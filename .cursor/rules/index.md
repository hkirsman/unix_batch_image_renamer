# Unix Batch Image Renamer - Cursor Rules

## Project Overview
A Docker-based tool that renames media files (JPG, JPEG, HEIC, MOV) using EXIF/video date tags plus an MD5 suffix for unique, chronologically ordered filenames.

## Key Rules

### File Naming Convention
- Renamed format: `YYYY-MM-DD_HH-MM-SS_<7-char-md5>.ext`
- Example: `2020-01-05_13-47-38_433a170.jpg`
- Images: prefer `DateTimeOriginal`; videos: fall back to `CreateDate`
- Skip files with no usable date; do not invent dates from filesystem mtime

### Shell Script Guidelines
- Requires Bash 4+ (`${var,,}` etc.); intended to run in the Docker image
- Keep `*.sh` as LF line endings (see `.gitattributes`) — CRLF breaks the Linux shebang
- Use `mmv` for renames (including case-only changes)
- Lowercase all filenames first; normalize `*.jpeg` → `*.jpg`
- Use `find` with `-print0` and `read -d ''` for safe iteration
- Extract dates with `exiftool -q -q -p '...' -d "%Y-%m-%d_%H-%M-%S"`

### Docker Configuration
- Base image: Ubuntu 22.04 (multi-platform)
- Packages: `exiftool`, `md5deep`, `mmv`
- Script at `/usr/local/bin/unix_batch_image_renamer.sh`
- Volume mount: `$(pwd)/:/app/:cached`
- On Git Bash / MSYS, use `MSYS_NO_PATHCONV=1` for Docker `-v` mounts so `/app` is not rewritten

### Make Targets
- `make build` — current platform
- `make build-multi` / `make build-push` — multi-arch
- `make setup-buildx` — buildx builder
- `make test` — build image, then run fixture suite (`bash tests/run.sh` if no make)

### Testing
- Cases live in `tests/cases/<name>/`: one media file, `expected.txt` (exact final name), `README.md` (why the case exists)
- Never run the renamer on committed fixtures — `tests/run.sh` copies media only into `.test-work/`
- Golden `expected.txt` names must be hand-recorded from a known-good run; do not recompute date+md5 inside the assert
- Keep fixtures small (plain Git is fine; no LFS required for current sizes)
- After changing the renamer, run `make test` or `bash tests/run.sh`

### Error Handling
- Suppress noisy mmv output for extension normalization
- Handle missing date tags by skipping and counting in the summary
