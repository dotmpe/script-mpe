writepl - Write playlist file based on times and tags

Usage::

  writepl myplaylist.vlc.m3u
  writepl myplaylist.mpv.sh

Convert a simple text file to a playlist. Above usage example reads ``myplaylist.tab`` and updates out-of-date playlist files.
The script is designed to run from the root of a media folder,
to support time ranges, and (had some) initial support for titles and tags and filtering on tags.

Advanced usage::

  writepl myplaylist.raw "" -        # Echo output, do not try to update file
  writepl myplaylist.raw alt.tab -   # Alternative table input, do not update
  writepl myplaylist.raw alt.tab     # Update file from alt. table file

There does not seem to be a common standard to add time offsets to playlist items.
Current supported formats are M3U with EXTVLCOPT for VideoLAN, and a shell script to use to invoke MPV.

Table format
------------
Each entry is a combination of a local filepath and a time range in seconds or
time (H:M:s or M:s) time-notation.

To list a 54 second clip starting at 10 seconds alternatively use::

  10 64 media.mp4
  0:10 1:04 media.mp4

To play an entire file::

  * * media.mp4
  0 - media.mp4

And to enter multiple entries for one file::

  - - media.mp4
  0:34 1:29
  2:12 3:54

and also to add several metadata fields to an entry::

  - - media.mp4 #:title: Title text
  - - #:tags: tag1 tag2
  11:03 11:22

Files may be specified without directory, but this will require a  ``find`` invocation to gather all the actual path locations/

- TODO: Cache dir locations after ``find`` to speed up/
  same goes for time calc which is unoptimized

Comments are ignored, but ``#:`` lines or fields are parsed and processed as metadata

Metadata
--------
The directory can be specified as document-level metadata, it will apply to
all following entries but is ignored with a warning if no entry exists there.
::

  #:Dir: path/to/playlist-files

TODO: specify how doc/file/entry metadata is handled and update scripts,
then see if tag selection is still working.
'~' character in title indicates substitution placeholder for parent title,
initial empty space indicates to concatenate parent title in front of entry.

MPV Options
___________
MPV scripts include ``list:mpv`` metadata as additional options.
For example to select subtitle track Id 2 and Japanese audio::

  #:list:mpv:sid: 2
  #:list:mpv:alang: jpn

Results in ``.mpv.sh`` lines::

  --sid=2 \
  --alang=jpn \

Status
------
sometimes events without end time would be nice to enter.
Ie. for chapters.

or to generate specific lists from master files with lots of metadata.

subtitles can be used for interesting things as well.

not a lot of programs seem to support time-limits on playlist entries.
E.g. for MPV need to use command-line options to generate a 'playlist'.

MPV EDL seems to support for per-media mute or skip files?



..
