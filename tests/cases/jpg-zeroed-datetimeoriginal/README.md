# jpg-zeroed-datetimeoriginal

Sample JPG whose `DateTimeOriginal` is zeroed (`0000:00:00 00:00:00`) while `CreateDate` holds a valid date.

Catches regressions where an unusable first tag stops the script from trying `CreateDate`.
