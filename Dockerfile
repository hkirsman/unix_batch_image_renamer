FROM --platform=$BUILDPLATFORM ubuntu:22.04

WORKDIR /app

ADD unix_batch_image_renamer.sh /usr/local/bin/unix_batch_image_renamer.sh

RUN apt-get update

## mmv needed to rename file if only case is different.
RUN apt-get install -y exiftool md5deep mmv

ENTRYPOINT ["unix_batch_image_renamer.sh"]
