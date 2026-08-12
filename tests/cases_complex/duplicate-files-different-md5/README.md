# duplicate-files-different-md5

Same-second pairs with different MD5s (Phase 1 keeps both; Phase 2 logs them as
potential duplicates):

- Two Nexus 4 MS vs Google JPEG pairs
- One FinePix S5600 Adobe Photoshop IRB vs untagged pair

Exercises `MOVE_DUPLICATES=yes` (move into `duplicates/` with `_ms` / `_google` /
`_adobe` / `_untagged` suffixes) and `MOVE_DUPLICATES=no` (leave in place; still
write the log/txt).

Adobe detection uses the Photoshop APP13 marker (`Photoshop 3.0`) or
`Adobe Photoshop` — not the generic `http://ns.adobe.com/xap` XMP URI (that
appears in almost any XMP packet, including MS/Google copies).

Expected files:

- `expected_yes_duplicates.txt` — basenames under `duplicates/` after yes
- `expected_no_toplevel.txt` — basenames left at top level after no
- `expected_potential_duplicates.txt` — exact `potential_duplicates.txt`
