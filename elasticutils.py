    #!/bin/env python
# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.

import os, sys, json, requests
from operator import attrgetter, methodcaller
import urllib
from elasticsearch import Elasticsearch
import logging

es = Elasticsearch(hosts=["localhost:9200"])


def searchAll(uri="http://localhost:9200/perform/_search?pretty=true") :
    query = json.dumps({
                "from": 0, "size": 15000,
                "query" : { 
                    "match_all" : {} 
                }
            })

    response = requests.get(uri, data=query)
    results = json.loads(response.text)
    return results

    #sorted(results['hits']['hits'], key= lambda k : k['_type'])    

def getUsersByDepartment(department, uri="http://localhost:9200/perform/users/_search") :
    query = json.dumps({"from":0, "size":15000,
    "query" : {
        "constant_score" : {
            "filter" : {
                "term" : {
                    "department" : department
                }
            }
        }
    }
    })
    response = requests.get(uri, data=query)
    results = json.loads(response.text)
    return results

def getUserByName(uid, uri="http://localhost:9200/perform/users/_search"):
    query = json.dumps({"from":0, "size":15000,
    "query" : {
        "term" : {"uid" : uid} 
    }
    })
    response = requests.get(uri, data=query)
    results = json.loads(response.text)
    if results['hits']['hits']:
        return results['hits']['hits'][0]['_source']
    else:
        return {}
 

 # Use location="DreamWorks Animation L.L.C." for Glendale
def getActiveUsersInLocation(location="DreamWorks Animation International Services, LLC"):
    results = es.search(index="perform",
                        doc_type="users", body={"from":0, "size":15000, "query": { 
    "bool": { 
      "must": [
                  {"match_phrase": {
                     "organization": location }}
                     ],
      "filter": [ 
        { "term":  { "active": True }}
        
      ]
    }
  }})

    location_users = []
    for i in results['hits']['hits']:
        if i["_source"]["location"]["id"] != "china-offsite":
            location_users.append(i["_source"])
    json_list = json.dumps(location_users)
    return json_list


def getAllActiveUsers():
    results = es.search(index="perform",
                        doc_type="users", body={"from":0, "size":15000, "fields":["_id"], "query": {"term":{"active": True}}})
    for i in results['hits']['hits']:
        print i['_id']

def getManyUserEmailData(uidList, uri="http://localhost:9200/perform/users/_search"):
    query = json.dumps(
        { "from":0, "size":15000,
            "fields": [
               "uid", "email", "cn"
            ],
            "query" : {
                "terms" : {
                    "uid" : uidList
                }
            }
        }
    )
    response = requests.get(uri, data=query)
    results = json.loads(response.text)
    if results['hits']['hits']:
        result_dict = {}
        for i in results['hits']['hits']:
            field_tmp = []
            field_tmp.append(i["fields"]["cn"][0])
            field_tmp.append(i["fields"]["email"][0])
            result_dict[i['_id']] = field_tmp
        return result_dict
    else:
        return {}

def get_employee_number(uid):
    try:
        data = getUserByName(uid)
        print data
        return data.get('employeeNumber')
    except:
        logging.warn("Couldn't get Employee Number for %s", uid)
        return ''


def get_mail_by_user(uid):
    try:
        data = getUserByName(uid)
        return data.get("email")
    except:
        logging.warn("Couldn't get mail address for %s", uid)

def get_name_by_user(uid):
    try:
        data = getUserByName(uid)
        return data.get("cn")
    except:
        logging.warn("Couldn't get user name for %s", uid)


if __name__ == "__main__":
    #getAllActiveUsers()
    #results = getActiveUsersInLocation()
    #print getManyUserEmailData(["ktoth", "mmanthram", "arajkumar", "yoyo"])
    print getManyUserEmailData(["gmunnuru","rpokala"])

    
# TM and (c) 2016 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
