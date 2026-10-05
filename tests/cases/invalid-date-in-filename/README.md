# invalid-date-in-filename

Sample MP4 with zeroed date metadata and an impossible date in its name, `vid_20230231_094527.mp4` (February 31).

Catches regressions in calendar validation of the filename date fallback: the file must be skipped, not renamed to an impossible timestamp.
