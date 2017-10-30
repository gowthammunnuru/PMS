#!/bin/env python
# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.

from __future__ import absolute_import

import os
import sys
import json
import traceback
import datetime
import time
import socket
import logging
import tornado.ioloop
import tornado.web
import mongodbutils
import tornado.options
import tornado.websocket
import tornado.template
import base64
import uuid

import templateutils
import authutils
import gitutils
import elasticutils
from bson import json_util
from mongodbutils import AuthError
import urllib2


tornado.options.define("port", default=8888, help="Run on the given port", type=int)

angularAppPath = os.path.abspath(os.path.dirname(__file__))

mongo = mongodbutils.getConnection(host='localhost', port=9090)
import utils

CURR_HOST = socket.gethostname()
CURR_PORT = tornado.options.options.port

import emailutils

emailutils.registerHost(CURR_HOST, CURR_PORT)


class Default(tornado.web.RequestHandler):
    """
    If Tornado doesnt know what to do, let angular take care of the url.
    """

    def get(self, path):
        """
        HTTP GET Method handler
        """
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        self.redirect('/#%s' % path, permanent=True)

class BaseHandler(tornado.web.RequestHandler):
    def get_current_user(self):
        return self.get_secure_cookie("user")

class Index(BaseHandler):
    """
    Handler to serve the template/index.html
    """
    # @tornado.web.authenticated
    def get(self):
        # if not self.current_user:
        #     self.redirect('/login')
        # name = tornado.escape.xhtml_escape(self.current_user)
        """
        HTTP GET Method handler
        """
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        with open(angularAppPath + "/index.html", 'r') as file:
            self.write(file.read())

class RecommendationHandler(tornado.web.RequestHandler):
    """
    Handler to export training recommendations
    """

    def get(self):
        """
        HTTP GET Method handler
        """
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        ryear = self.get_argument("ryear")
        rname = self.get_argument("rname")

        csvData = mongo.getAllTrainingRecomendations(ryear, rname)
        self.set_header('Content-Type', 'text/csv')
        self.set_header('Content-Disposition', 'attachment; filename=' + rname + '-' + ryear + '.csv')
        self.write(csvData)

class LogoutHandler(BaseHandler):
    def get(self, *args, **kwargs):
        self.clear_cookie("session")
        self.clear_cookie("user")

class LoginHandler(BaseHandler):
    
    def get(self,auth):
        pass

    def post(self, *args, **kwargs):
        auth = json.loads(self.request.body)
        uname = auth['user']
        password = auth['pass']
        response = {}
        if authutils.auth(uname, password):
            #self.set_current_user(uname)
            response['uid'] = uname
            response['sid'] = authutils.getSessionID(uname)
            response['is_admin'] = mongo.isAdmin(uname)
        else:
            response['error'] = "auth_error"
        
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', 'application/json')
        # self.set_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.write(response)
        self.finish()

    def set_current_user(self, user):
        if user:
            self.set_secure_cookie("user", tornado.escape.xhtml_escape(user), expires_days=30)
        else:
            self.clear_cookie("user")


class GetAllUsers(tornado.web.RequestHandler):

    def get(self):
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', 'application/json')
        self.set_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        response = elasticutils.searchAll()
        self.write(response)
        self.finish()

class GetActiveLocationUsers(tornado.web.RequestHandler):
    def get(self, location="DreamWorks Animation International Services, LLC"):
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', 'application/json')
        self.set_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        response = elasticutils.getActiveUsersInLocation(location)
        self.write(response)
        self.finish()


class GetUserQuery(tornado.web.RequestHandler):
    def get(self, uid):
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', 'application/json')
        self.set_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        response = elasticutils.getUserByName(uid)
        adminPermissions = mongo.getPermissionsByName(uid)
        response['permissions'] = adminPermissions
        self.write(response)
        self.finish()

class Avatar(tornado.web.RequestHandler):
    def get(self, uid):
        empNumber = elasticutils.get_employee_number(uid)
        path = "http://dwskg.anim.dreamworks.com/dreampages/animation/images/%s.jpg" %empNumber
        
        self.set_header('Access-Control-Allow-Origin', 'http://dwskg.anim.dreamworks.com')
        self.set_header('Content-Type', 'jpg')

        try:
            url = urllib2.urlopen(path)
            self.write(url.read())
            self.finish()
        except IOError:
            path = "/hosts/grayfern.anim.dreamworks.com/usr/pic1/default.png"
            with open(path, 'rb') as f:
                data = f.read()
                self.write(data)
            self.finish()

class Static(tornado.web.RequestHandler):
    """
    Handler to serve everything inside static/ directory
    """

    def get(self):
        """
        HTTP GET Method handler
        """
        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)
        ext = self.request.path.rpartition('.')[-1]

        if ext == 'css':
            contentType = 'text/css'
        elif ext == 'js':
            contentType = 'application/javascript'
        else:
            contentType = ''

        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', contentType)

        try:
            with open(angularAppPath + self.request.uri, 'r') as fd:
                self.write(fd.read())
        except:
            self.write('')


class Socket(tornado.websocket.WebSocketHandler):
    """
    A sample WebSocket endpoint that interprets every keystroke from the browser
    and see whether its a proper hostname or not.

    Access this endpoint at ws://localhost:<port>/ws/ip

    ex: ws://localhost:8080/ws/ip
    """

    def open(self):
        """
        Called when a WebSocket connection is established
        """

    def on_message(self, message):
        """
        Called when a client sends a message
        """
        data = json.loads(message)

        request = data['request']

        logging.debug("Received request: %s, data: %s", request['type'], data)
        t1 = time.time()

        try:
            response = getattr(self, "handler_%s" % request['type'])(request['query'], data)
        except Exception, e:
            traceback.print_exc()
            response = {
                'exception': e,
                'error': 'error'
            }

        if response is not None:
            self.respond(data, response)
        logging.debug('[%s]: %s secs', request['type'], (time.time() - t1))

    def respond(self, input, result):
        """
        A convenience function that packages the result
        into an object with corresponding input `callback_id`

        Since WebSocket results arent serial, `callback_id`
        helps client correlate result with the input.
        """

        output = {'callback_id': input['callback_id'], 'data': result}

        def jsonhandler(obj):
            if isinstance(obj, datetime.datetime) or isinstance(obj, datetime.date):
                return obj.isoformat()
            elif isinstance(obj, set):
                return list(obj)

        try:
            self.write_message(json.dumps(output, default=jsonhandler))
        except:
            logging.error("Problem in respond function")

    def handler_app_metadata(self, *_):
        """
        Getting list of (topojson ids, room ids) of people on this map
        """
        t1 = time.time()
        commit = gitutils.getCurrentCommit()
        t2 = time.time()
        logging.debug("[app_metadata]: getCurrentCommit() took %s seconds", t2 - t1)

        t1 = time.time()
        gitDescribe, tag = gitutils.getTagish(commit, getMajorTag=True)
        logging.info("[app_metadata]: getTagish() took %s seconds", time.time() - t1)

        t1 = time.time()
        metadata = {
            'commit': commit,
            'git_describe': gitDescribe,
            'tag': tag,
            'server': CURR_HOST,
            'ip': socket.gethostbyname(CURR_HOST),
            'pid': os.getpid()
        }
        logging.info("[app_metadata]: metadata dict took %s seconds", time.time() - t1)

        return metadata

    @utils.validate_activity
    def handler_get_all_admins(self, request,input):
        return mongo.getAdmins()

    @utils.validate_activity
    def handler_modify_admins(self, request, input):
        return mongo.modifyAdmins(request['uid'], request['uname'], request['date'], request['permissions'], request['roles'], request['ou'], request['action'])


    @utils.validate
    def handler_get_review(self, request, _):
        uid = request['uid']
        year = request['year']
        rname = request['rname']

        reviewType = request['review_type']

        logging.info("[get_review]: %s-%s-%s (%s)", uid, year, rname, reviewType)

        auth = request['auth']
        if request['review_type'] == 'review' and auth['uid'] == uid:
            restrictedAccess = True
        else:
            restrictedAccess = False

        data = {}
        try:
            data['reviews'] = mongo.getReviewsByUser(uid, year, rname, reviewType, auth=auth)
            data['metadata'] = mongo.getsetReviewMetadata(uid, year, rname)

            if restrictedAccess:
                # We reach here if a user can see his/her review. We still shouldnt send the feedback back.
                data['feedbacks'], _, = {}, {}
            else:
                data['feedbacks'], _, = mongo.getFeedbackByUser(uid)
        except Exception, e:
            traceback.print_exc()
            data['error'] = 'auth_error'
        else:
            # Review Type hasn't been set just yet
            if data['reviews']:
                data['latest_review'] = data['reviews'][-1]
                data['latest_template'] = templateutils.getTemplate(data['latest_review']['template_id'])

                data['permitted_users'] = mongo.getPermissions(uid, year, rname)['permitted_users']

                # if its restricted access, remove the user from the permitted users
                # TODO: this logic is a lil odd, change "deliver review" into a paramter, instead of adding
                # the user to permitted_users list
                if restrictedAccess:
                    data['permitted_users'].pop(data['permitted_users'].index(uid))

                data['contributors'] = mongo.getContributors(uid, year, rname)['contributors']

                data['timeline'] = {}
                data['timeline']['COMMIT_REVIEW'] = None
                data['timeline']['PUBLISH_REVIEW'] = None
                data['timeline']['ACKNOWLEDGE_REVIEW'] = None

                latestChangeType = data['latest_review']['change_type']

                if latestChangeType not in ['ACKNOWLEDGE_REVIEW', 'PUBLISH_REVIEW', 'READY2PUBLISH', 'COMMIT_REVIEW']:
                    # Nothing to do.
                    # This review isnt in a "good" state, return.
                    pass

                elif reviewType == 'review':

                    for review in reversed(data['reviews']):

                        changeType = review['change_type']

                        if changeType in ['ACKNOWLEDGE_REVIEW', 'PUBLISH_REVIEW', 'COMMIT_REVIEW']:
                            data['timeline'][changeType] = review['datetime']

                        # When we hit commit review, we stop
                        if changeType == 'COMMIT_REVIEW':
                            break

                else:
                    # We're in a good state, and we dont need to do anything
                    data['timeline']['COMMIT_REVIEW'] = data['latest_review']['datetime']
                    data['timeline']['PUBLISH_REVIEW'] = data['latest_review']['datetime']
                    data['timeline']['ACKNOWLEDGE_REVIEW'] = data['latest_review']['datetime']

            else:
                data['error'] = 'review_type_not_set'

        return data

    @utils.validate
    def handler_get_review_multi(self, request, input):

        responses = []

        for req in request['requests']:
            req['auth'] = request['auth']
            result = self.handler_get_review(req, input)

            responses.append(result)

        return responses

    @utils.validate
    def handler_template_lookup(self, request, _):

        template = templateutils.getTemplate(request)

        return template

    @utils.validate
    def handler_update_userdata(self, request, _):

        uid = request['uid']
        note = request['note']

        data = {
            'username': uid,
            'note': note,
        }

        results = mongo.setUser(uid, data)

        return results

#Is it using this? Find out where !!!!!!!!!!!!!!!!!!!!!!!!!!
    @utils.validate
    def handler_review_add(self, request, _):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        review_body = request['review_body']
        template_id = request['template_id']
        reviewer = request['reviewer']
        reviewType = request['review_type']

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

        data = utils.createReviewPacket(uid, year, rname, review_body, template_id, reviewers, reviewer, reviewType,
                                        change_type='REVIEW_ADD')

        results = mongo.addReview(uid, year, rname, data)

        return results

    @utils.validate
    @utils.is_my_turn
    def handler_review_draft(self, request, input):
        uid = request['uid']
        year = request['year']
        rname = request['rname']
        auth = request["auth"]

        review_body = request['review_body']
        template_id = request['template_id']
        reviewer = request['reviewer']
        reviewType = request['review_type']

        logging.debug('Saving %s', review_body)

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']
        data = utils.createReviewPacket(uid, year, rname, review_body, template_id, reviewers, reviewer, reviewType,
                                        change_type='REVIEW_DRAFT')

        if reviewType == 'self-review' and auth.get("uid") != uid:
            logging.error("Auth Error! (Sorry, you cannot edit others' self-review, even if you're an admin) %s", auth)
            raise AuthError()

        results = mongo.addReview(uid, year, rname, data, reviewType, diffSave=True)

        return self.handler_get_review(request, input)

    def handler_update_busy_reviewer(self, request, input):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        isBusy = request['isBusy']
        isCurrentlyEditedBy= request['isCurrentlyEditedBy']
       
        logging.debug('Saving review edited by %s', isCurrentlyEditedBy)

        results = mongo.updateIsBusyReviewer(uid, year, rname, "isBusy", isBusy ,isCurrentlyEditedBy)
        return results

    def handler_check_busy_reviewer_for_multi(self, request, input):

        review_list = request['review_list']
        auth_uid = request['auth']['uid']
        busy_reviewers = []

        for review in review_list:
            split_list = review.split("-", 2)
            result = mongo.getBusyReviewer(split_list[0], split_list[1], str(split_list[2]), "isBusy")
            if result:
                if result['isCurrentlyEditedBy'] == auth_uid or result['isCurrentlyEditedBy'] == 'admin':
                    continue
                else:
                    busy_reviewers.append(result['isCurrentlyEditedBy'])
            else:
                continue
        busy_reviewers = list(set(busy_reviewers))
        return busy_reviewers


    def handler_get_busy_reviewer(self, request, input):

        uid = request['uid']
        year = request['year']
        rname = request['rname']
        results = mongo.getBusyReviewer(uid, year, str(rname), "isBusy")
        if results:
            return results
        return None

    def handler_login(self, request, _):

        uname = request['user']
        password = request['pass']

        response = {}

        if authutils.auth(uname, password):
            response['uid'] = uname
            response['sid'] = authutils.getSessionID(uname)
            response['is_admin'] = mongo.isAdmin(uname)
        else:
            response['error'] = "auth_error"

        return response

    @utils.validate
    def handler_get_all_template_types(self, request, input):
        year = request['year']
        rname = request['rname']

        #adminUser = request['auth'].get('uid')

        data = {}

        for templateID in sorted(templateutils.getAllTemplateTypes()):
            request['uid'] = templateID

            request['review_type'] = 'weights-performance'
            weightsPerformance = self.handler_get_review(request, input)

            request['review_type'] = 'weights-potential'
            weightsPotential = self.handler_get_review(request, input)

            templateData = {
                'id': templateID,
                'template_id': templateID,
                'weights-performance': weightsPerformance,
                'weights-potential': weightsPotential,
                'contents': templateutils.getTemplate(templateID)
            }

            data[templateID] = templateData

        return data

    @utils.validate_activity
    def handler_set_template_weights(self, request, _):
        """
        Admin Operation
        Sets performance/potential weights based on what the user chooses.
        In the "Templates" tab on the Admin Console.
        Used for nine-box evaluation.

        """
        templateID = request['template_id']
        year = str(request['year'])
        rname = request['rname']
        adminUser = request['auth'].get('uid')

        dataWeights = utils.createReviewPacket(templateID, year, rname, {}, templateID, [adminUser], adminUser,
                                               'weights-performance', change_type='SET_TEMPLATE')
        results = mongo.addReview(templateID, year, rname, dataWeights, 'weights-performance')

        dataWeights = utils.createReviewPacket(templateID, year, rname, {}, templateID, [adminUser], adminUser,
                                               'weights-potential', change_type='SET_TEMPLATE')
        results = mongo.addReview(templateID, year, rname, dataWeights, 'weights-potential')

        return results

    @utils.validate_activity
    def handler_get_all_reviews_by_year(self, request, input):
        """
        Admin Operation
        """

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        all_reviews = mongo.getAllReviews(year, rname)
        permissions = mongo.getAllPermissions(year, rname)
        metadata = mongo.getsetReviewMetadata(uid, year, rname)

        all_permissions = {}

        for p in permissions:
            all_permissions[p['uid']] = p

        for review in all_reviews:
            review['permitted_users'] = all_permissions.get(review['uid'], {}).get('permitted_users', [])

        data = {'reviews': all_reviews, 'metadata': metadata}

        return data

    @utils.validate_activity
    def handler_get_admin_data(self, request, _):
        """
        Admin Operation
        """
        reviewTypes = mongo.getAllReviewTypes()
        latestReviews = mongo.getLatestReviewFromAllReviewTypes()
        selfReviews = mongo.getAllSelfReviews()

        logging.info([x['reviews']['change_type'] for x in latestReviews])

        data = {
            'review_types': reviewTypes,
            'latest_reviews': latestReviews,
            'self-reviews': selfReviews
        }

        return data

    @utils.validate
    def handler_get_user(self, request, _):

        uid = request['uid']

        reviews, selfReviews = mongo.getAllUserReviews(uid)

        performanceReviewSummary = utils.reviewSummary(reviews)
        selfReviewSummary = utils.reviewSummary(selfReviews)

        data = {
            'reviews': performanceReviewSummary, 'self-reviews': selfReviewSummary,
            'editable': mongo.getEditableReviews(uid),
            'years': performanceReviewSummary['years'].union(selfReviewSummary['years'])
        }

        return data

    @utils.validate_activity
    def handler_set_template_id(self, request, _):
        """
        Admin Operation
        Sets the template of the review (eg: rnd, animation etc. in the drop down) for a particular user.
        """
        uid = request['uid']
        year = str(request['year'])
        rname = request['rname']

        templateID = request['template_id']
        adminUser = request['auth'].get('uid')

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

        changeType = 'SET_TEMPLATE'

        if templateID is None:
            if len(reviewers) > 0:
                changeType = 'SET_REVIEWER'
            else:
                changeType = 'UNASSIGNED'
        else:
            changeType = 'SET_TEMPLATE'

        dataReview = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, 'review',
                                              change_type=changeType)
        dataSelfReview = utils.createReviewPacket(uid, year, rname, {}, templateID, [uid], adminUser, 'self-review',
                                                  change_type=changeType)

        results = mongo.addReview(uid, year, rname, dataReview, 'review')
        results = mongo.addReview(uid, year, rname, dataSelfReview, 'self-review')

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        #emailutils.emailAssigned4Employee(reviewers, uid, adminUser, **opts)

        return results

    @utils.validate
    def handler_set_reviewers(self, request, _):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        mode = request['mode']
        permittedUsers = request['users']

        auth = request['auth']
        reviewType = request['review_type']
        adminUser = request['auth'].get('uid')

        if mode == "add":
            mongo.addPermissions(uid, year, rname, permittedUsers, auth)

            opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
            emailutils.emailAssigned4Reviewer(permittedUsers, uid, adminUser, **opts)
        else:
            mongo.removePermissions(uid, year, rname, permittedUsers)

            # Chosing not to send an email when you remove a reviewer
            pass

        return mongo.getReviewsByUser(uid, year, rname, reviewType, auth=auth)

    @utils.validate
    def handler_publish_review(self, request, input):

        uid = request['uid']
        year = request['year']
        rname = request['rname']
        auth = request['auth']
        templateID = request['template_id']
        adminUser = request['auth'].get('uid')

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

        #Check if this COMMIT_REVIEW stuff is needed!!!!!!!!!!!!!!!!!!!!!!

        # When the user acknowledges the review, commit his/her self review, ensuring that it can't be edited again.
        data = utils.createReviewPacket(uid, year, rname, {}, templateID, [uid], adminUser, 'self-review',
                                        change_type='COMMIT_REVIEW')
        _ = mongo.addReview(uid, year, rname, data, 'self-review', diffSave=True)

        data = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, 'review',
                                        change_type='PUBLISH_REVIEW')
        results = mongo.addReview(uid, year, rname, data, 'review', diffSave=True)

        # Give permissions to uid
        mongo.addPermissions(uid, year, rname, [uid], auth)

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))

        # This is required by handler_get_review
        request['review_type'] = 'review'
        emailutils.emailPublished(reviewers, uid, adminUser, self.handler_get_review(request, input), **opts)

        return results

    @utils.validate_activity
    def handler_ready2publish_review(self, request, _):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        templateID = request['template_id']
        adminUser = request['auth'].get('uid')

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

        data = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, 'review',
                                        change_type='READY2PUBLISH')
        results = mongo.addReview(uid, year, rname, data, 'review', diffSave=True)

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        emailutils.emailReady2Publish(reviewers, uid, adminUser, **opts)

        return results

    @utils.validate
    def handler_commit_review(self, request, input):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        templateID = request['template_id']
        adminUser = request['auth'].get('uid')
        reviewType = request['review_type']

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']
        data = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, reviewType,
                                        change_type='COMMIT_REVIEW')

        results = mongo.addReview(uid, year, rname, data, reviewType, diffSave=True)

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        emailutils.emailCommitted(reviewers, uid, adminUser, self.handler_get_review(request, input), **opts)

        return results

    @utils.validate
    def handler_uncommit_review(self, request, _):
        uid = request['uid']
        year = request['year']
        rname = request['rname']

        templateID = request['template_id']
        adminUser = request['auth'].get('uid')
        reviewType = request['review_type']

        #Remove user's permission to view review since it is going into edit mode
        mongo.removePermissions(uid, year, rname, [uid])

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

        data = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, reviewType,
                                        change_type='REVIEW_DRAFT')

        results = mongo.addReview(uid, year, rname, data, reviewType, diffSave=True)

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        if reviewType == 'review':
            emailutils.emailReviewUncommitted(reviewers, uid, adminUser, **opts)
        elif reviewType == 'self-review':
            emailutils.emailSelfReviewUncommitted(reviewers, uid, adminUser, **opts)

        return results

    @utils.validate
    def handler_acknowledge_review(self, request, input):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        templateID = request['template_id']
        adminUser = request['auth'].get('uid')
        reviewType = request['review_type']

        reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']
        data = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, reviewType,
                                        change_type='ACKNOWLEDGE_REVIEW')
        results = mongo.addReview(uid, year, rname, data, reviewType, diffSave=True)

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        emailutils.emailAcknowledged(reviewers, uid, adminUser, self.handler_get_review(request, input), **opts)

        return results

    @utils.validate
    def handler_send_self_review_reminder(self, request, _):

        uid = request['uid']
        year = str(request['year'])
        rname = request['rname']

        adminUser = request['auth'].get('uid')

        opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
        emailutils.sendSelfReviewReminder(uid, adminUser, **opts)

        results = {'retVal': True}

        return results

    @utils.validate
    def handler_set_permissions(self, request, _):

        uid = request['uid']
        year = str(request['year'])
        rname = request['rname']

        permittedUsers = request['permitted_users']
        adminUser = request['auth'].get('uid')

        try:
            oldReviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

            mongo.setPermissions(uid, year, rname, permittedUsers)

            # While we're setting up permissions, initialize the contributors as well
            mongo.setContributors(uid, year, rname, [])

            templateID = request.get('template_id')
            reviewers = mongo.getPermissions(uid, year, rname)['permitted_users']

            changeType = 'SET_REVIEWER'

            if len(reviewers) == 0:
                if templateID is None:
                    changeType = 'UNASSIGNED'
                else:
                    changeType = 'SET_TEMPLATE'
            else:
                changeType = 'SET_REVIEWER'

            dataReview = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, 'review',
                                                  change_type=changeType)
            mongo.addReview(uid, year, rname, dataReview, 'review')
        except:
            results = {'retVal': False}
        else:
            opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
            emailutils.emailAssigned4Reviewer(set(reviewers) - set(oldReviewers), uid, adminUser, **opts)

            results = {'retVal': True}

        return results

    @utils.validate
    def handler_set_contributors(self, request, _):

        uid = request['uid']
        year = request['year']
        rname = request['rname']

        mode = request['mode']
        contributors = request['users']

        auth = request['auth']
        reviewType = request['review_type']
        adminUser = request['auth'].get('uid')

        if mode == "add":
            mongo.addContributors(uid, year, rname, contributors)

            opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
            emailutils.emailAssigned4Contributor(contributors, uid, adminUser, **opts)
        else:
            mongo.removeContributors(uid, year, rname, contributors)

            # Choosing not to send an email when you remove a reviewer
            pass

        return mongo.getReviewsByUser(uid, year, rname, reviewType, auth=auth)

    @utils.validate_activity
    def handler_setup_review(self, request, _):
        '''
        Admin Operation
        '''

        year = request['year']
        rname = request['rname']
        data = request['data']

        uid = request['auth']['uid']

        try:
            mongo.setupReview(uid, year, rname, data)
        except:
            results = {'retVal': False}
        else:
            results = {'retVal': True}

        return results

    @utils.validate
    def handler_get_feedback(self, request, _):

        uid = request['uid']
        adminUser = request['auth']['uid']

        data = {}

        data['feedbacks'] = mongo.getFeedback(uid, adminUser)

        if data['feedbacks']:
            data['latest_feedback'] = data['feedbacks'][-1]
        else:
            data['latest_feedback'] = utils.createFeedbackPacket(uid, '', adminUser)

        return data

    @utils.validate
    def handler_add_feedback(self, request, _):

        uid = request['uid']
        feedback_body = request['feedback_body']

        adminUser = request['auth'].get('uid')

        change_type = request['change_type'].upper()

        feedback = utils.createFeedbackPacket(uid, feedback_body, adminUser, change_type)

        return mongo.addFeedback(uid, feedback)

    @utils.validate_activity
    def handler_fetch_backlog_stats(self, request, _):
        """
        Returns the number of reviews that aren't complete for a given person.
        Format: {'usinha': 45, 'npai': 56, 'kpriya': 67}
        """
        ret = {}

        review_year = request['review_year']
        review_type = request['review_type']

        # Find a list of unique reviewers
        allPermissions = mongo.getAllPermissions(review_year, review_type)
        for review in allPermissions:
            status = mongo.getReviewLocked(review['uid'], review_year, review_type)

            if not status:
                for u in review['permitted_users']:
                    if not u in ret:
                        ret[u] = 0

                    ret[u] += 1

        retlist = []
        for user, count in ret.items():
            retlist.append({'id': user, 'count': count})
        return retlist

    @utils.validate_activity
    def handler_archive_review(self, request, _):
        year = request['year']
        rname = request['rname']
        mongo.archiveReview(year, rname)

    @utils.validate_activity
    def handler_unarchive_review(self, request, _):

        year = request['year']
        rname = request['rname']
        mongo.unarchiveReview(year, rname)

    def on_close(self):
        """
        Called when a WebSocket connection is dropped
        """


class HTTP2WS(tornado.web.RequestHandler):
    """
    An HTTP -> WS converter. Sometimes you want HTTP, and not WS.
    """

    def get(self, token):

        hostname = socket.gethostname().split(".")[0]
        host_port = "https://%s:%s" % (hostname, tornado.options.options.port)

        self.set_header('Access-Control-Allow-Origin', host_port)
        self.set_header('Content-Type', 'application/json')
        ws = Socket(self.application, self.request)

        #
        # These are the 2 parameters that Socket expects
        #
        # input -
        #
        #  {u'callback_id': u'e780e31a5',
        #   u'request': {u'query': u'', u'type': u'app_metadata'}}

        # request -
        #
        #   {u'query': u', u'type': u'app_metadata'}

        request = {'query': self.get_argument('query', {}), 'type': token}
        # Stuff in `request` with rest of the arguments so that it becomes easier to
        # debug from curl

        keys = [x for x in self.request.arguments.keys() if x != 'request']
        for key in keys:
            try:
                request['query'][key] = json.loads(self.get_argument(key, None))
            except:
                request['query'][key] = self.get_argument(key, None)

        input = {'callback_id': u'http2ws-pseudo-random-id', 'request': request}

        t1 = time.time()

        try:
            response = getattr(ws, "handler_%s" % request['type'])(request['query'], input)
        except Exception, e:
            traceback.print_exc()
            response = e

        t2 = time.time()
        logging.debug('[http2ws:%s]: %s secs', request['type'], t2 - t1)

        dthandler = lambda obj: (
        obj.isoformat() if isinstance(obj, datetime.datetime) or isinstance(obj, datetime.date) else None)
        message = json.dumps(response, default=dthandler)

        size = sys.getsizeof(message)

        logging.debug('[http2ws:%s]: %s bytes', request['type'], size)

        self.write(message)
        self.finish()


handlers = [
    (r'/training-recommendations', RecommendationHandler),
    (r'/static/.*', Static),
    (r'/ws/ip', Socket),
    (r'/wsapi/(?P<token>.*)', HTTP2WS),
    (r'/', Index),
    (r'/login', LoginHandler),
    (r'/logout', LogoutHandler),
    (r'/get_all_users', GetAllUsers),
    (r'/get_active_location_users/(?P<location>.*)', GetActiveLocationUsers),
    (r'/get_user/(?P<uid>.*)', GetUserQuery),
    (r'/avatar/(?P<uid>.*)', Avatar),
    (r'/(.*)', Default)  # When you visit a non-existant link
]

settings = {
    "cookie_secret": "A3D67BA7E8813535E2169125B43D2322FBA647D58DDEC49D97B8",
    "login_url": "/login",
    "debug": True,
}

class TornadoApplication(tornado.web.Application):
    def log_request(self, handler):
        """
        Copy/Pasted from tornado.web.Application.log_request()
        """
        if "log_function" in self.settings:
            self.settings["log_function"](handler)
            return
        if handler.get_status() < 400:
            log_method = logging.info
        elif handler.get_status() < 500:
            log_method = logging.warning
        else:
            log_method = logging.error

        request_time = 1000.0 * handler.request.request_time()

        # jjose
        summary = handler._request_summary()
        summary = summary.replace('127.0.0.1', handler.request.headers.get('X-Forwarded-For', '-unknown-'))

        log_method("%s %.2fms", summary, request_time)

if __name__ == "__main__":

    tornado.options.parse_command_line()

    # Turn debug on to have Tornado restart when you change this file
    # Recommended when you're developing. Dont forget to remove it
    # when you put this in production
    #

    if 'PERFORM_PROD' in os.environ:
        app = TornadoApplication(handlers, **settings)
    else:
        app = TornadoApplication(handlers, **settings)

    app.listen(port=tornado.options.options.port, address='127.0.0.1')

    logging.info('perform has started at %d', tornado.options.options.port)
    tornado.ioloop.IOLoop.instance().start()
