#!/usr/bin/env python3

import os, random, sys

# Usage: ./make_stuff_file.py [file(s)]

# This program takes file paths as a arguments. The contents of each file are
# concatenated into a single file, with random data stuffed in between file
# content. The goal is to simulate how special block device file might look
# when a filesystem is used on top of it (ie, a file, then a bunch of noise)

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
        
    print("Made {} KB of random stuff".format(max_stuff_size//1024))
    return rlst

def append_file(outfile, path):
    print("Appending {} KB from file '{}'".format(os.stat(path).st_size, os.path.basename(path)))
    try: 
        with open(path, "rb") as infile:
            while True:
                b = infile.read(1024)
                if b == b'':
                    break
                outfile.write(b)
        outfile.flush()
    except OSError:
        print("Problem opening '{}'".format(path), file=sys.stderr)

def append_stuff(outfile, max_stuff, random_stuff):
    bytes_to_add = random.randint(0, max_stuff)
    print("Adding {} KB of stuff".format(bytes_to_add//1024))
    start = len(random_stuff) - bytes_to_add
    outfile.write(bytes(random_stuff[start:]))


# "stuff" is data in-between
max_stuff = 1024*1024*10 # 10MB
random_stuff = get_stuff(max_stuff)
outfilename = "stuff_with_files_in_it.data"
filepaths = sys.argv[1:]

list(map(print,filepaths))

outfile = open("stuff_with_files_in_it.data", "wb")

for path in filepaths:
    append_stuff(outfile, max_stuff, random_stuff)
    append_file(outfile, path)

print("Writing...")
outfile.flush()
print("{} MB ({} files + random) written to '{}' ".format(
    os.stat(outfilename).st_size//1024//1024,
    len(filepaths), 
    outfilename))
