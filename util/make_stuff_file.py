#!/usr/bin/env python3

import os, random, sys

# Usage: ./make_stuff_file.py [dirpath] [maxfiles]

# This program accepts two arguments, a directory path, and an integer.  The
# directory path is searched recursively for files that contain a particular
# extension. When a number of these files are found, their contents are
# concatenated into a single file with random data stuffed in between the file
# content. The goal is to simulate how special block device file might look
# when a filesystem is used on top of it

def get_stuff(max_stuff_size):

    num_segments = 10
    len_segment = 255

    segments = []
    for i in range(0,num_segments):
        segment = list(map(lambda x: random.randint(0,255), range(0,len_segment)))
        segments.append(segment)

    rlst = []

    for i in range(max_stuff_size//len_segment):
        rlst.extend(segments[random.randint(0,num_segments-1)])
        
    print("Made {}KB of random stuff".format(max_stuff_size/1024))
    return rlst

def append_file(outfile, path):
    print("Appending {}KB from file '{}'".format(os.stat(path).st_size, os.path.basename(path)))
    with open(path, "rb") as infile:
        while True:
            b = infile.read(1024)
            if b == b'':
                break
            outfile.write(b)
    outfile.flush()

def append_stuff(outfile, max_stuff, random_stuff):
    bytes_to_add = random.randint(0, max_stuff)
    print("Adding {}KB of stuff".format(bytes_to_add/1024))
    start = len(random_stuff) - bytes_to_add
    outfile.write(bytes(random_stuff[start:]))

def get_filepath_set(toppath, extensions, maxfiles, max_stuff_size):
    filepaths = set()
    for dirpath, dirnames, filenames in os.walk(toppath):
        for filename in filenames:
            path = os.path.join(dirpath, filename)
            if len(filepaths) >= maxfiles:
                return filepaths
            if os.path.splitext(path)[-1][1:] in extensions:
                filepaths.add(path)

    return filepaths


# "stuff" is data in-between
max_stuff = 1024*1024*10 # 10MB
random_stuff = get_stuff(max_stuff)
maxfiles = int(sys.argv[2])
extensions = ["png", "jpg", "jpeg", "gif", "pdf"]
outfilename = "stuff_with_files_in_it.data"
startdir = sys.argv[1]
filepaths = get_filepath_set(startdir, extensions, maxfiles, max_stuff)

list(map(print,filepaths))

outfile = open("stuff_with_files_in_it.data", "wb")

for path in filepaths:
    append_stuff(outfile, max_stuff, random_stuff)
    append_file(outfile, path)

print("Writing...")
outfile.flush()
print("{}MB ({} files + random) written to '{}' ".format(
    os.stat(outfilename).st_size//1024//1024,
    len(filepaths), 
    outfilename))
