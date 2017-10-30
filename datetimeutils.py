import os

import pytz
import datetime

STUDIO = os.getenv('STUDIO')

if STUDIO in ['TTP', 'DDU']:
    tz = pytz.timezone('Asia/Calcutta')
elif STUDIO in ['GLD', 'RWC', 'DWA', 'GDI', 'RCI']:
    tz = pytz.timezone('US/Pacific')
else:
    tz = pytz.utc


def timenow():
    """
    Create a timezone aware datetime object
    """
    return datetime.datetime.now(tz)


def timeInAnotherTZ(dt, otherTZ):
    """
    Convert the timezone aware datetime to another timezone
    """

    return dt.astimezone(otherTZ)

