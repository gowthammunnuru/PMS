from __future__ import absolute_import

import os
import pytz
import time
import logging
import itertools
import subprocess
import mongodbutils
from multiprocessing.pool import ThreadPool
import datetimeutils
import authutils

import tornado.ioloop
import tornado.options

if 'PERFORM_TORNADO_NO_PARSE_COMMANDLINE' not in os.environ:
    tornado.options.parse_command_line()

SETUP_DONE_STATE = 'SETUP_DONE'

ASSIGN_STATES = ['SET_TEMPLATE', 'SET_REVIEWER','UNASSIGNED']

ACKNOWLEDGE_STATES = ['ACKNOWLEDGE_REVIEW']

LOCK_STATES = ['PUBLISH_REVIEW']

COMMIT_STATES = ['COMMIT_REVIEW', 'ADD_FEEDBACK', 'READY2PUBLISH']

_workers   = ThreadPool(10)

mongo = mongodbutils.getConnection(host='localhost', port=9090)

def run_background(func, callback, errback, args = (), kwds = {}):
    ioloop = tornado.ioloop.IOLoop.instance()

    def _callback(result):
            ioloop.add_callback(lambda: callback(*result))

    def wrap_in_errback(func):
        '''
        Instead of having _workers.apply_async call func()
        directly, in which case we lose Exception, have it call
        this function which will call our errback in case of some trouble
        '''

        def wrapped(*args, **kwargs):

            try:
                return func(*args, **kwargs)
            except Exception, e:
                print traceback.print_exc()
                errback(e, *args, **kwargs)

        return wrapped

    _workers.apply_async(wrap_in_errback(func), args, kwds, _callback)

def on_complete(response, input):

    self.respond(input, response)

def on_error(error, request, input):

    self.respondError(repr(error), request, input)

    # Raise exception here so as to break the flow.
    # returning something will have multiprocessing.Pool call the callback method
    raise ValueError(error)

def createReviewPacket(uid, year, rname, review_body, template_id, reviewers, reviewer, review_type, change_type='REVIEW_DRAFT'):

    if change_type in COMMIT_STATES + LOCK_STATES + ACKNOWLEDGE_STATES:
        committed = True
    else:
        committed = False

    # If its a self-review, act of marking as committed should locked the review as well
    if change_type in LOCK_STATES or (review_type == 'self-review' and committed):
        locked = True
    else:
        locked = False

    acknowledged = change_type in ACKNOWLEDGE_STATES

    # FIXME
    # We shouldnt be doing this, but I dont have time now
    # -jeff
    #
    # Ideally acknowledged would domino-trump everything, as opposed to
    # trumping everything at the end.
    if acknowledged:
        committed = True
        locked = True

    packet = {
        'uid': uid,
        'year': year,
        'rname': rname,
        'review_body': review_body,
        'template_id': template_id,
        'all_reviewers': reviewers,
        'reviewer': reviewer,
        'change_type': change_type,
        'locked': locked,
        'committed': committed,
        'acknowledged': acknowledged,
        'datetime': datetimeutils.timenow()
    }

    return packet


def createFeedbackPacket(uid, feedback_body, reviewer, change_type='SAVE_DRAFT'):

    if change_type in COMMIT_STATES + LOCK_STATES:
        committed = True
        locked = True
    else:
        committed = False
        locked = False

    packet = {
        'uid': uid,
        'feedback_body': feedback_body,
        'reviewer': reviewer,
        'change_type': change_type,
        'locked': locked,
        'committed': committed,
        'datetime': datetimeutils.timenow(),
    }

    return packet


def reviewSummary(reviews):

    summary = {'data': {}, 'years': set()}

    reviews = sorted(reviews, key=lambda x: (x['year'], x['rname']))
    for (year, rname), r in itertools.groupby(reviews, lambda x: (x['year'], x['rname'])):

        latestReview = list(r)[-1]
        summary['data'].setdefault(year, {})[rname] = removeSensitiveInfo(latestReview)
        summary['years'].add(year)

    return summary


def removeSensitiveInfo(review):
    if isLocked(review):
        return review
    else:
        review['review_body'] = {}
        return review


def isLocked(review):
    return review['change_type'] in LOCK_STATES


def validate(fn):
    """
    Session ID validator
    """

    def wrapper(self, request, input):

        uid = request['auth']['uid']
        sid = request['auth']['sid']

        if authutils.validateSessionID(uid, sid):
            logging.debug("User %s has a valid session id %s", uid, sid)
            return fn(self, request, input)
        else:
            logging.debug("Invalid session id %s for user %s", sid, uid)
            return {'error': 'auth_error'}

    return wrapper


def validate_admin(fn):
    """
    Validates whether a user is admin or not (in addition to the default `sid` validation)
    """

    def wrapper(self, request, input):

        uid = request['auth']['uid']

        if mongo.isAdmin(uid):
            logging.debug("User %s is an admin", uid)
            return fn(self, request, input)
        else:
            logging.error("User %s is not an admin", uid)
            return {'error': 'auth_error'}

    return validate(wrapper)

#Activity based checks, google it
def validate_activity(fn):
    """
    Validates whether a user has permissions to perform the activity (in addition to the default `sid` validation)
    """

    def wrapper(self, request, input):

        uid = request['auth']['uid']
        activity = request['activity']

        if mongo.activityAuthorized(uid, activity):
            logging.debug("User %s is authorized to perform this activity", uid)
            return fn(self, request, input)
        else:
            logging.error("User %s is not authorized to perform this activity", uid)
            return {'error': 'auth_error'}

    return validate(wrapper)

#Check if user has busy button
def is_my_turn(fn):
    """
     Checks whether a user holds the busy button lock and is allowed to edit the review.
    """

    def wrapper(self, request, input):

        auth_uid = request['auth']['uid']
        uid = request['uid']
        year = request['year']
        rname = request['rname']
        reviewType = request['review_type']
        results = mongo.getBusyReviewer(uid, year, str(rname), "isBusy")
        if reviewType != 'self-review' and not mongo.isAdmin(auth_uid):
            if results:
                if auth_uid == results['isCurrentlyEditedBy']:
                    logging.debug("User %s holds the busy button", auth_uid)
                    print "User %s holds the busy button", auth_uid
                    return fn(self, request, input) 
                elif results['isCurrentlyEditedBy'] == 'admin':
                    mongo.updateIsBusyReviewer(uid, year, str(rname), "isBusy", True, auth_uid)
                else:
                    logging.error("User %s does not hold busy button, needs to wait", auth_uid)
                    return {'error': 'waitlist_error', 'isCurrentlyEditedBy':results['isCurrentlyEditedBy'], 'uid': uid, 'year': year, 'rname': rname}
            else:
                 mongo.updateIsBusyReviewer(uid, year, str(rname), "isBusy", True, auth_uid)
        return fn(self, request, input)         
    return validate(wrapper)



class AsyncProcess(object):
    """An non-blocking process
    Example usage:
        class MainHandler(tornado.web.RequestHandler):
            @tornado.web.asynchronous
            def get(self):
                proc = AsyncProcess()
                proc.execute('sleep 5; cat /var/run/syslog.pid',
                           self.async_callback(self.on_response))
            def on_response(self, output):
                self.write(output)
                self.finish()
    execute() can take a string command line.
    """
    def __init__(self, io_loop=None):
        self.io_loop = io_loop or tornado.ioloop.IOLoop.instance()

    def execute(self, command, callback, **kargs):
        self.pipe = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, **kargs).stdout
        self.callback = callback

        self.io_loop.add_handler(self.pipe.fileno(), self._handle_events, self.io_loop.READ)

    def _handle_events(self, fd, events):
        """Called by IOLoop when there is activity on the pipe output. """
        self.io_loop.remove_handler(fd)
        output = ''.join(self.pipe)
        return self.callback(output)


def localtime(dt):
    """
    Converts UTC datetime object to IST or PST/PDT
    """

    if not dt:
        return dt

    # Incoming datetime object must be in UTC
    dt = pytz.utc.localize(dt)

    tzname = time.tzname[0]

    tz = 'US/Pacific'

    if tzname == 'IST':
        tz = 'Asia/Calcutta'

    return dt.astimezone(pytz.timezone(tz))
