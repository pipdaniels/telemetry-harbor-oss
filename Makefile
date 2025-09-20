.PHONY: build run-api run-worker run-all clean deps

# Build targets
build:
	go build -o bin/api ./cmd/api
	go build -o bin/worker ./cmd/worker

# Development targets
deps:
	go mod download
	go mod tidy

run-api: build
	./bin/api

run-worker: build
	./bin/worker

run-all: build
	./bin/api & ./bin/worker

# Production targets
build-prod:
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/api ./cmd/api
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/worker ./cmd/worker

# Cleanup
clean:
	rm -rf bin/