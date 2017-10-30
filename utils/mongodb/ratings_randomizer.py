#!/usr/local/bin/python
# ----------------------------------------------------------------------
# TM and (c) 2009 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
# ----------------------------------------------------------------------
"""
Application module for template_name
"""

from __future__ import division

__version__ = "$Id: template_name,v 1.15 2008/04/01 01:31:32 jono Exp $"
__source__ = "$Source: /rel/cvsroot/cmd/src_cmd/src_create/templates/python_program/template_name,v $"
__author__ = "Jeffrey Jose"

# Python Modules
import sys, os
import random
import math

# Studio Modules
import studioenv
import studio.framework.app

from studio.utils.path import Path

import mongodbutils
import templateutils

os.environ['PERFORM_TORNADO_NO_PARSE_COMMANDLINE'] = '1'
import utils

LOREM = [
    '''Lorem ipsum dolor sit amet, at mollis deseruisse eam, veri deterruisset ea sea! Mea malis persequeris et, idque oporteat petentium id vix, ut vel ferri scribentur vituperatoribus. Augue verear aeterno te cum! Phaedrum explicari ut vim, te usu soluta discere lobortis. At his dico autem atqui, iuvaret concludaturque ad mei, et tamquam fabulas cum! Pri meis vocent repudiandae ex, enim mandamus per in, eos dicam luptatum eu! Cum ut fugit melius omnium.

    Inani discere eu usu! Vel veri epicuri eu! Per id commodo deserunt appellantur. Vix inani laoreet in, nullam iuvaret vix in! Vidisse graecis sensibus te quo.

    Dolor postea perfecto nec cu, possit facilis constituam cu sed. Has ex maiorum temporibus. Te sint utamur placerat nam, duo ad eros fastidii. Eu altera volumus pri, zril torquatos referrentur mel an. Labores invenire persequeris id mei.
    ''',

    '''Lorem ipsum dolor sit amet, pro doctus commodo cu? At mel probo honestatis, suas dicit cum in. Sed an possit impedit fierent, sed erat blandit ut, sit velit saperet ne. Modo persius definitionem ut mel, eu impedit delectus sed. Sea ea habemus dissentias, iriure ponderum concludaturque pro eu?

    Aliquando vulputate te vim, fabellas repudiare democritum cu duo? Mea no vide consequuntur concludaturque. Ne apeirian argumentum has. Ex scripta ceteros democritum vim, eum postea melius disputando ad!
    ''',

    '''Lorem ipsum dolor sit amet, eu vis nominavi assentior, mei ne animal epicurei. Ut sit fierent aliquando, vitae instructior id usu! Timeam vivendum vituperata mei te, graece graecis te sea, postulant euripidis sea ut! Novum sensibus assentior ea mei, his enim molestiae id. Sint molestie eloquentiam vix ex, eius comprehensam an eos, pro an purto posidonium!

    Eu erat verear philosophia vel. Veri augue efficiantur ius no! Ei cum justo insolens, eum no decore feugait molestie. Eu vel reque denique, pri stet senserit at.

    Ponderum molestiae per in? Per blandit expetenda te, putant perfecto his an, mei vidisse liberavisse te! Nisl graeco copiosae no per, vel ut agam neglegentur. Ipsum legendos vel ne, brute reque ei pro, quo eu illud omnes. Duis minim invidunt ex eum! Similique delicatissimi in vis, ea eum aliquam laoreet detracto, eam nisl noluisse ullamcorper ne. Aliquid scaevola recusabo vix ex, per purto soluta deterruisset eu, atqui molestiae vis an?
    '''
]

import numpy
import numpy.random

def randomizer(mean, sigma, bins, start, end):

    data = numpy.random.normal(mean * 10, sigma * 5, 1000)

    hist, bins = numpy.histogram(data, bins = bins)

    binMidpoints = bins[:-1] + numpy.diff(bins) / 2

    array = [int(math.floor(x) // 10) for x in binMidpoints]

    result = [max([min([end, x]), start]) for x in array]

    print result
    return result

class App(studio.framework.app.App):
    """
    """

    def addCmdlineFlags(self, cl):
        """Adds command line flags to the application.

        :Parameters:
            cl
                Instance of an studio.utils.cmdline object.
        """
        super(App, self).addCmdlineFlags(cl)

        cl.addFlag('-host <host>', 'The MongoDB host to connect to', default = 'localhost')

        cl.addFlag('-port <port>', 'The MongoDB port to connect to', default = 9090, convert = int)

        cl.addFlag('-type <type>', 'Review type to target (review, self-review)', default = 'review')

        cl.addFlag('-user ...', 'Users to work on', flagAliases=['-users'])
        cl.addFlag('-year <type>', 'Review Year')
        cl.addFlag('-rname <type>', 'Review Name (ex: annual, intern, probation)')

        cl.addFlag('-commit', 'Mark the new review as committed')
        cl.addFlag('-readyToPublish', 'Mark the new review as ready2publish')
        cl.addFlag('-publishReview', 'Mark the new review as published')
        cl.addFlag('-acknowledgedReview', 'Mark the new review as acknowledeged')

        cl.addFlag('-rating <val>', 'Force this rating', convert = int)
        cl.addFlag('-text <text>',  'Force this text')

        cl.addFlag('-percent <percent>', 'Complete only so much percentage', default = 100, convert = int)

        cl.addFlag('-rating_start <num>', 'Dont go lesser than this value with rating.', default = 0, convert = int)
        cl.addFlag('-rating_end <num>', 'Dont go greater than this value with rating.', default = 6, convert = int)
        cl.addFlag('-rating_mean <num>', 'The mean', default = 4, convert = int)

        cl.addFlag('-no_shuffle', 'Pass this flag to shuffle the random (normal distribution) ratings')

    def configureOptions(self, opts):
        """Configures the application options.

        :Parameters:
            opts
                Dictionary of options parsed from command line flags.
        """

        opts = super(App, self).configureOptions(opts)

        if self.opts['rating'] and not (0 <= self.opts['rating'] <=6 ):
            raise ValueError('-rating should be a integer between 0 and 6')

        users = []
        for user in self.opts['user']:
            users.extend(user.split('+'))


        self.opts['user'] = users

        return opts

    def getModelKeys(self, template, token = 'ratings'):

        keys = [x for x in template['modelkeys'] if x.startswith(token)]

        pickCount =  int(math.floor(len(keys) * (self.opts['percent']/100)))

        return keys[:pickCount]

    def addRandomReviewData(self, uid, year, rname, reviewType, commit=False, readyToPublish=False, publishReview=False, acknowledgedReview=False):
        latestReview = self.mongo.getReviewsByUser(uid, year, rname, reviewType, {'uid': os.getenv('USER')})[-1]
        latestTemplate = templateutils.getTemplate(latestReview['template_id'])

        body = {}

        if self.opts['rating'] is not None:
            ratings = [self.opts['rating'] for x in self.getModelKeys(latestTemplate, 'ratings')]
        else:
            ratings = randomizer(self.opts['rating_mean'], 1, len(self.getModelKeys(latestTemplate, 'ratings')), self.opts['rating_start'], self.opts['rating_end'])

            if not self.opts['no_shuffle']:
                # Inplace shuffle
                numpy.random.shuffle(ratings)

        for rating, key in zip(ratings, self.getModelKeys(latestTemplate, 'ratings')):

            body[key] = rating

        for key in self.getModelKeys(latestTemplate, 'notes'):

            if self.opts['text']:
                text = self.opts['text']
            else:
                text = random.choice(LOREM)

            body[key] = text

        reviewers = self.mongo.getPermissions(uid, year, rname)

        packet_type = 'REVIEW_DRAFT'
        if commit:
            packet_type = 'COMMIT_REVIEW'
        if readyToPublish:
            packet_type = 'READY2PUBLISH'
        if publishReview:
            packet_type = 'PUBLISH_REVIEW'
        if acknowledgedReview:
            packet_type = 'ACKNOWLEDGE_REVIEW'

        packet = utils.createReviewPacket(uid, year, rname, body, latestReview['template_id'], reviewers['permitted_users'], os.getenv('USER'), reviewType, change_type=packet_type)

        print "Saving random ratings for %s-%s-%s (%s)" % (uid, year, rname, reviewType)
        self.mongo.addReview(uid, year, rname, packet, reviewType, diffSave = True)


    def main(self):
        """Application entry point."""
        super(App, self).main()

        self.mongo = mongodbutils.MongoDB(self.opts['host'], self.opts['port'])

        reviewType = self.opts['type']
        year       = self.opts['year']
        rname      = self.opts['rname']
        commit     = self.opts['commit']
        readyToPublish=self.opts['readyToPublish']
        publishReview=self.opts['publishReview']
        acknowledgedReview=self.opts['acknowledgedReview']

        for uid in self.opts['user']:
            print "Working on %s" % uid
            self.addRandomReviewData(uid, year, rname, reviewType, commit, readyToPublish, publishReview, acknowledgedReview)


if __name__ == '__main__':
    App().run()


# ----------------------------------------------------------------------
# TM and (c) 2009 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
# ----------------------------------------------------------------------
