# old-file-from-2002

Sample JPG with EXIF from 2002. This case ensures the script still works with files from cameras 20+ years old.

Catches regressions in `DateTimeOriginal` parsing / formatting for older camera EXIF, and the default rename path (`YYYY-MM-DD_HH-MM-SS_<md5>.jpg`).
