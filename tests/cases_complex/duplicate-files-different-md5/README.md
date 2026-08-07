# duplicate-files-different-md5

Two same-second MS vs Google JPEG pairs (Nexus 4). Different MD5s, so Phase 1
keeps both; Phase 2 logs them as potential duplicates.

Exercises `MOVE_DUPLICATES=yes` (move into `duplicates/` with `_ms` / `_google`
suffixes) and `MOVE_DUPLICATES=no` (leave in place; still write the log/txt).

Expected files:

- `expected_yes_duplicates.txt` — basenames under `duplicates/` after yes
- `expected_no_toplevel.txt` — basenames left at top level after no
- `expected_potential_duplicates.txt` — exact `potential_duplicates.txt`
