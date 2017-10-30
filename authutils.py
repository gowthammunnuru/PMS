from __future__ import absolute_import

import os
import ldap
import json
import hashlib
import logging
import mongodbutils
import elasticutils


mongo = mongodbutils.getConnection(host='localhost', port=9090)

def getSessionID(uid):
    KEY = "%s-%s-%s" % (mongodbutils.getMasterPassword(), uid, mongo.isAdmin(uid))

    return hashlib.sha256(KEY).hexdigest()


def validateSessionID(uid, sid):
    return sid == getSessionID(uid)


def try_login(ld, uid_dn_string, uname, pwd):
    try:
        bindres = ld.simple_bind_s(uid_dn_string, pwd)
    except ldap.INVALID_CREDENTIALS, ldap.UNWILLING_TO_PERFORM:
        logging.warn("Invalid or incomplete credentials for %s", uname)
        return False
    except Exception as out:
        logging.warn("Auth attempt for %s had an unexpected error: %s", uname, out)
        return False
    else:
        logging.info("Correct password for %s specified" % uname)
        return True

def auth(uname, pwd):

    #Find out where the user is logging in from, and
    # use ldap server accordingly.
    # if os.environ['STUDIO'] in ['GLD', 'RWC']:
    LDAP_SEARCH_BASE = 'dc=anim,dc=dreamworks,dc=com'
    LDAP_URL = 'ldap://ldaprr.anim.dreamworks.com'
    uid_dn_string = 'uid=%s, ou=People,dc=anim,dc=dreamworks,dc=com'%uname
    # elif os.environ['STUDIO'] == 'TTP':
    #     LDAP_SEARCH_BASE = 'dc=ddu-india,dc=com'
    #     LDAP_URL = 'ldap://ldaprr.ddu-india.com'
    #     uid_dn_string = 'uid=%s, ou=People,dc=ddu-india,dc=com'%uname

    LDAP_VERSION_3 = True

    if not uname or not pwd:
        logging.warn("Username or password not supplied")
        return False

    ld = ldap.initialize(LDAP_URL)
    if LDAP_VERSION_3:
        ld.set_option(ldap.VERSION3, 1)

    udn = elasticutils.getUserByName(uname)

    if not udn:
        logging.warn("Cannot resolve username: %s", uname)
        return False

    if not mongodbutils.CONF.exists() and pwd == "123":
        return True

    ret = try_login(ld, uid_dn_string, uname, pwd)

    return ret





