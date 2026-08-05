# old-file-from-2002

Sample JPG with EXIF from 2002. We've added this because it's over 20 years old and in theory we're making sure our script works
also with old files made with cameras 20+ years ago.

Catches regressions in `DateTimeOriginal` parsing / formatting for older camera EXIF, and the default rename path (`YYYY-MM-DD_HH-MM-SS_<md5>.jpg`).
