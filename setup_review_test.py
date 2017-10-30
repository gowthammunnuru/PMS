#!/bin/env python
# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.

import sys
from pymongo import Connection
from mongodbutils import MongoDB
import utils
import emailutils
import socket


class MongoDB_test(MongoDB):
    
    def __init__(self, host="localhost", port=9090, dbname='perform'):
        super(MongoDB_test, self).__init__(host, port, dbname)

    def delete_all_collections(self):
        col_list = ['reviews', 'self-reviews', 'permissions', 'contributors', 'setup-review', 'feedbacks', 'ninebox-weights-performance', 'ninebox-weights-potential']
        existing_col_list = self.db.collection_names()
        for i in col_list:
            if i in existing_col_list:
                self.db.drop_collection(i)

    def delete_collection(self, collection):
        self.db.remove(collection)

    def add_admin(self, uid="ageorge"):

        permissions = ["EDIT_REVIEWS", "SETUP_REVIEWS"]
        department = "Human Resources"
        roles = "HR_REVIEWER"

        collection = self.db['admins']
        collection.update({'uid':uid}, {'$set':{'uid':uid, 'uname':"Adheena George", 'permissions':permissions,'ou':department, 'roles':roles}}, True)


def add_review_cycle(rname="2016_testreview"):
    mongo.setupReview(uid="jkumaran", year=2016, rname=rname, data={})

def assign_template_reviewer(uid="jkumaran", rname="2016_testreview", templateID="2016/animator", reviewers=["arajkumar", "mthiyagar"]):
    adminUser = "jkumaran"
    changeType = "SETUP_DONE"
    year = "2016"
    
    mongo.setPermissions(uid, year, rname, reviewers)
    dataReview = utils.createReviewPacket(uid, year, rname, {}, templateID, reviewers, adminUser, 'review', change_type=changeType)

    dataSelfReview = utils.createReviewPacket(uid, year, rname, {}, templateID, [uid], adminUser, 'self-review', change_type=changeType)

    results = mongo.addReview(uid, year, rname, dataReview, 'review')
    results = mongo.addReview(uid, year, rname, dataSelfReview, 'self-review')

    #Skip email sending for now.
    # opts = emailutils.createOpts('review', mongo.getsetReviewMetadata(uid, year, rname))
    # emailutils.emailAssigned4Employee(reviewers, uid, adminUser, **opts)





if __name__ == "__main__":
    hostname = socket.gethostname()
    if hostname.startswith(("tonido", "numbace")):
        mongo = MongoDB_test(host="localhost", port=9090, dbname='perform')
        mongo.delete_all_collections()
        add_review_cycle()
        assign_template_reviewer()
        mongo.add_admin()
    else:
        print "This script works only on machine tonido! Exiting..."
        sys.exit(1)



# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
