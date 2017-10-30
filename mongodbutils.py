from __future__ import absolute_import


import ldap,json
import logging
import pymongo
import itertools
import path
import hashlib
import socket
from pymongo import Connection

import datetimeutils
import templateutils
import elasticutils

import re
from urlparse import urljoin
from BeautifulSoup import BeautifulSoup, Comment

CONF = path.path('/etc/perform.conf')
CONF_DEV = path.path('config/perform.conf')

key = ['d', 'r', 'e', 'a', 'm', 'w', 'o', 'r', 's', '-', 'p', 'e', 'r', 'f', 'o', 'r', 'm']
KNOWN_KEY = hashlib.sha256("-".join(key)).hexdigest()

HOST = socket.gethostname()


defaultResult = {"personal_email": "personalemail@gmail.com"}

connection = None

COLL_REVIEW = 'reviews'
COLL_SELF_REVIEW = 'self-reviews'
COLL_PERM = 'permissions'
COLL_CONTRIBUTORS = 'contributors'
COLL_SETUP_REVIEW = 'setup-review'
COLL_FEEDBACK = 'feedbacks'
COLL_NINEBOX_WEIGHTS_PERFORMANCE = 'ninebox-weights-performance'
COLL_NINEBOX_WEIGHTS_POTENTIAL = 'ninebox-weights-potential'
ADMINS = 'ADMINS'
REVIEW_ACTIVE = 'active'
REVIEW_ARCHIVED = 'archived'
REVOKE_ADMIN_RIGHTS ='REVOKE_ADMIN_RIGHTS'

def getConnection(*args, **kwargs):
    global connection

    if connection:
        return connection

    connection = MongoDB(*args, **kwargs)
    return connection


def getConfigValues():
    if CONF.exists():
        configFile = CONF
    else:
        configFile = CONF_DEV

    fp = configFile.open('r')
    values = json.load(fp)
    return values


def getMasterPassword():
    config = getConfigValues()

    UNKNOWN_KEY = config['password']

    KEY = '%s-%s-%s' % (KNOWN_KEY, HOST, UNKNOWN_KEY)

    return hashlib.sha256(KEY).hexdigest()


class AuthError(Exception):
    pass


class MongoDB(object):
    """
    This class abstracts connecting to the database. 
    The private functions (with "_") are meant to only be called by corresponding public functions.
    """

    def __init__(self, host, port=9090, dbname='perform'):

        self.connection = Connection(host=host, port=port)

        self.dbname = dbname
        self.db = self.connection[self.dbname]

        self.authenticate()

    def authenticate(self, user='admin'):
        password = getMasterPassword()
        return self.db.authenticate(user, password)

    def _getAdmins(self, query={}):
        collection = self.db['admins']
        results = collection.find(query)
        return results

    def _modifyAdmins(self, uid, uname, date, permissions, roles, department, action ):
        collection = self.db['admins']
        if action == REVOKE_ADMIN_RIGHTS:
            results = list(collection.find({'uid': uid}))
            if results:
                collection.remove({'uid':uid})
                return "SUCCESS"
            else: 
                return "ERROR: NO ADMIN FOUND" 
        else:
            collection.update({'uid':uid}, {'$set':{'uid':uid, 'uname':uname, 'permissions':permissions,'ou':department, 'roles':roles}}, True)
            return "SUCCESS"
    
    def _updateIsBusyReviewer(self, uid, year, rname, collection, isBusy, isCurrentlyEditedBy):
        """
        Private function to acquire the busy button
        """        
        
        logging.info('[%s] Adding %s review to %s-%s', uid, year, rname, isCurrentlyEditedBy)

        year = str(year)
        collection = self.db['reviewLocker']
        if (isBusy):
            collection.update({'uid':uid, 'year':year, 'rname':rname}, {'$set':{'uid':uid, 'year':year, 'rname':rname,'isCurrentlyEditedBy': isCurrentlyEditedBy}}, True)
            return "SUCCESS"
        else:
            collection.update({'uid':uid, 'year':year, 'rname':rname}, {'$set':{'uid':uid, 'year':year, 'rname':rname,'isCurrentlyEditedBy': "admin"}}, True)
            return "SUCCESS"    


    def _getBusyReviewer(self, uid, year, rname, collection):
        """
        Private function to acquire the busy button
        """        
        year = str(year)
        rname = str(rname)
        collection = self.db['reviewLocker']
        logging.info("%s .............:", rname)
        allReviews = list(collection.find({'uid': uid, 'rname':rname, 'year':year}))
        if allReviews:
            allReviews = allReviews[0]
            return allReviews
        return None

    def sanitizeHTML(self, value=None, base_url=None):
        rjs = r'[\s]*(&#x.{1,7})?'.join(list('javascript:'))
        rvb = r'[\s]*(&#x.{1,7})?'.join(list('vbscript:')) #for IE users (vb)
        re_scripts = re.compile('(%s)|(%s)' % (rjs, rvb), re.IGNORECASE)
        validTags = 'p i strong b u a h1 h2 h3 pre br img'.split()
        validAttrs = 'href src width height'.split()
        urlAttrs = 'href src'.split() # Attributes which should have a URL
        if not value:
            return value
        soup = BeautifulSoup(value)
        for comment in soup.findAll(text=lambda text: isinstance(text, Comment)):
            # Get rid of comments
            comment.extract()
        for tag in soup.findAll(True):
            if tag.name not in validTags:
                tag.hidden = True
            attrs = tag.attrs
            tag.attrs = []
            for attr, val in attrs:
                if attr in validAttrs:
                    val = re_scripts.sub('', val) # Remove scripts (vbs & js)
                    if attr in urlAttrs:
                        val = urljoin(base_url, val) # Calculate the absolute url
                    tag.attrs.append((attr, val))

        return soup.renderContents().decode('utf8')



    def _addReview(self, uid, year, rname, data, collection, diffSave=True, diffThresholdNum=10):
        """
        Private function to add a review
        """

        logging.info('[%s] Adding %s review to %s-%s', uid, year, rname, data)

        year = str(year)

        # Sanitize Markdown/HTML to protect against XSS PERFORM-139
        for k,v in data['review_body'].items():
            if k.startswith("notes"):
                clean = self.sanitizeHTML(v)
                data['review_body'][k] = clean

        if diffSave:
            try:
                allReviews = list(collection.find({
                    'uid': data['uid'],
                    'year': data['year'],
                    'rname': data['rname']
                }).sort('_id', pymongo.ASCENDING))
                logging.info("%s:%s:%s %s entries", uid, year, rname, len(allReviews))

                dropDiffIDs = []

                for change_type, reviews in itertools.groupby(allReviews, key=lambda x: x['change_type']):

                    if change_type == data['change_type']:
                        dropDiffIDs = [x['_id'] for x in reviews][:-diffThresholdNum]

                    for dropID in dropDiffIDs:
                        logging.info('Deleting %s', dropID)
                        collection.remove({'_id': dropID})

                lastEntry = allReviews[-1]
                lastReviewBody = lastEntry['review_body']

                lastReviewBody.update(data['review_body'])

                data['review_body'] = lastReviewBody
                results = collection.insert(data)
            except:
                results = collection.insert(data)
        else:
            results = collection.insert(data)

        return data

    def modifyAdmins(self, uid, uname, date, permissions, roles, department, action):
        """
        Modify the admin collection.
        """
        results = self._modifyAdmins(uid, uname, date, permissions, roles, department, action)
        return results

    def getAdmins(self):
        """
        Get the admin collection. 
        """
        results = list(self._getAdmins())
        return results
    
    def getAdminNames(self):
        """
        Get only names of all the admins.
        """
        admins = []
        results = self._getAdmins()
        for i in results:
            admins.append(i['uid'])
        return admins

    def isAdmin(self, user):
        return user in self.getAdminNames()

    def getAdminByName(self, uid):
        """
        Get admin data of a user based on their uid.
        """
        admins = []
        results = self._getAdmins()
        for i in results:
            if i['uid'] == uid:
                return i

    def getAdminNamesByPermission(self, permission):
        """
        Get admin names of users based on their permissions.
        """
        admins = []
        results = self._getAdmins()
        for i in results:
            if permission in i['permissions']:
                admins.append(i['uid'])
        return admins

    def updateIsBusyReviewer(self, uid, year, rname, collection, isBusy, isCurrentlyEditedBy):
        """
        acquire lock on a review
        """
        return self._updateIsBusyReviewer( uid, year, rname, collection, isBusy, isCurrentlyEditedBy)    

    def getBusyReviewer(self, uid, year, rname, collection):
        """
        user who acquired lock on a review
        """
        return self._getBusyReviewer( uid, year, rname, collection)     
        
    def getPermissionsByName(self, uid):
        """
        Get permissions of a user based on their uid.
        """
        results = self._getAdmins()
        for i in results:
            if i['uid'] == uid:
                perm = [i.strip() for i in i['permissions']]
                return perm


    def activityAuthorized(self,user, activity):
        """
        Check if the activity is allowed for the user.

        """
        adminList = self._getAdmins({"uid":user})
        userActivities = adminList[0]
        if activity in userActivities['permissions']:
            return 1
        return 0

    def addReview(self, uid, year, rname, data, reviewType, diffSave=True):
        """
        Add a review "change_type"
        """
        year = str(year)

        collName = self.getCollectionNameByReviewType(reviewType)

        collection = self.connection[self.dbname][collName]

        data['review_type'] = reviewType

        results = self._addReview(uid, year, rname, data, collection, diffSave=diffSave)

        # If this review has both reviewers and template set, we're done with setup.
        import utils
        if data['change_type'] in utils.ASSIGN_STATES:

            if data['all_reviewers'] and data['template_id']:
                newData = data
                newData['change_type'] = utils.SETUP_DONE_STATE
                newData.pop('_id')

                results = self._addReview(uid, year, rname, newData, collection, diffSave=diffSave)

        return results

    def getCollectionNameByReviewType(self, reviewType):

        if reviewType == 'review':
            collName = COLL_REVIEW
        elif reviewType == 'self-review':
            collName = COLL_SELF_REVIEW
        elif reviewType == 'weights-performance':
            collName = COLL_NINEBOX_WEIGHTS_PERFORMANCE
        elif reviewType == 'weights-potential':
            collName = COLL_NINEBOX_WEIGHTS_POTENTIAL
        else:
            raise ValueError('Unknown review type')

        return collName

    def massageReviewPacket(self, review, reviewType):

        allModelKeys = templateutils.getTemplate(review['template_id'])['modelkeys']

        currModelKeys = set(allModelKeys).intersection(review['review_body'].keys())

        review['curr_modelkeys'] = len(currModelKeys)
        review['all_modelkeys'] = len(allModelKeys)

        # This should have been ideally part of utils.createReviewPacket.
        # But since the first version is already in production, I have to do this as a post process
        review['review_type'] = reviewType

        return review

    def getReviewsByUser(self, uid, year, rname, reviewType, auth=None):

        auth_info = auth or {}
        year = str(year)
        admin_info = self.getAdminByName(auth_info.get('uid'))

        collName = self.getCollectionNameByReviewType(reviewType)

        user_info = elasticutils.getUserByName(uid)

        permissions = self.getPermissions(uid, year, rname)
        permittedUsers = permissions.get('permitted_users')
        year_permitted = permissions.get('year')

        if reviewType == 'review':

            if auth_info.get('uid') == uid and auth_info.get('uid') not in permittedUsers:
                # This is your review, but you don't have permissions just yet
                logging.error("Auth Error! (this is your review, "
                              "but you do not have permissions just yet) auth info: %s", auth_info)
                raise AuthError()
            elif auth_info.get('uid') == uid and auth_info.get('uid') in permittedUsers and year == year_permitted:
                # This is your review, and you have access to it (Delivered)
                pass
            elif auth_info.get('uid') in permittedUsers:
                # You're a reviewer, you can see this review
                pass
            elif auth_info.get('uid') in self.getAdminNames():
                #Check if admin is a HR reviewer (not allowed to view reviews of HR dept)
                
                if user_info.get('ou') == "Human Resources" and 'EDIT_HR' not in admin_info.get('permissions'):
                    logging.error("Auth Error! (You do not have permissions to view this review: %s", auth_info)
                    raise AuthError()
                else:
                    # You are an admin that can see any review
                    pass
            else:
                logging.error('Auth Error! (some other reason) auth info: %s', auth_info)
                raise AuthError()

        elif reviewType == 'self-review':
            if auth_info.get('uid') == uid:
                # This is your self-review, access it
                pass
            elif auth_info.get('uid') in permittedUsers:
                # You're a reviewer, so you can see this person's self-review
                pass

            elif auth_info.get('uid') in self.getAdminNames():
                #Check if admin is a HR reviewer (not allowed to view self-reviews of HR dept)
                if user_info.get('ou') == "Human Resources" and 'EDIT_HR' not in admin_info.get('permissions'):
                    logging.error("Auth Error! (You do not have permissions to view this self-review: %s", auth_info)
                    raise AuthError()
                else:
                    # You are an admin that can see any self-review
                    pass

            else:
                logging.error('Auth Error! (some other reason) auth info: %s', auth_info)
                raise AuthError()
        elif reviewType == 'weights-performance' or reviewType == 'weights-potential':
            # Anybody can see weights
            pass
        else:
            logging.error("Auth Error! (some reason that we don't really know. FIX THIS.) auth info: %s", auth_info)
            raise AuthError()

        collection = self.connection[self.dbname][collName]

        results = [self.massageReviewPacket(x, reviewType) for x in
                   collection.find({'uid': uid, 'year': year, 'rname': rname}).sort(
                       [("datetime", 1)])]  # find items, and sort by datetime
        return results

    def getReviewLocked(self, uid, ryear, rtype):
        # No self reviews!
        # import pdb
        # pdb.set_trace()
        collName = self.getCollectionNameByReviewType('review')
        collection = self.connection[self.dbname][collName]
        reviews = self.getLatestReviewFromAllReviewTypes()
        import utils
        for review in reviews:
            if review["reviews"]["uid"] == uid and review["reviews"]["year"] == str(ryear) and review["reviews"]["rname"] == rtype:
                if review["reviews"]["change_type"] in utils.LOCK_STATES + utils.ASSIGN_STATES + utils.ACKNOWLEDGE_STATES:
                    return True

        return False

    def getAllReviews(self, year, rname):
        '''
        Admin Operation
        '''

        year = str(year)

        collection = self.connection[self.dbname][COLL_REVIEW]

        if rname:
            reviews = list(collection.find({'year': str(year), 'rname': rname}).sort(
                [("datetime", 1)]))  # find items, and sort by datetime
        else:
            # You'll reach here when you wanna get all reviews. Mostly for debugging.
            reviews = list(collection.find({'year': str(year)}).sort([("datetime", 1)]))

        return reviews

    def getAllUsersFromLDAP(self):
        ldap_server = ldap.open('ldap.anim.dreamworks.com')
        results = ldap_server.search_s('ou=people,dc=anim,dc=dreamworks,dc=com',
                                       ldap.SCOPE_SUBTREE,
                                       attrlist=["uid", "cn", "ou"])
        user_info = {}
        for _, info in results:
            if "uid" not in info:
                continue
            uid = info["uid"].pop()
            department = info.get("ou", [""])[-1]
            name = info.get("cn", [""])[-1]
            user_info[uid] = {"name": name, "department": department}

        return user_info

    def getAllTrainingRecomendations(self, year, rname):
        """
        Admin Operation
        """
        col_name = self.getCollectionNameByReviewType('review')
        collection = self.connection[self.dbname][col_name]

        pipeline = [
            {"$match": {"year": str(year), "rname": rname}},
            {"$sort": {"datetime": pymongo.DESCENDING}},
            {"$group": {
                "_id": "$uid",
                "training-recommendations": {"$first": "$review_body.notes::training-recommendations"},
                "reviewers": {"$first": "$all_reviewers"},
                "acknowledged": {"$first": "$acknowledged"}
            }
            },
            {"$match": {"acknowledged": True}}
        ]

        reviews = collection.aggregate(pipeline)["result"]
        departments = {}
        users = self.getAllUsersFromLDAP()

        # querying ldap for fullname, department, reviewer name
        for review in reviews:
            uid = str(review['_id'])
            user = users[uid]

            if uid in review['reviewers']:
                review['reviewers'].remove(uid)  # The all_reviewers field
            reviewers = [users[reviewer]["name"] for reviewer in review['reviewers']]

            user['reviewers'] = reviewers
            user['training-recommendations'] = review['training-recommendations'].split('\n')

            departments.setdefault(user['department'], {'reviewers': [], 'uids': {}})

            departments[user['department']]['reviewers'].extend(reviewers)
            departments[user['department']]['uids'][uid] = user

        csv = ''
        for dep in departments:
            csv = csv + dep
            for reviewer in list(set(departments[dep]['reviewers'])):
                csv += ',%s' % reviewer
            csv += '\n'
            for key, user in departments[dep]['uids'].items():
                csv += user['name']
                for recommendation in user['training-recommendations']:
                    csv += ',\"%s\"' % recommendation
                csv += '\n'
            csv += '\n'

        return csv

    def getAllSelfReviews(self):

        reviews = self.db[COLL_SELF_REVIEW].group(
            ['uid', 'rname', 'year'],  # key
            None,  # criteria
            {'selfReviews': {}},  # initial object
            'function(obj, prev) {prev.selfReviews = obj}'  # reduce
        )

        return reviews

    def getAllSelfReviewsByYear(self, year, rname):

        year = str(year)

        collection = self.connection[self.dbname][COLL_SELF_REVIEW]

        if rname:
            reviews = list(collection.find({'year': str(year), 'rname': rname}).sort([("datetime", 1)]))
        else:
            # You'll reach here when you wanna get all reviews. Mostly for debugging.
            reviews = list(collection.find({'year': str(year)}).sort([("datetime", 1)]))

        return reviews

    def getAllPermissions(self, year, rname):

        year = str(year)

        collection = self.connection[self.dbname][COLL_PERM]

        permissions = list(collection.find({'year': str(year), 'rname': rname}))

        return permissions

    def getAllUserReviews(self, uid):

        collection = self.connection[self.dbname][COLL_REVIEW]

        reviews = list(collection.find({'uid': uid}).sort([("datetime", 1)]))

        collection = self.connection[self.dbname][COLL_SELF_REVIEW]

        selfReviews = list(collection.find({'uid': uid}).sort([("datetime", 1)]))

        return reviews, selfReviews

    def _getUnlockedReviews(self, collection, reviewType, uid=None, year=None, rname=None):

        criteria = {}
        if uid:
            criteria['uid'] = uid

        if year:
            criteria['year'] = year

        if rname:
            criteria['rname'] = rname

        # XXX: This can be optimized to use collection.aggregate
        reviews = collection.group(['uid', 'year', 'rname'], criteria, {'results': []},
                                   'function(obj, prev){prev.results.push(obj)}')
        lastReviews = [sorted(x['results'], key=lambda x: x['datetime'])[-1] for x in reviews]

        # Massage the review packet
        lastReviews = [self.massageReviewPacket(x, reviewType) for x in lastReviews]

        return filter(lambda x: x['locked'], lastReviews), filter(lambda x: not x['locked'], lastReviews)

    def getUnlockedReviews(self, uid, reviews):

        lockedReviews = []
        unlockedReviews = []

        collection = self.connection[self.dbname][COLL_REVIEW]

        for review in reviews:
            locked, unlocked = self._getUnlockedReviews(collection, reviewType='review', uid=review['uid'],
                                                        year=review['year'], rname=review['rname'])

            # lockedReviews.extend(locked)
            lockedReviews.extend([x for x in locked if not (x['review_type'] == 'review' and x[
                'uid'] == uid)])  # skip performance reviews that are delivered. Otherwise it'll show up in task list.

            unlockedReviews.extend(unlocked)

        for unlockedReview in unlockedReviews:

            auth = {'uid': unlockedReview['uid']}  # Create a dummy auth object

            # Get the latest self review
            selfReviews = self.getReviewsByUser(unlockedReview['uid'], unlockedReview['year'], unlockedReview['rname'],
                                                'self-review', auth=auth)

            if selfReviews:
                unlockedReview['self-review'] = selfReviews[-1]
            else:
                unlockedReview['self-review'] = selfReviews

        return lockedReviews, unlockedReviews

    def getUnlockedSelfReviewsByUser(self, uid):

        collection = self.connection[self.dbname][COLL_SELF_REVIEW]

        return self._getUnlockedReviews(collection, reviewType='self-review', uid=uid)

    def getAllReviewTypes(self):
        '''
        Admin operation
        '''

        return list(self.db[COLL_SETUP_REVIEW].find().sort([('datetime', pymongo.DESCENDING)]))

    def getLatestReviewFromAllReviewTypes(self):
        '''
        Admin operation
        '''

        latestReviews = self.db[COLL_REVIEW].group(
            ['uid', 'rname', 'year'],  # key
            None,  # criteria
            {'reviews': {'datetime': 0, "change_type": ""}},  # intial object
            '''
            function(obj, prev) {

                if (prev.reviews.datetime < obj.datetime) {
                    prev.reviews = obj;
                }
                else if (prev.reviews.datetime.getTime() == obj.datetime.getTime()){
                    if (obj.change_type == "SETUP_DONE" || obj.change_type == "ACKNOWLEDGE_REVIEW"){
                        prev.reviews = obj;
                    }
                    else{
                        prev.reviews
                    }

                }
            }
            '''  # reduce
        )
        return latestReviews

    def getEditableReviews(self, uid):

        permittedReviews = self.getPermittedReviewsByUser(uid)
        logging.info("Found %d permitted reviews", len(permittedReviews))

        lockedReviews, unlockedReviews = self.getUnlockedReviews(uid, permittedReviews)

        lockedSelfReviews, unlockedSelfReviews = self.getUnlockedSelfReviewsByUser(uid)

        data = {}
        data.setdefault('locked', {})['review'] = lockedReviews
        data.setdefault('locked', {})['self-review'] = lockedSelfReviews

        data.setdefault('unlocked', {})['review'] = unlockedReviews
        data.setdefault('unlocked', {})['self-review'] = unlockedSelfReviews

        logging.info('locked: review (%d), self-review (%d)',
                     len(data['locked']['review']),
                     len(data['locked']['self-review']))
        logging.info('unlocked: review (%d), self-review (%d)',
                     len(data['unlocked']['review']),
                     len(data['unlocked']['self-review']))

        return data

    def getTemplate(self, template_id):

        collection = self.connection[self.dbname]['templates']

        template = list(collection.find({'name': template_id}, {'_id': 0}))[0]

        return template

    def undoReviewChange(self, uid, year, rname):

        year = str(year)

        collection = self.connection[self.dbname][COLL_REVIEW]

        lastEntry = collection.find({'uid': uid, 'year': year, 'rname': rname}).sort('_id', pymongo.DESCENDING).limit(1)

    def setContributors(self, uid, year, rname, contributors):

        year = str(year)

        collection = self.connection[self.dbname][COLL_CONTRIBUTORS]

        contributors = [x.strip() for x in contributors if x.strip()]

        collection.update({'uid': uid, 'year': year, 'rname': rname}, {'$set': {'contributors': contributors}},
                          upsert=True)

    def getContributors(self, uid, year, rname):

        year = str(year)

        collection = self.connection[self.dbname][COLL_CONTRIBUTORS]

        results = list(collection.find({'uid': uid, 'year': year, 'rname': rname}))

        if results:
            return results[0]
        else:
            contributors = {'contributors': []}

            return contributors

    def addContributors(self, uid, year, rname, contributors):

        collection = self.connection[self.dbname][COLL_CONTRIBUTORS]
        permissions = self.getContributors(uid, year, rname)

        contributors = [x.strip() for x in contributors if x.strip()]

        if permissions:

            permissions.pop('_id')

            for user in contributors:
                if user not in permissions['contributors']:
                    permissions['contributors'].append(user)

            logging.info('Updating', permissions)
            collection.update({'uid': uid, 'year': year, 'rname': rname}, permissions)
        else:
            permissions = {
                'uid': uid,
                'year': year,
                'rname': rname,
                'contributors': contributors
            }

            logging.info('Inserting', permissions)
            collection.insert(permissions)

    def removeContributors(self, uid, year, rname, removeUsers):

        year = str(year)

        permissions = self.getContributors(uid, year, rname)
        collection = self.connection[self.dbname][COLL_CONTRIBUTORS]

        removeUsers = [x.strip() for x in removeUsers if x.strip()]

        if permissions:
            permissions.pop('_id')
            permissions['contributors'] = list(set(permissions['contributors']) - set(removeUsers))

            logging.info('Updating', permissions)
            collection.update({'uid': uid, 'year': year, 'rname': rname}, permissions)

    def addPermissions(self, uid, year, rname, permittedUsers, auth):

        collection = self.connection[self.dbname][COLL_PERM]
        permissions = self.getPermissions(uid, year, rname)

        permittedUsers = [x.strip() for x in permittedUsers if x.strip()]

        if permissions:
            permissions.pop('_id')
            for user in permittedUsers:
                if user not in permissions['permitted_users']:
                    permissions['permitted_users'].append(user)

            logging.info('Updating', permissions)
            collection.update({'uid': uid, 'year': year, 'rname': rname}, permissions)
        else:
            permissions = {
                'uid': uid,
                'year': year,
                'rname': rname,
                'permitted_users': permittedUsers
            }

            logging.info('Inserting', permissions)
            collection.insert(permissions)

    def removePermissions(self, uid, year, rname, removeUsers):

        year = str(year)

        permissions = self.getPermissions(uid, year, rname)
        collection = self.connection[self.dbname][COLL_PERM]

        removeUsers = [x.strip() for x in removeUsers if x.strip()]

        if permissions:
            permissions.pop('_id')
            permissions['permitted_users'] = list(set(permissions['permitted_users']) - set(removeUsers))

            logging.info('Updating', permissions)
            collection.update({'uid': uid, 'year': year, 'rname': rname}, permissions)

    def setPermissions(self, uid, year, rname, permittedUsers):

        year = str(year)

        collection = self.connection[self.dbname][COLL_PERM]

        permittedUsers = [x.strip() for x in permittedUsers if x.strip()]

        collection.update({'uid': uid, 'year': year, 'rname': rname},
                          {'$set': {'permitted_users': permittedUsers}},
                          upsert=True)

    def getPermissions(self, uid, year, rname):

        collection = self.connection[self.dbname][COLL_PERM]

        results = [permission for permission in collection.find({'uid': uid, 'rname': rname})
                   if int(permission['year']) >= int(year)]

        permissions = [permission for permission in results
                       if str(permission['year']) == year]

        #Only one review cycle with that rname in one year
        if permissions:
            permissions = permissions[0]
        else:
            permissions = {'permitted_users': []}

        logging.debug("Permissions for %s, year: %s, review: %s is %s",
                      uid, year, rname, permissions)

        return permissions

    def getPermittedReviewsByUser(self, uid):

        collection = self.connection[self.dbname][COLL_PERM]

        results = list(collection.find({'permitted_users': {'$in': [uid]}}))

        logging.debug("Permitted reviews for user %s: %s", uid, results)

        return results

    def unarchiveReview(self, year, rname):
        """
        Mark the review as unarchived
        """
        collection = self.connection[self.dbname][COLL_SETUP_REVIEW]

        # find the review to modify
        result = collection.find({'year': year, 'rname': rname})
        review = result[0]
        review['status'] = REVIEW_ACTIVE

        # Update the review document
        results = collection.update({'year': year, 'rname': rname}, review)

        return results

    def archiveReview(self, year, rname):
        """
        Mark the review as archived
        """
        collection = self.connection[self.dbname][COLL_SETUP_REVIEW]

        # find the review to modify
        result = collection.find({'year': year, 'rname': rname})
        review = result[0]
        review['status'] = REVIEW_ARCHIVED

        # Update the review document
        results = collection.update({'year': year, 'rname': rname}, review)

        return results

    def setupReview(self, uid, year, rname, data):
        """
        Create review_types - 2015/annual, etc
        """

        year = str(year)

        collection = self.connection[self.dbname][COLL_SETUP_REVIEW]

        setup_data = {
            'uid': uid,
            'year': year,
            'rname': rname,
            'datetime': datetimeutils.timenow(),
            'status': 'active',
        }

        setup_data.update(data)

        if '_id' in setup_data:
            setup_data.pop('_id')

        results = collection.update({'year': year, 'rname': rname}, setup_data, upsert=True)

        return results

    def getsetReviewMetadata(self, uid, year, rname):

        if not (year and rname):
            raise ValueError()

        year = str(year)

        collection = self.connection[self.dbname][COLL_SETUP_REVIEW]

        results = list(collection.find({'year': year, 'rname': rname}))

        if results:
            results = results[0]
        else:
            results = self.setupReview(uid, year, rname, {})

        return results

    def getFeedback(self, uid, reviewer):

        collection = self.connection[self.dbname][COLL_FEEDBACK]

        results = list(collection.find({'uid': uid, 'reviewer': reviewer}).sort([("datetime", 1)]))

        return results

    def getFeedbackByUser(self, uid):

        collection = self.connection[self.dbname][COLL_FEEDBACK]

        results = list(collection.find({'uid': uid, 'locked': True}).sort([("datetime", 1)]))

        data = {}

        for reviewer, feedbacks in itertools.groupby(results, lambda x: x['reviewer']):
            data[reviewer] = list(feedbacks)

        return results, data

    def addFeedback(self, uid, feedback):

        collection = self.connection[self.dbname][COLL_FEEDBACK]

        feedbacks = self.getFeedback(uid, feedback['reviewer'])
        if feedbacks:
            lastFeedback = feedbacks[-1]
        else:
            # If nothing's there, then the "nothing" is actually locked
            lastFeedback = {'locked': True}

        if feedback['locked']:
            # If its locked - insert
            collection.insert(feedback)
        elif not feedback['locked'] and not lastFeedback['locked']:
            # If its not locked, and previous is also not locked - update
            collection.update({'_id': lastFeedback['_id'], 'uid': uid, 'reviewer': feedback['reviewer']}, feedback)
        elif not feedbacks or lastFeedback['locked']:
            # If nothing exists, OR if its locked - insert
            collection.insert(feedback)
        else:
            # update last one
            collection.update({'_id': lastFeedback['_id'], 'uid': uid, 'reviewer': feedback['reviewer']}, feedback)

        return self.getFeedback(uid, feedback['reviewer'])
