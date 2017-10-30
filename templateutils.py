from __future__ import absolute_import

import re
import path
from BeautifulSoup import BeautifulSoup

import memoize


TEMPLATE_DIR = path.path('static/review_templates/')


@memoize.memoize
def getTemplate(key):
    template = {
        'template_id': key,
        'section': {},
        'modelkeys': [],  # Holds the full list of `modelkeys`
        'is_lead': False,
        'weights-performance': {},
        'weights-potential': {},
    }

    if not key:
        return template

    if any(keyword in key for keyword in ['-lead', '-head', '-supe', '-manager']):
        isLead = True
    else:
        isLead = False

    template['is_lead'] = isLead

    templateCommonDir = TEMPLATE_DIR / key.split('/')[0]
    templateDir = TEMPLATE_DIR / key

    for templateFile in templateDir.files(pattern='*.html'):

        namebase = templateFile.namebase

        templateString = templateFile.open('r').read()

        # Attach Common here
        commonTemplate = path.path(templateCommonDir / "common.%s.html" % namebase)
        if commonTemplate.exists():
            commonTemplateString = commonTemplate.open('r').read()

            templateString = templateString + commonTemplateString

        # Attach Lead here
        if isLead:
            leadTemplate = path.path(templateCommonDir / "common.%s.lead.html" % namebase)

            if leadTemplate.exists():
                leadTemplateString = leadTemplate.open('r').read()

                templateString = templateString + leadTemplateString

        templateObj = BeautifulSoup(templateString)

        section = template['section'].setdefault(namebase, {})

        section['html'] = templateString

        section['blocktitle'] = templateObj.find('review').string
        section['name'] = namebase

        for tag in templateObj.findAll():

            if tag.name not in ['prompt', 'review']:  # These are organizational tags, and wont have any modelkeys
                modelkey = createModelkey(section['blocktitle'], tag.parent.get('blocktitle', ''), tag)
                template['modelkeys'].append(modelkey)

            tag['mode'] = 'multi'

        section['html_mode_multi'] = str(templateObj)

        for tag in templateObj.findAll():
            tag['mode'] = 'preview'

        section['html_mode_preview'] = str(templateObj)

    return template


def sanitize(string):
    return re.sub('\W+', '-', str(string)).lower()


def createModelkey(sectionTitle, blocktitle, tag):
    if blocktitle:
        modelkey = "%s-%s::%s" % (sanitize(sectionTitle), sanitize(blocktitle), sanitize(tag.string))
    else:
        # We reach here for template.html files without any blocks, which there's just 1 block.
        # (comments/notes are an example)
        modelkey = "%s::%s" % (sanitize(sectionTitle), sanitize(tag.string))

    return modelkey


def parseRatings(html):
    """
    This is used by emailutils to get a python friendly datastructure of the template
    """
    ratings = []

    for prompt in BeautifulSoup(html).findAll('prompt'):
        p = {
            'blocktitle': prompt['blocktitle'],
            'criteria': [x.string for x in prompt.findAll('criteria')],
            'modelkeys': [createModelkey('ratings', prompt['blocktitle'], x) for x in prompt.findAll('criteria')]
        }

        ratings.append(p)

    return ratings


def parseNotes(html):
    """
    This is used by emailutils to get a python friendly datastructure of the template
    """

    notes = []

    for comment in BeautifulSoup(html).findAll('comment'):
        c = {
            'notetitle': comment.string,
            'modelkey': createModelkey('notes', None, comment.string)
        }

        notes.append(c)

    return notes


def getAllTemplateTypes():
    """
    Return all available template types

    TODO: Add support for multiple versions.
    """
    templates = []

    for template in TEMPLATE_DIR.walkfiles('ratings.html'):
        templateYear = template.parent.parent.namebase
        templateName = template.parent.namebase

        templates.append('%s/%s' % (templateYear, templateName))

    return templates
