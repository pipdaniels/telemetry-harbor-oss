# Stage 1: The Builder
# This stage builds both the API and Worker binaries.
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -o /worker ./cmd/worker


# --- Final Stages ---

# Stage 2a: The API Image
# This creates the final, minimal image for the API server.
FROM gcr.io/distroless/static-debian11 AS api
WORKDIR /
COPY --from=builder /api /api
CMD ["/api"]


# Stage 2b: The Worker Image
# This creates the final, minimal image for the worker.
FROM gcr.io/distroless/static-debian11 AS worker
WORKDIR /
COPY --from=builder /worker /worker
CMD ["/worker"]
