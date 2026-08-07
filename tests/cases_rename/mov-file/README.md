# mov-file

Sample MOV with video CreateDate metadata.

Catches regressions in the video date path (CreateDate when `DateTimeOriginal` is absent) and the default rename for `.mov` (`YYYY-MM-DD_HH-MM-SS_<md5>.mov`).
