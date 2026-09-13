FROM golang:1.22-alpine AS builder

# Install dependencies
RUN apk add --no-cache git gcc musl-dev sqlite-libs-dev

# Set working directory
WORKDIR /app

# Copy go.mod first for caching
COPY backend/go.mod backend/go.sum ./
RUN go mod download

# Copy source code
COPY backend/ .

# Build the binary
RUN CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o main .

# Final stage - minimal runtime image
FROM alpine:latest

# Install runtime dependencies (for SQLite)
RUN apk add --no-cache sqlite-libs

WORKDIR /app

# Copy built binary from builder
COPY --from=builder /app/main .
COPY --from=builder /app/go.* .

# Expose port
EXPOSE 8080

# Start the server
CMD ["./main"]
