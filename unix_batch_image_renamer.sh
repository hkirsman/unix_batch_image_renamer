for i in *.jpg; do
  md5=`md5deep "$i" | cut -c 1-7`.jpg
  date_raw=`exif --tag="DateTimeOriginal" "$i" | sed -n '6p'`
  year=`echo "$date_raw" | cut -c 10-13`
  month=`echo "$date_raw" | cut -c 15-16`
  day=`echo "$date_raw" | cut -c 18-19`
  hour=`echo "$date_raw" | cut -c 21-22`
  minute=`echo "$date_raw" | cut -c 24-25`
  second=`echo "$date_raw" | cut -c 27-28`
  mv -i "$i" "$year-$month-$day"_"$hour-$minute-$second"_"$md5"
done
