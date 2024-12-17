# Build Stage
FROM rust:slim AS builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy Cargo files and fetch dependencies
COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
RUN cargo fetch

# Copy source and build release
COPY src ./src
RUN cargo build --release

# Development Stage
FROM rust:slim AS development

WORKDIR /app

# Install dependencies for development
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy all files for development
COPY . .

# Expose development port
EXPOSE 50052

CMD ["cargo", "run"]

# Production Stage
FROM debian:bookworm-slim AS production

WORKDIR /app

# Use non-root user
RUN addgroup --system app && adduser --system --ingroup app app
USER app

# Copy build artifact from builder
COPY --from=builder /app/target/release/card_compose /app/card_compose

# Expose production port
EXPOSE 50052

CMD ["./card_compose"]
