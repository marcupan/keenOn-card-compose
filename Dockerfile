# Build Stage
FROM rust:slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy Cargo files and fetch dependencies (cache dependencies layer)
COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
RUN cargo fetch

# Copy source and build release with limited concurrency to reduce memory usage
COPY src ./src
RUN cargo build --release --jobs 1

# Development Stage
FROM rust:slim AS development

WORKDIR /app

# Install dependencies for development
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy all files for development
COPY . .

# Set RUSTFLAGS to limit codegen units and reduce debug info
ENV RUSTFLAGS="-C codegen-units=1 -C debuginfo=0"

# Build with a single job to further reduce memory usage during linking
RUN cargo build --jobs 1

# Expose development port (adjust as needed)
EXPOSE 50052

# Run the application in debug mode
CMD ["cargo", "run"]

# Production Stage
FROM debian:bookworm-slim AS production

WORKDIR /app

# Create a non-root user for security
RUN addgroup --system app && adduser --system --ingroup app app
USER app

# Copy build artifact from builder
COPY --from=builder /app/target/release/card_compose /app/card_compose

# Expose production port
EXPOSE 50052

CMD ["./card_compose"]
