#!/usr/local/bin/python

# ----------------------------------------------------------------------
# TM and (c) 2015 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
# ----------------------------------------------------------------------
"""
Utility for testing out PDF Service functionality
"""

__author__ = "Navin Pai"

# Python Modules
import sys, os
import random
import math
import urllib

from tornado.httpclient import AsyncHTTPClient
import tornado.ioloop

# Studio Modules
import studioenv
import studio.framework.app

import argparse

from studio.utils.path import Path

OUTFILE = '/tmp/tmp.pdf'

class App():

    def __init__(self):

        self.args = self.Parser()
        self.main()

    def Parser(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('-host <host>', help='The PDFservice host to connect to', default = 'localhost')

        parser.add_argument('-port <port>', help='The PDFservice port to connect to', default = 8090)

        parser.add_argument('-infile <infile>', help='the HTML input file eg. /tmp/main.html', required = True)

        parser.add_argument('-out <outfile>', help='the location where to save the PDF output file eg. /tmp/abc.pdf', required =True)

        args = parser.parse_args()

        return args

    def configureOptions(self, opts):
        """Configures the application options.

        :Parameters:
            opts
                Dictionary of options parsed from command line flags.
        """

        opts = super(App, self).configureOptions(opts)

        return opts

    def pdf_response(self, response):
        global OUTFILE
        try:
            pdf_data = response.buffer.read()
            tmpfile = OUTFILE

            fp = open(tmpfile, 'w')
            fp.write(pdf_data)
            fp.close()

            print 'CREATED' , OUTFILE
        except Exception as e:
            print "\n\nXXXXXXXXXXXXXXX Exception Occurred: XXXXXXXXXXXXX"
            print "Check if PDFService host is up and running on the mentioned port"
        
        finally:
            tornado.ioloop.IOLoop.instance().stop()

        return
    
    def main(self):
        """Application entry point."""
        super(App, self).main()

        global OUTFILE 
        
        # OUTFILE = self.opts['out']
        OUTFILE = self.args.out
       
        input_file = open(self.args.infile)

        post_data = {}    
        post_data['data'] = input_file.read()

        body = urllib.urlencode(post_data)
        
        if self.args.host.find('http://') == -1:
            host = 'http://'+self.args.host
        else:
            host = self.args.host

        port = str(self.args.port)

        print "Sending", self.args.infile, "to PDFService at", host, "on port", port 

        http_client = AsyncHTTPClient()
        
        http_client.fetch(host + ':' + port, self.pdf_response, method = 'POST', headers = None, body = body)
        tornado.ioloop.IOLoop.instance().start()
       


if __name__ == '__main__':
    App()


# ----------------------------------------------------------------------
# TM and (c) 2009 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
#
