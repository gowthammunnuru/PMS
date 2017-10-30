# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2008-2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
"""
Provides convenient ways to get studio data from the LDAP server.

"""
import ldap
import socket
import logging
import datetime

DOMAINS = ['dreamworks.com', 'ddu-india.com', 'odw.com', 'odw.com.cn']


class Connection(object):
    """
    An LDAP server connection.
    """
    def __init__(self, server='ldap://ldaprr.anim.dreamworks.com', dn=None):
        """
        Initializes the Connection object.

        :Parameters:
            server : `str`
                The LDAP server.  Defaults to "ldap://ldaprr" (the LDAP round-robin)
            dn : `str`
                The LDAP domain name.  Default to None

        :Returns:
            A Connection instance

        :Rtype:
            `Connection`
        """
        logging.info("Initializing LDAP connection")
        self.server = server
        if dn:
            self.dn = dn
        else:
            self.dn = 'ou=People,dc=anim,dc=dreamworks,dc=com'

        self.connection = ldap.initialize(self.server)

    def query(self, search_filter, attributes=None):
        """
        Queries the LDAP server for specified attributes
        based on the given search filter.

        :Parameter:
            searchFilter : `str`
                The function-style, key/value logical filter
            attributes : `list`
                LDAP record attributes to return

        :Returns:
            A Result instance

        :Rtype:
            `Result`
        """
        logging.debug('Searching LDAP using filter: %s', search_filter)
        try:
            result_id = self.connection.search(self.dn,
                                               ldap.SCOPE_SUBTREE,
                                               search_filter,
                                               attributes)
            logging.debug("resultId: %s", result_id)
            result_type, result_data = self.connection.result(result_id, timeout=45)
        except ldap.LDAPError:
            logging.debug("Could not get LDAP data for query: %s", search_filter)
            raise
        except ldap.SERVER_DOWN:
            logging.debug("Could not contact %s", self.server)
            raise

        if not result_data:
            raise ValueError("LDAP returned no data for query: %s" % search_filter)
        records = []

        for dn, attributes in result_data:
            records.append(Record(dn, attributes))

        return Result(records)


class Result(list):
    """
    An LDAP Result.

    A subclass of list containing Record objects.
    """
    def get_records_with(self, search_filter):
        """
        Gets a subset of the internal Record objects which match the
        filter criteria.

        :Parameter:
            searchFilter : `str`
                A filter of the form "key=value" against which to filter
                records

        :Returns:
            A list of `Record` objects which match the filter criteria

        :Rtype:
            `list`
        """
        filtered_records = []
        for record in self:
            key, value = search_filter.split('=')
            logging.debug("Checking %s for %s of %s", record, key, value)
            if record.get(key) == value:
                filtered_records.append(record)
        return filtered_records


class Record(dict):
    """
    An LDAP record.

    A subclass of dict containing key/value pairs of LDAP attributes and their
    values.
    """
    def __init__(self, dn, attributes):
        """
        Initializes the Record object.

        Records the time of instanciation, the domain name from whence the
        LDAP data came, and the key/value pairs of the LDAP query.

        :Parameters:
            dn : `str`
                The LDAP's domain name
            attributes : `dict`
                The key/value pairs of the query's attributes

        :Returns:
            A Record instance.

        :Rtype:
            `Record`
        """
        self.asOf = datetime.datetime.now()
        self.dn = dn
        for key, value in attributes.items():
            if len(value) == 1:
                self[key] = value[0]
            else:
                self[key] = value

    def __repr__(self):
        """
        Print out the object's representation
        noting the LDAP domain name from
        whence the data came.
        """
        return '<Record of "%s">' % self.dn


def get_phone_by_user(uid):
    """
    A convenience function for getting a user's
    telephone number by their username.

    :Parameters:
        uid : `str`
            An LDAP username

    :Returns:
        A DreamWorks telephone extension

    :Rtype:
        `str` or `None`
    """
    try:
        return Connection().query('uid=%s' % uid)[0].get('telephoneNumber')
    except:
        logging.warn("Couldn't get phone number for %s", uid)


def get_office_by_user(uid):
    """
    A convenience function for getting a user's
    building and office number by their username.

    :Parameters:
        uid : `str`
            An LDAP username

    :Returns:
        The name of a DreamWorks office location

    :Rtype:
        `str` or `None`
    """
    try:
        return Connection().query('uid=%s' % uid)[0].get('physicalDeliveryOfficeName')
    except:
        logging.warn("Couldn't get office number for %s", uid)


def _get_uid_sloppy(name):
    """ This method is to help maintain the loose matching
        behavior of dwapy.directory prior to the GMail migration.
        Ideally this behavior should not have been available to begin
        with and should not be relied upon.
    """
    ds = Connection()
    uid = None
    # Try the same recipient name with all possible domains
    for domain in DOMAINS:
        address = name + '@' + domain
        try:
            uid = ds.query('(mail=%s)' % address)[0].get('uid')
            return uid
        except:
            pass
    if not uid:
        raise ValueError("Recipient name not found in any domain.")


def get_mail_by_user(uid, warn_on_error=True):
    """
    A convenience function for getting a user's
    fully-qualified email address by their username.

    :Parameters:
        uid : `str`
            An LDAP username

    :Returns:
        A fully-qualified email address

    :Rtype:
        `str` or `None`
    """
    try:
        ds = Connection()
        try:
            logging.debug("Querying LDAP for uid=%s", uid)
            mail = ds.query('uid=%s' % uid)[0].get('mail')
        except (ValueError, KeyError), e:
            new_uid = _get_uid_sloppy(uid)
            logging.debug("Remapped UID %s to %s", uid, new_uid)
            mail = ds.query('uid=%s' % new_uid)[0].get('mail')
        return mail
    except:
        if warn_on_error:
            logging.warn("Couldn't get mail address for %s", uid)
        else:
            raise


def get_user_by_mail(address):
    """
    A convenience function for getting a username by
    a fully-qualified canonical email address.

    :Parameters:
        address : `str`
            A full-qualified canonical email address

    :Returns:
        A uid.

    :Rtype:
        `str` or `None`
    """
    ds = Connection()
    try:
        try:
            user = ds.query('mail=%s' % address)[0].get('uid')
        except ValueError, e:
            user = _get_uid_sloppy(address.split('@')[0])
        return user
    except:
        logging.warn("Couldn't get uid for %s", address)


def get_name_by_user(uid):
    """
    A convenience function for getting the full
    name of a user by their username.

    :Parameters:
        uid : `str`
            An LDAP username

    :Returns:
        An LDAP user's full name

    :Rtype:
        `str` or `None`
    """
    try:
        return Connection().query('uid=%s' % uid)[0].get('cn')
    except:
        logging.warn("Couldn't get user name for %s", uid)


def get_members_by_group(group):
    """
    A convenience function for getting a list of members
    of an LDAP group by the group name.

    :Parameters:
        group : `str`
            An LDAP group name

    :Returns:
        A list of LDAP users

    :Rtype:
        `list`
    """
    try:
        return Connection().query('(&(cn=%s)(objectClass=posixGroup))' % group)[0].get('memberUid')
    except:
        logging.warn("Couldn't get group members for %s", group)


def sort_mail_by_last_name(mail_address):
    """
    A convenience function to be passed into .sort() or sorted() as the "key"
    argument which isolates the last names in email addresses of the form
    First.Whatever.Last@domain.com.

    :Parameter:
        mailAddress : `str`
            An email address

    :Returns:
        The last name of the email user

    :Rtype:
        `list`
    """
    return str(mail_address).split('@')[0].split('.')[-1].lower()


def get_user_from_mail_address(ds, address):
    """
    Given a directory service connection (dwapy.directory.Connection)
    and an email address, this function will return the username that
    corresponds to that address.
    """
    search_filter = "(&(objectClass=person)(mail=%s))" % address
    records = ds.query(search_filter)
    user = None
    for record in records:
        if 'uid' in record.keys():
            user = record['uid']
            break
    return user, records


def get_home_dir_by_user(uid):
    """
    A convenience function for getting a user's
    home directory by their username.

    :Parameters:
        uid : `str`
            An LDAP username

    :Returns:
        A fully-expanded directory, or None if user
        doesn't exist or other catastrophic failure

    :Rtype:
        `str` or `None`
    """
    ldap_results = [r['homeDirectory'] for r in
                    Connection().query('uid={0}'.format(uid))]

    if ldap_results:
        home = ldap_results.pop()
    else:
        home = None

    return home


# TM and (c) 2008-2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
