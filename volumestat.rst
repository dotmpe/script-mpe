Helper for mounts

Darwin
------
Monitoring a single mount, or subscribing for events for one path does not seem
possible.

Instead WatchPaths allows to monitor any directory for changes, and by scanning
for paths we can determine mounts. Iow. scripts should adapt to events happening
for one or multiple paths, or possibly for

This means that there is never an event for
a
single path, but

