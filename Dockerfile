FROM rust:slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev curl && \
    rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
RUN cargo fetch

COPY src ./src
RUN cargo build --release --jobs 1

FROM rust:slim AS development

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev curl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/* && \
    GRPCURL_VERSION=1.8.7 && \
    curl -sSL https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VERSION}/grpcurl_${GRPCURL_VERSION}_linux_arm64.tar.gz -o grpcurl.tar.gz && \
    tar -xzf grpcurl.tar.gz -C /usr/local/bin grpcurl && \
    rm grpcurl.tar.gz

COPY . .

ENV RUSTFLAGS="-C codegen-units=1 -C debuginfo=0"
ENV RUST_LOG=info

# Copy health check script
COPY scripts/health-check.sh /usr/local/bin/health-check
RUN chmod +x /usr/local/bin/health-check

EXPOSE 50052

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD health-check || exit 1

CMD ["cargo", "run"]

FROM debian:bookworm-slim AS production

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN addgroup --system app && adduser --system --ingroup app app

# Copy health check script
COPY scripts/health-check.sh /usr/local/bin/health-check
RUN chmod +x /usr/local/bin/health-check

# Copy binary from builder
COPY --from=builder /app/target/release/card_compose /app/card_compose

# Set permissions
RUN chown -R app:app /app
USER app

# Environment variables
ENV RUST_LOG=info

EXPOSE 50052

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD health-check || exit 1

CMD ["./card_compose"]
