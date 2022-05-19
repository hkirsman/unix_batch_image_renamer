# Unix batch image renamer

All cameras have their own way of naming images. This tool creates unique
names for the image by reading the exif data in the image plus it appends
md5 hash based on the image source. The image name becomes something like this:
2020-01-05_13-47-38_433a170.jpg

If you have [Docker](https://docs.docker.com/get-docker/), then cd to the folder where images are and execute:

    docker run --rm -t -i --volume "$(pwd)/:/app/:cached" hkirsman/unix-batch-image-renamer

I'm using this system to have unique file names for my photos and to order them
nicely in the file system. First I just used time in the naming, but there where
files with exact same date (photos taken with little interval) so I started
adding suffix (1), (2) etc. But sometimes I had copied some of the
photos to other places and renamed them with other suffix. Then when gathering
the photos to a single place there was no way of making difference between them
just by looking in the file name. By using first 7 characters of the file md5
hash I can be sure of the file uniqueness. Also I can later check if the file
is still ok by checking the md5.
