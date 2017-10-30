from __future__ import absolute_import

import path
import json
import logging
import datetime
import tornado.template

import mail
import misc
import utils
import directory
import templateutils
import elasticutils
import random



TEMPLATE = '''
<html>
<head>
</head>

<body>
    <div style="width:100%%;padding:24px 0px 16px 0px; background-color: #f5f5f5;text-align: center;">
        <div style="display:inline-block;width: 90%%;max-width: 680px;min-width: 280px;text-align:left;font-family:'PT Sans', sans-serif;">
            <a href="http://%(host)s"><img src="http://%(host)s/static/media/images/logo.email.png" style="max-height:35px;margin-bottom:10px;"/></a>
            <div style="display: block; padding: 0 2px;"> <div style="display: block; background: #fff; min-height: 2px;"> </div> </div>
                <div style="border-left: 1px solid #f0f0f0;boder-right: 1px solid #f0f0f0">
                    <img src="http://%(host)s/avatar/%(reviewuser)s" style="height:100px;width:100px;border-radius:50%%;float:right;margin-right:25px;margin-top:13px;"/>
                    <div style="padding: 24px 42px 32px 32px; background: #fff;border-right:1px solid #eaeaea; border-left: 1px solid #eaeaea;border-bottom: 2px solid #eaeaea;">

                        <h3 style="margin-top:0px;">%(heading)s</h3>
                        <div>%(description)s</div>
                        <div style="margin-top:15px;">
                            <a href="http://%(host)s/%(link)s" style="background-color:#009688;color:white;padding:5px 10px;cursor:pointer;font-size: 12px;text-decoration:none;">Open in perform</a>

                         </div>

                    </div>
                    <p style="float:right;color:#9D9D9D;font-size:12px;" title="With <3 from %(host)s at %(datetime)s">This email was sent by perform</p>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
'''

EMAILDATA = {
    'assigned4reviewer': {
        'subject': "You have been assigned as a reviewer for %(reviewuser_name)s",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Assigned',
            'description': 'You have been assigned as a reviewer for %(reviewuser_name)s',
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'selfreviewreminder': {
        'subject': "Your self review for %(review_desc)s is pending",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Pending',
            'description': 'Please submit your self review for %(review_desc)s',
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'assigned4employee': {
        'subject': "Your self review for %(review_desc)s is now open for editing",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Pending',
            'description': 'Please submit your self review for %(review_desc)s',
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'reviewcommitted': {
        'subject': "%(admin_name)s has committed %(reviewuser_name)s's review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Committed',
            'description': "%(admin_name)s has committed %(reviewuser_name)s's review",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'selfreviewcommitted4reviewer': {
        'subject': "%(reviewuser_name)s has committed his/her self review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Committed',
            'description': "%(reviewuser_name)s has committed his/her self review",
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'selfreviewcommitted4employee': {
        'subject': "Your self review has been committed",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Committed',
            'description': "Your self review has been committed",
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'reviewuncommitted': {
        'subject': "%(admin_name)s has uncommitted %(reviewuser_name)s's review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Uncommitted',
            'description': "%(admin_name)s has uncommitted %(reviewuser_name)s's review",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'selfreviewuncommitted4employee': {
        'subject': "%(admin_name)s has uncommitted your self review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Uncommitted',
            'description': "%(admin_name)s has uncommitted your selfreview",
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'selfreviewuncommitted4reviewer': {
        'subject': "%(admin_name)s has uncommitted %(reviewuser_name)s's self review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Self Review Uncommitted',
            'description': "%(admin_name)s has uncommitted %(reviewuser_name)s's selfreview",
            'link': 'selfreview/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'ready2publish': {
        'subject': "%(reviewuser_name)s's review is ready to publish",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Ready to Publish',
            'description': "%(admin_name)s has reviewed %(reviewuser_name)s's review and is now ready to publish",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'published4reviewer': {
        'subject': "%(admin_name)s has published %(reviewuser_name)s's review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Published',
            'description': "%(admin_name)s has published %(reviewuser_name)s's review",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'published4employee': {
        'subject': "Your %(review_desc)s is now ready to view",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Published',
            'description': 'Your review is now ready to view',
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'acknowledged4reviewer': {
        'subject': "%(reviewuser_name)s has acknowledged his/her review",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Acknowledged',
            'description': "%(reviewuser_name)s has acknowledged his/her review",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'acknowledged4employee': {
        'subject': "You have acknowledged your %(review_desc)s",
        'body': TEMPLATE,
        'params': {
            'heading': 'Review Acknowledged',
            'description': "You have acknowledged your %(review_desc)s",
            'link': 'review/%(reviewuser)s/%(review_year)s/%(review_rname)s'
        }
    },

    'addcontributor': {
        'subject': "Please provide feedback for %(reviewuser_name)s",
        'body': TEMPLATE,
        'params': {
            'heading': 'Feedback Requested',
            'description': "Please provide feedback for %(reviewuser_name)s",
            'link': 'feedback/%(reviewuser)s'
        }

    }

}

PDFTEMPLATE = tornado.template.Loader('./static/partials/').load('user.pdf.html')
PDFDIR = path.path('/usr/pic1/perform.pdf/')
PDFEXE = path.path(__file__).abspath().parent
try:
    PDFDIR.mkdir()
except:
    pass

# TODO
# self-review: committed emails
# review: committed, published

HOSTPORT = {}


def registerHost(host, port):
    """
    """

    global HOSTPORT

    host, port = misc.getCNAME(host, port)

    HOSTPORT = {'host': host, 'port': port}


if misc.isprod():
    GLOBAL_CC_LIST = ['perform-hr@dreamworks.com'] #['perform-hr@ddu-india.com'] #'perform-hr@ddu-india.com'
else:
    GLOBAL_CC_LIST = ['performdev-hr@dreamworks.com'] #'perform-dev@ddu-india.com'


def _send(token, toUser, fromUser, attachment=None, *args, **kwargs):
    """
    Note - attachment can only take one single file
    """
    params = kwargs.get('params')


    uidList = [fromUser] + toUser + GLOBAL_CC_LIST

    userEmailData = elasticutils.getManyUserEmailData(uidList)

    print params

    # Update the incoming params with the params from EMAILDATA
    for (k, v) in EMAILDATA[token]['params'].items():
        params[k] = v % params

    # params.update(HOSTPORT)
    params['datetime'] = datetime.datetime.now().strftime('%e %b %Y %H:%M:%S%p')

    subject = EMAILDATA[token]['subject'] % params
    body = EMAILDATA[token]['body'] % params

    if not userEmailData.get(fromUser):
        logging.warn("Couldn't get user details for email: %s", fromUser)
    else:
        senderName = userEmailData.get(fromUser)[0]
        fromEmail = userEmailData.get(fromUser)[1]

    toEmails = []
    for to in set(toUser + GLOBAL_CC_LIST):
        try:
            toEmail = userEmailData.get(to)[1]
        except:
            toEmail = to

        toEmails.append(toEmail)

    attachments = []
    if attachment:
        attachments = [attachment]

    pdfInfo = ' + PDF' if attachment else ''

    if misc.isprod():
        logging.info('[EMAIL%s] (%20s) %s -> %s', pdfInfo, token, fromEmail, toEmails)
        mail.mail(fromEmail, toEmails, body, subject=subject, sender_name=senderName, format_html=True,
                  attachments=attachments)
    else:
        
        #We will MOCK send mails only from the portal-dev group.

        mockFromPeople = {'Archana Rajkumar':'archana.rajkumar@ddu-india.com','Maninya M':'maninya.m@ddu-india.com', 
                      'Jaya Kumaran':'jaya.kumaran@ddu-india.com', 'Rahul Mendiratta':'rahul.mendiratta@ddu-india.com',
                      'Sriram Viswanathan':'Sriram.Viswanathan@ddu-india.com','Gowtham Munnuru':'gowtham.munnuru@ddu-india.com'}

        mockFromName = mockFromPeople.keys()[random.randrange(len(mockFromPeople.keys()))]

        subject = "MOCK sent mail for %s: %s (%s)" % (senderName, subject, ", ".join(toEmails))

        toEmails = ['performdev-hr@dreamworks.com']

        logging.info('[EMAIL%s (MOCK) for %s] (%20s) %s -> %s', pdfInfo, fromEmail, token, mockFromPeople[mockFromName], toEmails)
        
        mail.mail(fromEmail, toEmails, body, subject=subject, sender_name=senderName, format_html=True,
                  attachments=attachments)

        # if attachment:
        #    pdf = path.path(attachment)
        #    html = path.path(pdf.parent / "%s.html" % pdf.namebase)

        #    pdf.unlink()
        #    html.unlink()


def send(*args, **kwargs):
    """
    To send a pdf attachment, ensure that you pass
        - params (dict)
        - review (dict)
        - pdf    (bool = True)
    """
    try:
        if kwargs.get('pdf'):
            review = kwargs.get('review')
            params = kwargs.get('params')

            params['review_year'] = review['latest_review']['year']
            params['review_rname'] = review['latest_review']['rname']

            # This is asynchronous
            callback = lambda pdf: _send(attachment=pdf, *args, **kwargs)
            makePDF(review, params, callback=callback)
        else:
            # Synchronous
            _send(*args, **kwargs)
    except Exception, e:
        logging.error(e)


def createOpts(token, params):
    """
    Create a new dict based on the params with

     <token>_<key> : <value>
     <token>_<key> : <value>

     ...

    """

    opts = {}

    for (k, v) in params.items():
        opts[str("%s_%s" % (token, k))] = v

    return opts


def getParams(reviewUser, admin, **kwargs):
    admin_data = elasticutils.getUserByName(admin)
    if not admin_data:
        logging.warn("Couldn't get user details for email: %s", admin)
    params = {
        'reviewuser': reviewUser,
        'reviewuser_name': elasticutils.get_name_by_user(reviewUser),
        'admin': admin_data.get("cn"),
        'admin_name': admin_data.get("cn")
    }

    params.update(kwargs)
    params.update(HOSTPORT)

    if 'review_desc' not in params:
        params['review_desc'] = 'No Description'

    return params


def emailAssigned4Reviewer(reviewers, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    for reviewer in reviewers:
        send('assigned4reviewer', [reviewer], admin, params=params)


def sendSelfReviewReminder(reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('selfreviewreminder', [reviewUser], admin, params=params)


def emailAssigned4Employee(reviewers, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('assigned4employee', [reviewUser], admin, params=params)


def emailCommitted(reviewers, reviewUser, admin, review, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    if admin == reviewUser:
        send('selfreviewcommitted4reviewer', reviewers, admin, params=params)
        send('selfreviewcommitted4employee', [reviewUser], admin, params=params, review=review, pdf=True)
    else:
        send('reviewcommitted', reviewers, admin, params=params)


def emailReviewUncommitted(reviewers, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('reviewuncommitted', reviewers, admin, params=params)


def emailSelfReviewUncommitted(reviewers, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('selfreviewuncommitted4employee', [reviewUser], admin, params=params)
    send('selfreviewuncommitted4reviewer', reviewers, admin, params=params)


def emailAcknowledged(reviewers, reviewUser, admin, review, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('acknowledged4reviewer', reviewers, admin, params=params, review=review)
    send('acknowledged4employee', [reviewUser], admin, params=params, review=review)


def emailAssigned4Contributor(contributors, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    for contributor in contributors:
        params['contributor'] = contributor
        params['contributor_name'] = elasticutils.get_name_by_user(contributor)

        send('addcontributor', [contributor], admin, params=params)


def emailReady2Publish(reviewers, reviewUser, admin, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)

    send('ready2publish', reviewers, admin, params=params)


def emailPublished(reviewers, reviewUser, admin, review, **kwargs):
    params = getParams(reviewUser, admin, **kwargs)
    send('published4reviewer', reviewers, admin, params=params, review=review)
    send('published4employee', [reviewUser], admin, params=params, review=review)

def getReviewHash(review):
    latest = review['latest_review']

    uid = latest['uid']
    year = latest['year']
    rname = latest['rname']
    datetime = latest['datetime']
    body = json.dumps(latest['review_body'])

    return hash("%s-%s-%s-%s-%s" % (uid, year, rname, datetime, body))


def getAttachmentFilename(review, params, ext='pdf'):
    reviewhash = getReviewHash(review)

    filename = "%s.%s.%s.%s.%s" % (
        params['reviewuser_name'].replace(' ', '.'),
        params['review_year'],
        params['review_desc'].replace(' ', '.'),
        review['latest_review']['review_type'],
        ext
    )

    tmpDir = PDFDIR / str(reviewhash)

    try:
        tmpDir.mkdir()
    except:
        pass

    return "%s/%s" % (tmpDir, filename)


def makePDF(review, params, callback):
    html = makeHTML(review, params)

    htmlfile = getAttachmentFilename(review, params, 'html')
    pdffile = getAttachmentFilename(review, params, 'pdf')

    if path.path(pdffile).exists():
        logging.info("[email]: Found in cache (%s)", pdffile)
        return callback(pdffile)

    logging.info(htmlfile)
    logging.info(pdffile)
    fp = open(htmlfile, 'w')
    fp.write(html)
    fp.close()

    process = utils.AsyncProcess()

    # cmd = "html2pdf --margin-top 0 --margin-right 0 --margin-bottom 0 --margin-left 0
    # --quiet --print-media-type %s %s " % (htmlfile, pdffile)
    cmd = "%s/html2pdf --quiet --print-media-type %s %s " % (PDFEXE, htmlfile, pdffile)

    return process.execute(cmd, lambda x: callback(pdffile))


def makeHTML(review, params):
    """
    This is used only for generating markup to send to the PDF service
    """

    values = {}
    values.update(params)

    values['user_designation'] = ''  # FIXME

    values['timeline'] = dict((x, utils.localtime(y)) for x, y in review['timeline'].items())

    values['review_type'] = review['latest_review']['review_type']

    if review['latest_review']['review_type'] == "review":
        reviewers = list(set(review['permitted_users']) - set([review['latest_review']['uid']]))
        contributors = review['contributors']
        values['reviewed_by'] = "Reviewed by: %s" % ", ".join(
            [elasticutils.get_name_by_user(x) for x in list(reviewers) + contributors])
    else:
        values['reviewed_by'] = "Self Review"

    # Figure out details from the
    values['parameters'] = {}
    # values['ratings_title'] = ['Too new / NA', 'Imp needed', 'Inconsistent', 'Developing', 'Achieves', 'Achieves+', 'Exceeds', 'No rating']
    values['ratings_title'] = ['Too new / NA', 'Improvement needed', 'Partially Meets', 'Achieves', 'Achieves+', 'Exceeds', 'No rating']
    values['notes'] = {}

    template = templateutils.getTemplate(review['latest_review']['template_id'])

    #
    # Ratings (Part I)
    #
    ratingsHTML = template['section']['ratings']['html']
    ratings = templateutils.parseRatings(ratingsHTML)

    values['ratings'] = []

    for block in ratings:

        blockdata = {
            'blocktitle': block['blocktitle'],
            'criteria': []
        }

        for i, modelkey in enumerate(block['modelkeys']):
            r = review['latest_review']['review_body'].get(modelkey, 7)  # 7 = "No rating."

            data = {
                'rating': r,
                'name': block['criteria'][i]
            }

            blockdata['criteria'].append(data)

        values['ratings'].append(blockdata)

    #
    # Notes (Part 2)
    #
    notesHTML = template['section']['notes']['html']
    notes = templateutils.parseNotes(notesHTML)

    values['notes'] = []

    for note in notes:
        notedata = {
            'notetitle': note['notetitle'],
            'text': review['latest_review']['review_body'].get(note['modelkey'], 'No comments').replace('\n', '<br/>')
        }

        values['notes'].append(notedata)

    return PDFTEMPLATE.generate(**values)


if __name__ == '__main__':
    registerHost('fireodd.ddu-india.com', 8888)

    import mongodbutils

    mongo = mongodbutils.getConnection(host='localhost', port=9090)

    # Fetch data for a specific user
    review_self = mongo.getReviewsByUser('ajmohan', 2015, 'annual', 'self-review', {'uid': 'jjose'})

    review = mongo.getReviewsByUser('ajmohan', 2015, 'annual', 'review', {'uid': 'jjose'})

    # Generate data used by _send
    review_to_pass = {}
    review_to_pass['latest_review'] = review_self[-1]
    review_to_pass['reviews'] = review_self
    review_to_pass['committed'] = False
    emailPublished(['jjose'], 'usinha', 'jjose', review_to_pass, review_desc='Annual Performance Review')

    # reviews require some extra data
    review_to_pass = {}
    review_to_pass['latest_review'] = review[-1]
    review_to_pass['reviews'] = review
    review_to_pass['permitted_users'] = mongo.getPermissions('ajmohan', '2015', 'annual')['permitted_users']
    review_to_pass['contributors'] = mongo.getContributors('ajmohan', '2015', 'annual')['contributors']
    review_to_pass['acknowledged'] = False
    review_to_pass['published'] = False

    emailPublished(['usinha'], 'ajmohan', 'usinha', review_to_pass, review_desc='Annual Performance Review')
