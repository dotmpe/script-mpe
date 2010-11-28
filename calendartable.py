#!/usr/bin/env python
"""
:date: 2010-09-14

convert table to ical


FIXME: splitting columns does not work like this, fixed with cell implementaiton
is needed.
TODO: instead write USN-AAD/USNO RS-table to Google Calendar compatible CSV?
XXX: CSV convertors/tools?
XXX: ~dotmpe/archive/3/cabinet/2010/09/sunset-sundown.txt

"""
from icalendar import Calendar, Event
from datetime import datetime
from icalendar import UTC # timezone



if __name__ == '__main__':
    import sys 

    # XXX: prolly dont do this but add conversion to CSV
    #colrow_layout = 'month', 'day'
    line_offset = 6, 2 
    colrow_offset = 3, 1
    cell_values = 'dtstart', 'dtend'
    IFS=' '

    column_width = len(cell_values)
    now = datetime.now(UTC)
    
    cal = Calendar()
    #cal.add('prodid', '-//My calendar product//mxm.dk//')
    #cal.add('version', '2.0')

    rows = sys.stdin.readlines()

    year = 2010
    headers = [],[]
    for line in rows[line_offset[0]:-line_offset[1]]:
        # XXX: stripping for convenience!
        cells = [d.strip() for d in line.split(IFS) if d.strip()]
        if len(headers[0]) < colrow_offset[0]:
            headers[0].append(line) # XXX: unparsed column header
        else:
            headers[1].append(cells[:colrow_offset[1]])
            day = int(cells[0])
            if day == 29:
            	break
            cells = cells[colrow_offset[1]:]
            month = 0
            while cells:
                month += 1
                values, cells = cells[:column_width], cells[column_width:]
                if not (values[0] and values[1]):
                	continue
                event = Event()
                event.add('summary','Sunlight hours')
                for prop, value in zip(cell_values, values):
                    hour, minute = map(int, [value[:2],value[2:]])
                    event.add(prop, datetime(
                        year,month,day,hour,minute,tzinfo=UTC))
                event.add('dtstamp', now)
                #event['uid'] = '20050115T101010/27346262376@mxm.dk'
                #event.add('priority', 5)
                cal.add_component(event)

    print cal.as_string()
    #f = open('example.ics', 'wb').write(cal.as_string()) 

