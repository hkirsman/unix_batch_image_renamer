# Unix batch image renamer

All cameras have their own way of naming images. This tool creates unique
names for the image by reading the exif data in the image plus it appends
md5 hash based on the image source. The image name becomes something like this:
2020-01-05_13-47-38_433a170.jpg

If you have [Docker](https://docs.docker.com/get-docker/), then cd to the folder where images are and execute:

    docker run --rm -t -i --volume "$(pwd)/:/app/:cached" hkirsman/unix-batch-image-renamer

There's also argument to keep the original file name suffixed:

    docker run --rm -t -i --volume "$(pwd)/:/app/:cached" hkirsman/unix-batch-image-renamer keep-file-names

I'm using this system to have unique file names for my photos and to order them
nicely in the file system. First I just used time in the naming, but there where
files with exact same date (photos taken with little interval) so I started
adding suffix (1), (2) etc. But sometimes I had copied some of the
photos to other places and renamed them with other suffix. Then when gathering
the photos to a single place there was no way of making difference between them
just by looking in the file name. By using first 7 characters of the file md5
hash I can be sure of the file uniqueness. Also I can later check if the file
is still ok by checking the md5.

## Potential duplicates

Exact byte duplicates (same MD5) are overwritten during rename. Different copies
of the “same” photo that still share the same capture second (e.g. a Windows
MicrosoftPhoto copy vs a Google-processed copy) keep different MD5s and both
survive. After renaming, the script groups those same-second files and writes:

- `potential_duplicates.log` — human-readable sizes, camera/Make, MS/Google tag hints
- `potential_duplicates.txt` — basenames only (blank line between groups); used as the move list

If any sets are found, you are prompted once to move **all** listed files into
`./duplicates/`, appending a tag suffix before the extension:

| Tags | Suffix |
|------|--------|
| MicrosoftPhoto only | `_ms` |
| Google Software/CreatorTool only | `_google` |
| Both | `_ms_google` |
| Neither | `_untagged` |

Example: `2013-06-20_14-43-41_789f3aa.jpg` → `duplicates/2013-06-20_14-43-41_789f3aa_ms.jpg`

Decline the prompt (default) to leave files in place and review from the logs.
For non-interactive runs (no TTY), set an environment variable:

```bash
docker run --rm -t -i -e MOVE_DUPLICATES=yes --volume "$(pwd)/:/app/:cached" hkirsman/unix-batch-image-renamer
# or MOVE_DUPLICATES=no to skip the move without prompting
```

## Multi-Platform Support

This Docker image supports both AMD64 (Intel) and ARM64 (Apple Silicon) architectures. The image will automatically use the correct architecture for your system.

### Building Locally

To build the image for your current platform:
```bash
make build
```

To build for both platforms (useful for distribution):
```bash
make build-multi
```

## Testing

Run all fixture suites (builds the image first):

```bash
make test
```

Or, if you don't have `make` (image must already be built):

```bash
bash tests/run.sh          # both suites
bash tests/run_rename.sh   # single-file rename only
bash tests/run_complex.sh  # potential-duplicate / MOVE_DUPLICATES only
```

### `tests/cases_rename/<name>/`

One media file per case:

- one media file (`.jpg`, `.jpeg`, `.heic`, or `.mov`)
- `expected.txt` — exact final filename after rename (one line)
- `README.md` — why this sample exists

### `tests/cases_complex/<name>/`

Multi-file cases (e.g. same-second MS vs Google pairs). Each case is run with
`MOVE_DUPLICATES=yes` and `MOVE_DUPLICATES=no`:

- two or more media files
- `expected_yes_duplicates.txt` — sorted basenames under `duplicates/` after yes
- `expected_no_toplevel.txt` — sorted basenames left top-level after no
- `expected_potential_duplicates.txt` — exact `potential_duplicates.txt`
- `README.md` — why this sample exists

Fixtures are never modified in place; runners copy media into `.test-work/` first.
