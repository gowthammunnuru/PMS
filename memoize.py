from __future__ import absolute_import

import time
import logging

CACHE = {}

THRESHOLD = 1 * 60 * 60  # 1hr


def get(key):

    global CACHE, THRESHOLD

    now = time.time()

    (cachedTime, cached) = CACHE.get(key, (now, None))

    if cached and (now - cachedTime) < THRESHOLD:
        # print '[MEMOIZE]: Returning cached for %s' % key
        return cached
    elif cached and (now - cachedTime) > THRESHOLD:
        logging.info('[MEMOIZE]: Found cached for %s, but old', key)
        return None


def getset(key, value):

    global CACHE, THRESHOLD

    now = time.time()

    logging.info('[MEMOIZE]: Saving %s in cache', key)
    CACHE[key] = (now, value)

    return value


def memoize(fn):

    def wrapper(key):

        cached = get(key)

        if cached:
            return cached
        else:
            result = getset(key, fn(key))
            return result

    return wrapper
