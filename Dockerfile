# services/keenOn-card-compose/Dockerfile

# Build Stage
FROM rust:slim AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
RUN cargo fetch
COPY src ./src
RUN cargo build --release

# Development Stage
FROM rust:slim AS development
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
COPY . .
EXPOSE 50052
CMD ["cargo", "run"]

# Production Stage
FROM debian:bookworm-slim AS production
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
USER app
COPY --from=builder /app/target/release/card_compose /app/card_compose
EXPOSE 50052
CMD ["./card_compose"]
