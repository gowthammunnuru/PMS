# DreamWorks Animation LLC Confidential Information.
# TM and (c) 2006-2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
"""
Simple interface to create and send email messages.
"""

from __future__ import absolute_import


import os
import pwd
import re
import socket
import logging
import smtplib
from path import path
from email import Encoders
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from directory import Connection


_COMMASPACE = ', '

global SMTP_SERVER
SMTP_SERVER = None


def mail(sender, to, body, cc=None, bcc=None, reply="", subject="", headers=None,
         sender_name=None, attachments=None, server=None, format_html=False):
    """
    Create and mail a text message. The sender, to, and body are mandatory.
    May raise SMTP exceptions.

    :Parameters:
        sender : `str`
            From address, as a string.  Supports multiple formats such as:
            "loginName", "loginName@domain.name", "<loginName@domain.name>",
            "Sender's Name <loginName@domain.name>".
        to : `list`
            "To" addresses, as a list of strings.
        body : `str`
            String of text to send.
        cc : `list`
            Carbon copy addresses, as a list of strings.
        bcc : `list`
            Blank carbon copy addresses, as a list of strings.
        reply : `str`
            "Reply-To" address, as a string.
        subject : `str`
            Subject of the message, as a string.
        headers : `dict`
            Dictionary of {"header":"value"} for other mail headers.
        sender_name : `str`
            The sender parameter tries to figure out the user's name and
            email address from the string provided.  Use this parameter to
            specify a specific sender name.  The "From" field of the email
            will be of the form "senderName <sender>" without any validation.
            The "sender" value must be an email address in the form of
            "loginName@domain.name" when using this variable.
        attachments : `list`
            A list of files to attach to the email.  Files that do not exist
            will be skipped.
        server : `smtplib.SMTP`
            An SMTP server object.  This is an optional argument that can be
            replaced with a mock class for unit testing.

    :Rtype:
        None

    :Raises `smtplib.SMTPException`:
        See http://www.python.org/doc/lib/module-smtplib.html for a description
        of exceptions raised when sending email.
    """
    if attachments is None:
        attachments = []
    if headers is None:
        headers = {}
    if bcc is None:
        bcc = []
    if cc is None:
        cc = []
    msg = create(sender, to, body, cc=cc, bcc=bcc, reply=reply, subject=subject,
                 headers=headers, sender_name=sender_name, attachments=attachments,
                 format_html=format_html)
    send(msg, server=server)


def create(sender, to, body, cc=None, bcc=None, reply="", subject="",
           headers=None, sender_name=None, attachments=None, format_html=False):
    """
    Creates a text email object, but does not send it.

    :Parameters:
        sender : `str`
            From address, as a string.  Supports multiple formats such as:
            "loginName", "loginName@domain.name", "<loginName@domain.name>",
            "Sender's Name <loginName@domain.name>".
        to : `list`
            "To" addresses, as a list of strings.
        body : `str`
            String of text to send.
        cc : `list`
            Carbon copy addresses, as a list of strings.
        bcc : `list`
            Blank carbon copy addresses, as a list of strings.
        reply : `str`
            "Reply-To" address, as a string.
        subject : `str`
            Subject of the message, as a string.
        headers : `dict`
            Dictionary of {"header":"value"} for other mail headers.
        sender_name : `str`
            The sender parameter tries to figure out the user's name and
            email address from the string provided.  Use this parameter to
            specify a specific sender name.  The "From" field of the email
            will be of the form "senderName <sender>" without any validation.
            The "sender" value must be an email address in the form of
            "loginName@domain.name" when using this variable.
        attachments : `list`
            A list of files to attach to the email.  Files that do not exist
            will be skipped.

    :Returns:
        An object formatted for email delivery.

    :Rtype:
        `email.MIMEText.MIMEText`
    """
    if headers is None:
        headers = {}
    if attachments is None:
        attachments = []
    if bcc is None:
        bcc = []
    if cc is None:
        cc = []
    sender_proper = _create_sender(sender, sender_name)

    if type(to) != list:
        to = [to]
    to = map(_attach_domain, to)
    to = _COMMASPACE.join(to)

    if type(cc) != list:
        cc = [cc]
    cc = map(_attach_domain, cc)
    cc = _COMMASPACE.join(cc)

    if type(bcc) != list:
        bcc = [bcc]
    bcc = map(_attach_domain, bcc)
    bcc = _COMMASPACE.join(bcc)

    msg = MIMEMultipart()
    msg['To'] = to
    msg['Cc'] = cc
    msg['Bcc'] = bcc
    msg['From'] = sender_proper
    msg['Sender'] = sender_proper
    msg['Reply-To'] = reply
    msg['Subject'] = subject.replace("\n", " ")

    if headers != {}:
        for keys, values in headers.items():
            msg[keys] = values.replace("\n", " ")

    body_msg = MIMEText(body)
    if format_html:
        body_msg.set_type("text/html")
    msg.attach(body_msg)

    for attachment in attachments:
        attachment = path(attachment)
        if not attachment.isfile():
            logging.warn("File '%s' does not exist or is not a file. Cannot attach "
                         "to the email.", attachment)
            continue

        content_type = _get_content_type(attachment)
        part = MIMEBase(content_type[0], content_type[1])
        part.set_payload(attachment.open('rb').read())
        Encoders.encode_base64(part)
        part.add_header('Content-Disposition', u'attachment; filename="{0:s}"'.format(attachment.basename()))
        msg.attach(part)

    return msg


def _get_content_type(attachment):
    extension = attachment.ext

    jpeg_extensions = ['.jpg', '.jpeg', '.jpe']

    if extension in jpeg_extensions:
        return 'image', 'jpeg'
    elif extension == '.png':
        return 'image', 'png'
    elif extension == '.gif':
        return 'image', 'gif'
    else:
        return 'application', 'octet-stream'

def is_connected(conn):
    try:
        status = conn.noop()[0]
    except:  # smtplib.SMTPServerDisconnected
        status = -1
    return True if status == 250 else False


def send(msg, server=None):
    """
    Send an email message object using the smtp server.

    :Parameters:
        msg : `email.MIMEText.MIMEText`
            The email message formatted for delivery.
        server : `smtplib.SMTP`
            An SMTP server object.  This is an optional argument that can be
            replaced with a mock class for unit testing.

    :Rtype:
        None

    :Raises `smtplib.SMTPException`:
        See http://www.python.org/doc/lib/module-smtplib.html for a description
        of exceptions raised when sending email.
    """
    sender = msg['From']
    recipients = _make_recipient_list_from_message_header(msg)


    global SMTP_SERVER
    if not SMTP_SERVER:
        server = smtplib.SMTP()
        server.connect()
        SMTP_SERVER = server
    else:
        server = SMTP_SERVER
        if not is_connected(server):
            server.connect()


    # Workaround for subject bug reported in SQ#105447 until it is fixed
    # in the python module (http://bugs.python.org/issue1974).
    msg_str = _format_message_text(msg.as_string())

    
    try:
        server.sendmail(sender, recipients, msg_str)
    finally:
        pass
        #server.close()


def _make_recipient_list_from_message_header(msg):
    """
    Looks at the 'To', "Cc', and 'Bcc' headers and constructs a list
    of recipients.  It assumes that each one of those headers is a
    comma-separated string of addresses.
    """
    recipients = msg['To'].split(_COMMASPACE)

    if msg['Cc']:
        recipients += msg['Cc'].split(_COMMASPACE)

    if msg['Bcc']:
        recipients += msg['Bcc'].split(_COMMASPACE)

    return recipients


def _format_message_text(message_text):
    """
    Reformats the message text by replacing characters that would create
    unrecognized characters when read in Thunderbird.  It replaces ``\\n\\t``
    strings in the header with ``\\n[space]`` since tabs in the header for
    'Subject' cause the messages to display oddly in Thunderbird.

    :Parameters:
        messageText : `str`
            A string of a properly-formated email message including headers.

    :Returns:
        A copy of the message with invalid characters replaced with valid ones.

    :RType:
        `str`
    """
    (header_text, email_body) = message_text.split("\n\n", 1)
    header_text = header_text.replace("\n\t", "\n ")
    return header_text + "\n\n" + email_body


def _create_sender(sender, sender_name=None):
    """
    Creates a sender string in the form of "Sender's Name <sender@domain.name>".

    In order for email to be sent, the sender needs to be properly formatted.
    This function will either build the sender directly from the arguments
    provided, or try to construct it based on the sender argument.

    :Parameters:
        sender : `str`
            The name of the sender.  It will be parsed in order to find the
            sender's name and address so that it can be put into the proper
            format.
        sender_name : `str`
            If provided, this function will not parse the sender argument and
            construct the proper sender string.  Instead it will assume that
            the sender argument is an email address and senderName is a string
            and will return the properly-formatted string as
            "[senderName] <[sender]>".  The "sender" value should be
            an email address in the form of "loginName@domain.name" when
            using this variable.


    :Returns:
        A string of a sender in the format of "[senderName] <[sender]>"

    :Rtype:
        `str`
    """
    if sender_name:
        return '"%s" <%s>' % (sender_name, sender)

    # Pattern is from dyoung
    pattern = re.compile('([^<@]+\s[^<@\s]+)*(\s)*(<)*([\w\.]+)*(@.*\.\w+)*(>)*')
    result = re.match(pattern, sender)

    if result.groups() is None:
        raise ValueError("Sender provided cannot be parsed as sender's address.")
    else:
        if result.groups()[0] is not None:
            fullname = result.groups()[0]
        else:
            fullname = pwd.getpwuid(os.geteuid())[4]

        if result.groups()[4] is not None:
            domain = result.groups()[4]
        else:
            # ESA-3818: Taken from io.notify as a workaround -agaige
            # Determine the domain name based on the fully qualified hostname.
            hostname = socket.getfqdn()
            domain_name_split = hostname.split('.')[1:]
            domain = '@' + '.'.join(domain_name_split)

        if result.groups()[3] is not None:
            address = result.groups()[3]
        else:
            address = pwd.getpwuid(os.geteuid())[0]

    sender_proper = '"%s" <%s%s>' % (fullname, address, domain)
    return sender_proper


def _attach_domain(recipient):
    """
    If not present, attaches a domain name if the recipient matches a
    corresponding username.

    :Parameters:
        sender : `str`
            The name of the recipient.

    :Returns:
        A string of the recipient possibly with a domain attached

    :Rtype:
        `str`
    """
    if '@' not in recipient:
        con = Connection()
        try:
            results = con.query(u"uid={0:s}".format(recipient), ['mail'])
            for record in results:
                for key, value in record.items():
                    if key == 'mail':
                        return value
        except ValueError:  # ignore errors if recipient not in LDAP
            pass

    return recipient

# TM and (c) 2006-2013 DreamWorks Animation LLC.  All Rights Reserved.
# Reproduction in whole or in part without prior written permission of a
# duly authorized representative is prohibited.
