#!/bin/sh


# ID for simple strings without special characters
mkid()
{
	id=$(echo "$1" | tr '.-' '__')
}

# to filter strings to valid id
mkvid()
{
	vid=$(echo "$1" | sed 's/\([^a-z0-9_]\|\_\)/_/g')
}
mkcid()
{
	cid=$(echo "$1" | sed 's/\([^a-z0-9-]\|\-\)/-/g')
}

