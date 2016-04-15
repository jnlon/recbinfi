# recbinfi
`recbinfi` is a program that undeletes binary files based on their [file
signatures](https://en.wikipedia.org/wiki/List_of_file_signatures). Currently,
it is capable of recovering JPG, GIF, PNG, ZIP, and PDF file types.  Support for more
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

For certain formats, you can also use `recbinfi` to un-concatenate files.
For example, say you have 3 PNG images: `a.png`, `b.png`, and `c.png`: 

```
# Stuff all 3 images into a single file

$ cat a.png b.png c.png > abc.pngs

# Seperate them with recbinfi

$ recbinfi abc.pngs
0.png    +378 KB (0x0 - 0x5EBB8)
1.png     +11 KB (0x5EBB9 - 0x61856)
2.png    +220 KB (0x61857 - 0x98982)
EOF

```

Note that when using `recbinfi` for file-recovery purposes, it is ideal to run
it from a path on a **separate device**, since there is a chance that the files
it recovers will overwrite other recoverable data on the disk.

### Caveats

- Certain filetypes (such as JPG, GIF, and PDF) have indefinite end-of-file
  signatures. This means that disk recovery will usually work for these
  formats, but you cannot perform the un-concatenate trick on them as
  demonstrated above. 

- There is a chance that while your file was deleted from the disk, some other
  data was written over top of it. In these cases, `recbinfi` will still be
  able to recover your file (unless the file signatures were overwritten),
  however the file will probably be corrupted and you won't be able to open it.

# TODO

- Switching on/off file formats for flexibility/performance (un-hard-code max_sizes)
- Add a proper commandline interface (options, help, version...)
- Add support for more formats (media files?)
- Separate file formats into their own file
- Add a technical README for documentation purposes
