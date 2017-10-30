#!/bin/env python
# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.

from __future__ import absolute_import

import json
import ldap
import elasticsearch
import elasticsearch.helpers
import os


def populate():
    dn = 'ou=People,dc=anim,dc=dreamworks,dc=com'
    attrlist = {'uid': 'uid',
                'employmentStatus': 'active',
                'employeeNumber': 'employeeNumber',
                'givenName': 'givenName',
                'sn': 'surname',
                'telephoneNumber': 'phone',
                'physicalDeliveryOfficeName': 'location',
                'o': 'organization',
                'ou': 'ou',
                'mail': 'email',
                'employeeType':'employeeType'
                }

    conn = ldap.open('ldap.anim.dreamworks.com')
    results = conn.search_s(dn, ldap.SCOPE_SUBTREE, attrlist=attrlist.keys())
    records = []
    for _, info in results:
        if "uid" not in info:
            continue
        uid = info['uid'][-1]
        record = {attrlist[k]: info.get(k, [''])[-1] for k in attrlist}

        office = info.get('physicalDeliveryOfficeName', ['---'])[-1]
        record['location'] = dict(zip(('site', 'building', 'floor', 'seat'), office.split('-')))
        record['location']['id'] = '-'.join(office.lower().split())
        if 'Bldg:' in office  or 'Fl:' in office or 'Office:' in office:
            if 'Bldg:' in office:
                 record['location']['building'] = office.split('Bldg:')[-1].split(',')[0].lstrip()
            if 'Fl:' in office:
                 record['location']['floor'] = office.split('Fl:')[-1].split(',')[0].lstrip()
            if 'Office:' in office:
                 record['location']['seat'] = office.split('Office:')[-1].split(',')[0].lstrip()
            record['location']['site'] = 'GLD'
            record['location']['id'] = office
        record['site_key'] = record['location']['site']
        site = {'blr': "", 'gld': "", 'other': "", 'rwc': "", 'central': ""}
        if not record['location']['site']:
            site["other"] = "1"
        else:
            site[record['location']['site'].lower()] = "1"

        record['site'] = site

        if record['location']['site'] == 'BLR':
            record['location']['site'] = 'BANGALORE'
        if 'building' in record['location'].keys():
            record['location']['building'] = record['location']['building'].title()
        record['location']['site'] = record['location']['site'].title()

        record['active'] = True if 'Active' in record['active'] else False
        record['cn'] = record['givenName'] + " " + record['surname']

        records.append({
            '_op_type': 'index',
            '_index': 'perform',
            '_type': 'users',
            '_id': uid,
            '_source': record
        })

    es = elasticsearch.Elasticsearch(hosts=["localhost:9200"])
    if es.indices.exists('perform'):
        es.indices.delete('perform')

    parent_dir = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(parent_dir, 'mapping.json')) as fd:
        es_mappings = json.load(fd)
        es.indices.create('perform', body=es_mappings)
    elasticsearch.helpers.bulk(es, records, stats_only=True)

if __name__ == '__main__':
    populate()

# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
