FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install git (needed for go mod download)
RUN apk add --no-cache git

# Copy only go.mod first (go.sum doesn't exist yet)
COPY go.mod ./

# Download dependencies (this will generate go.sum inside the image layer)
RUN go mod download

# Copy the rest of the source code
COPY . .

# Ensure go.sum is generated with all required (including indirect) dependencies
RUN go mod tidy

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o cart .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/cart .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

# Expose port
EXPOSE 7001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:7001/health || exit 1

# Run the application
CMD ["./cart"]

