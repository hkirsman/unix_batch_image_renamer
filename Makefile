# Build for current platform only
build:
	docker build -t hkirsman/unix-batch-image-renamer .

# Build for multiple platforms (linux/amd64, linux/arm64)
build-multi:
	docker buildx build --platform linux/amd64,linux/arm64 -t hkirsman/unix-batch-image-renamer .

# Build and push multi-platform image
build-push:
	docker buildx build --platform linux/amd64,linux/arm64 --push -t hkirsman/unix-batch-image-renamer .

# Create and use buildx builder if it doesn't exist
setup-buildx:
	docker buildx create --name multiarch --use || true
	docker buildx inspect --bootstrap
