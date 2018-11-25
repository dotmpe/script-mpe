A quick preproc in Bash rather than Bourne to prototype using the regex
matching.

Each include will need to be processed as well, and no caching is done
automatically.

The lookup is done with one resolve_include, that either looks for the
include ID, with any of the extensions or not and echoes the first existing
path. The same it does in global mode using SCRIPTPATH for lookup by default.

A better system would cache the preprocess output and record dependencies
so there is a way to validate the cache.

Maybe a scheme using an inserted extension or other name reformatting.
Maybe at another basedir (.build et al) too.
```
preproc_c main
...
  preproc $1.sh > $1.c.sh

```

TODO: setup lib global vars
```
preproc_exts=.inc.sh
preproc_dest=.d
preproc_path=SCRIPTPATH
```
