import os
import re
import time
from datetime import datetime, timedelta


ISO_8601_DATETIME = '%Y-%m-%dT%H:%M:%SZ'


def iso8601_datetime_format(time_tuple):
    """
    Format datetime tuple to ISO 8601 format suitable for MIME messages.

    NOTE: can use use datetime().isoformat() on instances too.
    """
    return time.strftime(ISO_8601_DATETIME, time_tuple)

def iso8601_from_stamp(ts):
    """
    Go from (UTC) timestamp to formatted date time.
    """
    if isinstance(ts, basestring):
        assert ts.isdigit()
        ts = int(ts)
    dt = datetime.fromtimestamp(ts)
    return dt.isoformat()

def parse_isodatetime(s):
    """
    Opposite of datetime().isoformat()
    """
    if s[0] == '-':
        s = str(datetime.now().year)+s[1:]
    if 'T' in s or ':' in s and '-' in s:
        fmt = ISO_8601_DATETIME
    elif '-' in s:
        l, f = len(s), []
        if l >= 4: f.append('%Y')
        if l >= 8: f.append('%m')
        if l == 10: f.append('%d')
        fmt = "-".join(f)
    elif ':' in s:
        l, f = len(s), []
        if l >= 2: f.append('%H')
        if l >= 4: f.append('%S')
        if l == 6: f.append('%s')
        fmt = ":".join(f)
    assert fmt, repr(s)
    return datetime.strptime(s, fmt)

def obj_serialize_datetime_list(l, ctx):
    r = []
    for n, i in enumerate(l):
      r.append(obj_serialize_datetime(i, ctx))
    return r

def obj_serialize_datetime_dict(o, ctx):
    r = {}
    for k, v in o.items():
      r[k] = obj_serialize_datetime(v, ctx)
    return r

def obj_serialize_datetime(o, ctx):
    if hasattr(o, 'items'):
      return obj_serialize_datetime_dict(o, ctx)
    elif hasattr(o, 'iter') or hasattr(o, '__iter__'):
      return obj_serialize_datetime_list(o, ctx)
    else:
      if isinstance(o, datetime):
        o = o.strftime(ctx.opts.flags.serialize_datetime)
      return o

human_time_period_specs = dict(
   s='sec',
   second='sec',
   M='min',
   minute='min',
   H='hour',
   d='day',
   w='week',
   Y='year',
   y='year',
   sec=1,
   min=60,
   hour=60 * 60,
   day=24 * 60 * 60,
   week=7 * 24 * 60 * 60,
   year=365 * 24 * 60 * 60
)
def human_time_period(spec, specs=human_time_period_specs):
    M = r'^([0-9\.]+)([A-Za-z]+)$'
    sign = spec.startswith('-')
    if sign:
        spec = spec[1:]
    num = re.match(M, spec).group(1)
    if '.' in num:
        num = float(num)
    else:
        num = int(num)
    unit = re.match(M, spec).group(2)

    while unit in specs:
        if isinstance(specs[unit], basestring):
            unit = specs[unit]
            continue

        else:
            num *= specs[unit]
            break

    if sign:
        return 0-num
    return num

def shift(pspec, dt_ref=None):
    if not dt_ref:
        dt_ref = datetime.now()
    return dt_ref + timedelta(0, human_time_period(pspec))

def older_than(dt, pspec):
    return dt < shift('-'+pspec)

def modified_before(p, pspec):
    if isinstance(pspec, basestring):
        dt_m = datetime.fromtimestamp(os.path.getmtime(p))
        return older_than( dt_m, pspec )
    else:
        return os.path.getmtime(p) < pspec


if __name__ == '__main__':
    print(human_time_period('5min'))
    print(human_time_period('60min'))
    print(human_time_period('2week'))
    print(human_time_period('4.5week'))
    print(modified_before('.lvimrc', '1week'))
    print(datetime.now())
    print(shift('-10s'))
    print(shift('-12.44y'))
