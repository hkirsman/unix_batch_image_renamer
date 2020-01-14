FROM ubuntu

WORKDIR /app

ADD unix_batch_image_renamer.sh /usr/local/bin/unix_batch_image_renamer.sh

RUN apt-get update

RUN apt-get install -y exif md5deep

ENTRYPOINT ["unix_batch_image_renamer.sh"]
