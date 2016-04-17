#!/bin/sh

# Uses ImageMagick's 'identify' to determine if an image file is corrupt
# If it is, echo the filename

for i in $@ ; do identify "$i" &> /dev/null ; if [ $? -eq 1 ] ; then echo "$i" ; fi ; done
