# mp4-date-from-filename

Sample MP4 with all date metadata zeroed (`0000:00:00 00:00:00`) and a camera-style filename `VID_20190415_094527.mp4`.

Catches regressions in the filename date fallback (issue #10) and ensures zeroed video dates are not used as a filename.
