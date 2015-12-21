# Unix batch image renamer

This batch file finds all the jpg files in current folder and renames them to
[YEAR]-[MONTH]-[DAY]_[HOUR]_[MINUTE[]_[SECOND]_[UNIQUE_MD5_HASH_OF_THE_FILE].jpg
according to exif data in the image.

I'm using this system to have unique file names for my photos and to order them nicely in the file system. First I just used time in the naming but there where files with excact same date (photos taken with little interval) so I started adding suffix (1), (2) etc. But sometimes I had copied some of the photos to other places and renamed them with other suffix. Then when gathering the photos to a single place there was no way of making difference between them just by looking in the file name. By using first 7 characters of the file md5 hash I can be sure of the file uniqueness. Also I can later check if the file is still ok by checking the md5.
