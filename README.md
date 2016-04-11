# recbinfi
`recbinfi` is a program that undeletes binary files based on their [file
signatures](https://en.wikipedia.org/wiki/List_of_file_signatures). Currently,
it is capable of recovering JPG, GIF, PNG, and PDF file types.  Support for more
file types is coming!

# Usage
`recbinfi` takes a file path as an argument. On Unix-like systems, a special
block device file may be used, causing it to 'undelete' files on a given device
or partition.

On Linux, for example, `/dev/sda` usually represents the hosts primary storage
device. `recbinfi` can search it like so:

```
$ recbinfi /dev/sda
```

A new directory `output` will be created in your current path, and any files it
finds will be outputted there. You should see the names of the files (an
integer with a filename extension) and their respective sizes printed to the
console.

You can also use `recbinfi` to un-concatenate files. For example, say you have 
3 JPG images: `a.jpg`, `b.jpg`, and `c.jpg`: 

```
# Stuff all 3 images into a single file

$ cat a.jpg b.jpg c.jpg > abc.jpgs

# Seperate them with recbinfi

$ recbinfi abc.jpgs
0.jfif.jpg           (209 KB)
1.jfif.jpg           (83 KB)
2.jfif.jpg           (528 KB)
EOF
```

Note that when using `recbinfi` for file-recovery purposes, it is ideal to use
it from a path on a **separate device**, since there is a chance that the files
it recovers will overwrite other recoverable data on the disk.

### Caveats

- PDF files with more than one EOF marker will probably not be recovered correctly. See [this StackOverflow post](http://stackoverflow.com/questions/11896858/does-the-eof-in-a-pdf-have-to-appear-within-the-last-1024-bytes-of-the-file/29489874#29489874).

# TODO

- Switching on/off file formats for flexibility/performance 
- Add a proper commandline interface (options, help, version...)
- Add support for more formats (zip, media files,  ...)
- Separate file formats into their own file
- More reliability testing
- Put all JPG types into one output directory
