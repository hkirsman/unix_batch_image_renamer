# Unix Batch Image Renamer - Cursor Rules

## Project Overview
This is a Docker-based tool that renames image files (JPG, JPEG, HEIC) using EXIF data and MD5 hashes to create unique, chronologically ordered filenames.

## Key Rules

### File Naming Convention
- Images are renamed to format: `YYYY-MM-DD_HH-MM-SS_md5hash.ext`
- Example: `2020-01-05_13-47-38_433a170.jpg`
- Uses first 7 characters of MD5 hash for uniqueness
- Only renames files with valid EXIF date data (filename length > 17)

### Shell Script Guidelines
- Use `mmv` for safe file renaming (handles case differences)
- Normalize JPEG extensions to `.jpg`
- Convert all filenames to lowercase first
- Use `find` with `-print0` and `read -d ''` for safe file iteration
- Extract EXIF data using `exiftool -DateTimeOriginal`

### Docker Configuration
- Base image: Ubuntu 22.04 (multi-platform compatible)
- Required packages: `exiftool`, `md5deep`, `mmv`
- Script installed to `/usr/local/bin/`
- Volume mount pattern: `$(pwd)/:/app/:cached`
- Supports both AMD64 and ARM64 architectures

### Multi-Platform Build Commands
- `make build` - Build for current platform only
- `make build-multi` - Build for both linux/amd64 and linux/arm64
- `make build-push` - Build and push multi-platform image
- `make setup-buildx` - Setup buildx builder for multi-platform builds

### Error Handling
- Check filename length before renaming (must be > 17 characters)
- Suppress mmv output for extension normalization
- Handle files without valid EXIF data gracefully

### Development Notes
- Use `make build` to build Docker image for current platform
- Use `make build-multi` for cross-platform compatibility
- Test with sample images in mounted volume
- Ensure EXIF data exists in test images
- Docker image works on both Intel Macs and Apple Silicon
