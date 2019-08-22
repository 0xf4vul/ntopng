#!/usr/bin/env python3

# (C) 2013-19 - ntop.org
# Author: Simone Mainardi <mainardi@ntop.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

import argparse
import signal
import sys
from functools import partial
import ssl
import urllib.request
import base64
import json

__version__ = '1.0.0'

def output(label, state = 0, lines = None, perfdata = None, name = 'ntopng'):
    if lines is None:
        lines = []
    if perfdata is None:
        perfdata = {}

    pluginoutput = ""

    if state == 0:
        pluginoutput += "OK"
    elif state == 1:
        pluginoutput += "WARNING"
    elif state == 2:
        pluginoutput += "CRITICAL"
    elif state == 3:
        pluginoutput += "UNKNOWN"
    else:
        raise RuntimeError("ERROR: State programming error.")

    pluginoutput += " - "

    pluginoutput += name + ': ' + str(label)

    if len(lines):
        pluginoutput += ' - '
        pluginoutput += ' '.join(lines)

    if perfdata:
        pluginoutput += '|'
        pluginoutput += ' '.join(["'" + key + "'" + '=' + str(value) for key, value in perfdata.items()])

    print(pluginoutput)
    sys.exit(state)


def handle_sigalrm(signum, frame, timeout=None):
    output('Plugin timed out after %d seconds' % timeout, 3)

class Checker(object):
    def __init__(self, host, port, ifid, user, secret, use_ssl, unsecure, timeout, verbose):
        self.host = host
        self.port = port
        self.ifid = ifid
        self.user = user
        self.secret = secret
        self.use_ssl = use_ssl
        self.unsecure = unsecure
        self.timeout = timeout
        self.verbose = verbose

        if self.verbose:
            print('[%s:%u][ifid: %u][ntopng auth: %s/%s][ssl: %u][unsecure: %u][timeout: %u]' % (self.host, self.port, self.ifid, self.user, self.secret, self.use_ssl, self.unsecure, self.timeout))

    def check_url(self, ifid, checked_host):
        """
        Requests
        entity = 1 means "Host" and this must be kept in sync with ntopng sources
        """

        return 'http%s://%s:%u/lua/get_alerts_table_data.lua?status=engaged&ifid=%u&entity=1&entity_val=%s&currentPage=1&perPage=1&sortColumn=column_date&sortOrder=desc' % ('s' if self.use_ssl else '', self.host, self.port, ifid, checked_host)

    def fetch(self, ifid, checked_host):
        req = urllib.request.Request(self.check_url(ifid, checked_host))

        if self.user is not None or self.secret is not None:
            credentials = ('%s:%s' % (self.user, self.secret))
            encoded_credentials = base64.b64encode(credentials.encode('ascii'))
            req.add_header('Authorization', 'Basic %s' % encoded_credentials.decode("ascii"))

        if self.unsecure:
            ssl._create_default_https_context = ssl._create_unverified_context

        try:
            with urllib.request.urlopen(req) as response:
                data = response.read().decode('utf-8')
        except Exception as e:
            output('Failed to fetch data from ntopng [%s: %s]' % (type(e).__name__, str(e)), 3)

        try:
            data = json.loads(data)
        except Exception as e:
            if self.verbose:
                print(data)
            output('Failed to parse fetched data as JSON [%s: %s]' % (type(e).__name__, str(e)), 3)

        return data

    def check(self, ifid, checked_host):
        res = self.fetch(ifid, checked_host)
        if res['totalRows'] > 0:
            output("There are %u engaged alerts" % res['totalRows'], 2)
        else:
            output("There are no engaged alerts", 0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--version', action = 'version', version = '%(prog)s v' + sys.modules[__name__].__version__)
    parser.add_argument('-V', '--verbose', action = 'store_true')
    parser.add_argument('-H', '--host', help = 'The IP address of the host running ntopng', required = True)
    parser.add_argument("-P", "--port", help = "The port on which ntopng is listening for connections (default = 3000)", type = int, default = 3000)
    parser.add_argument("-I", "--ifid", help = "The id of the ntopng monitored interface", type = int, choices = range(0, 256), required = True)
    parser.add_argument("-U", "--user", help = "The name of an ntopng user")
    parser.add_argument("-S", "--secret", help = "The password to authenticate the ntopng user")
    parser.add_argument('-c', '--checked-host', help = 'The IP address of the host which should be checked', required = True)
    # parser.add_argument("-T", "--type", required = True, help = "Alert type. Supported: 'host-alerts', 'flow-alerts'", choices = ['host-alerts', 'flow-alerts'])
    parser.add_argument("-s", "--use-ssl", help="Use SSL to connect to ntopng", action = 'store_true')
    parser.add_argument("-u", "--unsecure", help="When SSL is used, ignore SSL certificate verification", action = 'store_true')
    parser.add_argument("-t", "--timeout", help="Timeout in seconds (default 10s)", type = int, default = 10)
    args = parser.parse_args()

    signal.signal(signal.SIGALRM, partial(handle_sigalrm, timeout=args.timeout))
    signal.alarm(args.timeout)

    checker = Checker(args.host, args.port, args.ifid, args.user, args.secret, args.use_ssl, args.unsecure, args.timeout, args.verbose)

    checker.check(args.ifid, args.checked_host)
