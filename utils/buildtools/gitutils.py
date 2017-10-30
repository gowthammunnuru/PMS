#!/usr/local/bin/python
#
# An assortment of git functions to query the repository
#
# Jeffrey Jose  | June 26, 2013
#

import os
import re
import subprocess
import logging
# import studioenv
# from studio.system.command import Command

def getCurrentCommit():
    '''
    '''
    commit = runcmd('git rev-parse --short HEAD')[0]

    return commit

def getCurrentBranch():
    '''
    Get current branch
    '''
    branch = runcmd('git rev-parse --abbrev-ref HEAD')[0]
    return branch

def checkoutBranch(branch):
    '''
    Checkout the specified branch
    '''
    return runcmd('git checkout %s' % branch)

def getCurrentRepoRoot():
    '''
    Get the root of the current repo
    '''
    repo = getRoot(os.getcwd())
    return repo

def getTagFromCommit(commit):
    '''
    '''
    try:
        tag = runcmd('git describe --exact-match %s' % commit)[0]
    except IndexError, e:
        raise ValueError('There are no tags for commit %s' % commit)
    else:
        return tag

def getTagish(commit, getMajorTag = False):

    try:
        tag = getTagFromCommit(commit)
        t = tag
    except:
        t, c, h = getDescribe().split('-')
        tag = "%s-%s" % (t, c)
    logging.debug("[Gowthtam]", tag)
    if getMajorTag:
        return tag, t
    else:
        return tag

def getDescribe():
    '''
    '''
    describe = runcmd('git describe --tags')[0]
    return describe

def getAllTags():
    '''
    Get all tags from that commit onwards.
    Note: This isnt *all* the commits
    '''
    result = [x.split(' @@ (') for x in
              runcmd('git log --simplify-by-decoration --decorate --format="%H @@%d"')
              if 'tag:' in x]

    if not result:
        return [(None, None)]

    tags = []
    for commit, taginfo in result:
        try:
            tag = re.search('tag: (\S+)[,)]', taginfo).groups()[0]
        except:
            tag = taginfo.rstrip(')').replace('tag: ', '')

        tags.append((tag, commit))

    return tags

def verifyTag(tag):
    '''
    Verifies whether a tag exists or not
    '''

    allTags = (x[0] for x in getAllTags())

    if not tag in allTags:
        raise ValueError('Tag %s doesnt exist' % tag)


def getNotes(commit):
    '''
    '''
    notes = runcmd('git notes show %s' % commit)
    return notes

def getRoot(path):
    '''
    '''
    root = runcmd('git rev-parse --show-toplevel', cwd = path)[0].rstrip('/')
    return root

def mergeBranch(branch, fastForward = True):
    '''
    Merge branch with/without fastforward
    '''
    if fastForward:
        runcmd('git merge %s' % branch)
    else:
        runcmd('git merge %s --no-ff' % branch)

def addTag(tag, message = None):
    '''
    Add the specified tag, optionally pass the message
    '''

    if message:
        runcmd('git tag -a %s -m "%s"' % (tag, message))
    else:
        runcmd('git tag -a %s' % tag)

def removeTag(tag):
    '''
    Remove the specified tag
    '''

    runcmd('git tag -d %s' % tag)

def runcmd(cmd, cwd = False):
    '''
    Utility Function to run commands
    '''
    if cwd:
        proc = subprocess.Popen(cmd,shell=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,cwd=cwd)
        help(proc)
    else:
        proc = subprocess.Popen(cmd,shell=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        output,error = proc.communicate()
        errcode = proc.returncode
    if errcode == 0:
        return [output.strip()]
    else:
        raise Exception

if __name__ == '__main__':
    from PyQt4 import QtCore; QtCore.pyqtRemoveInputHook(); import pdb; pdb.set_trace()
