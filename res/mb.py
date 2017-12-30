"""
res.mb - a bunch of uncompiled regex parts and patterns
"""


## Partial char sequences

# Cover variable names
var_c = 'A-Za-z0-9_'

# All-capital letter varnames
capref_c = 'A-Z_'
capnumref_c = 'A-Z0-9_'

# Case-insensitive, generic computer generated string ID's
sref_c = '0-9a-z\-'

# NOTE: tag-c is combined with included-sep-c and stripped from excluded-c
tag_c = 'A-Za-z0-9_'
tag_seps = '/:._\-'
included_sep_c = '\/:;\.\-\+\(\)\[\]_'
excluded_c = ',;\-'

value_c = r'A-Za-z0-9%s' % included_sep_c

re_meta_c = r'\\A-Za-z0-9{}(),!@+_'

# Simple number types, without and with optional sign
bin_r =     r'0b[0-1]+'
oct_r =     r'0(?:o)?[0-8]+'
int_r =     r'[0-9]+'
dec_r =     r'[0-9\.]+'
hex_r =     r'0x[0-9a-f]+'
long_r =    r'[0-9]+L'
float_r =   r'[0-9\.]+f'

sbin_r =    r'(?:-)?0b[0-1]+'
soct_r =    r'(?:-)?0(?:o)?[0-8]+'
sint_r =    r'(?:-)?[0-9]+'
sdec_r =    r'(?:-)?[0-9\.]+'
shex_r =    r'(?:-)?0x[0-9a-f]+'
slong_r =   r'(?:-)?[0-9]+L'
sfloat_r =  r'(?:-)?\([0-9\.]+\)f'

# Complex number types based on signed decimal and integer
sci_dec_r = r'%se%s' % (sdec_r, sint_r)
complex_r = r'%s\+%sj' % (sdec_r, sdec_r)

bool_r = r'[Tt]rue|[Ff]alse'

# Match on start of line, or after non-word char
start_c = r'(^|\W)'

# Match until space, end, or excluded char
end_c = r'(?=\ |$|[%s])' % excluded_c


## Completed patterns

simple_varname_r = r'[%s][%s]+' % (capref_c, capnumref_c)


# NOTE: ISO 8601 requires padding to two-digits for all positions after year
# Full Zulu/UTC datetime, optional separators.
iso_8601_dt_z_r = r'[0-9]{4}-?[0-9]{2}-?[0-9]{2}T[0-9]{2}\:?[0-9]{2}\:?[0-9]{2}Z'
# Full datetime with zone offset
iso_8601_dt_r   = r'[0-9]{4}-?[0-9]{2}-?[0-9]{2}T[0-9]{2}:?[0-9]{2}:?[0-9]{2}[+-][0-9]{2}:?[0-9]{2}'
# Liberal parse pattern for date, time, both or none.
iso_8601_dt_l_r = \
r'''
(
  ( [0-9]{4} | - ) - [0-9]{2} - [0-9]{2}
  (?: T [0-9]{2} : [0-9]{2} (?: : [0-9]{2} )? )?
  (?: Z | ( [+-] [0-9]{2} :? [0-9]{2} ) )?
)
'''

"""
YYYY-MM-DD or YYYYMMDD
YYYY-MM (but not YYYYMM)
--MM-DD or --MMDD
"""
# Ordinal date: <year>-<day-of-year>
iso_8601_ord_r =  r'[0-9]{4}-[0-9]{1,3}'
# Week: <year>W<week>[-<day>]
iso_8601_wk_r =   r'[0-9]{4}-W[0-9]{1,2}'


uriref_simple_netpath_scan_r = r'([^\ ]+\:)?\/\/[^ ]+'


# Python re metacharacter match for escaping
escape_meta_r = r'(?!\\)([^%s])' % re_meta_c


def num_r(tp, sign=False):
    return "".join((
            start_c,
            sign and '(?:-)?' or '',
            globals()[tp.replace('-', '_')+'_r'],
            end_c
        ))


if __name__ == '__main__':
    import re
    o = (re.VERBOSE,)
    assert re.match(iso_8601_dt_z_r, '1999-12-01T12:12:12Z', *o)
    assert re.match(iso_8601_dt_r, '1999-12-01T12:12:12+01:30', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '--12-01T12:12:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12:12', *o)

    assert re.match(iso_8601_dt_l_r, '1999-12-01', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T11Z', *o)

    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-0112:12:12+01:30', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-0112:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12Z', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-0112:12+01:30', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-01T12:12+0130', *o)
    assert re.match(iso_8601_dt_l_r, '1999-12-0112:12+0130', *o)

    assert not re.match(iso_8601_dt_l_r, '12', *o)
    assert not re.match(iso_8601_dt_l_r, '123', *o)
    assert not re.match(iso_8601_dt_l_r, '12-3', *o)
    assert not re.match(iso_8601_dt_l_r, '1234', *o)
    assert not re.match(iso_8601_dt_l_r, '12-34', *o)
    assert not re.match(iso_8601_dt_l_r, '12345', *o)
    assert not re.match(iso_8601_dt_l_r, '1234-12', *o)
    assert not re.match(iso_8601_dt_l_r, '123456', *o)
    assert not re.match(iso_8601_dt_l_r, '12:12', *o)
    assert not re.match(iso_8601_dt_l_r, '12:12:12', *o)

    assert not re.match(iso_8601_dt_l_r, 'T-', *o)
    assert not re.match(iso_8601_dt_l_r, 'T123-', *o)
    assert not re.match(iso_8601_dt_l_r, 'T+', *o)
    assert not re.match(iso_8601_dt_l_r, 'TZ', *o)
    assert not re.match(iso_8601_dt_l_r, '1234T', *o)
    assert not re.match(iso_8601_dt_l_r, '1234TZ', *o)
    assert not re.match(iso_8601_dt_l_r, '123456T', *o)
