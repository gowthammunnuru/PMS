#!/usr/local/bin/python
#
# Jeffrey Jose | Feb 19, 2015
#

import sys, os
import socket
import path

DEV_HOSTS = [
    'telluride.gld.dreamworks.net',
    'grayfern.anim.dreamworks.com'
]

CNAMES = {
    'magneto.ddu-india.com': 'perform.ddu-india.com',
    'kiwi.ddu-india.com'   : 'performdev.ddu-india.com',
    'telluride.gld.dreamworks.net': 'performdev.gld.dreamworks.net',
    'pandora.gld.dreamworks.net': 'perform.dreamworks.net',
}

def getenv():

    HOST = socket.gethostname()

    if path.path('/etc/perform.conf').exists():
        return 'prod'
    else:
        return 'dev'

def isprod():

    return getenv() == 'prod'

def isdev():

    return getenv() == 'dev'

def getCNAME(host, port):

    # If host is in the CNAME list, its assumed that its running on port 80
    if host in CNAMES:
        return (CNAMES.get(host), 80)
    else:
        return (host, port)
