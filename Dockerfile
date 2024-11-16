# Stage 1: Build Stage
FROM rust:slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y protobuf-compiler pkg-config libssl-dev

# Copy over manifest files and build dependencies first to cache layers
COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto

# Fetch dependencies (build step caching)
RUN cargo build --release --locked

# Copy the source code and build the project
COPY src ./src
RUN cargo build --release

# Stage 2: Production Stage
FROM debian:buster-slim AS production

WORKDIR /app

# Copy the build artifact from the builder
COPY --from=builder /app/target/release/card_compose /app/card_compose

ENV RUST_LOG=info
EXPOSE 50052

CMD ["./card_compose"]

# Stage 3: Development Stage
FROM rust:slim AS development

WORKDIR /app

# Install development dependencies
RUN apt-get update && apt-get install -y protobuf-compiler pkg-config libssl-dev

# Copy the entire project for development
COPY . .

CMD ["cargo", "run"]
