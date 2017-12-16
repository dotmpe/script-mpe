import os
import re
from datetime import datetime, timedelta


human_time_period_order = [
  ]
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
