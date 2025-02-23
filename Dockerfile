FROM rust:slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
RUN cargo fetch

COPY src ./src
RUN cargo build --release --jobs 1

FROM rust:slim AS development

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

COPY . .

ENV RUSTFLAGS="-C codegen-units=1 -C debuginfo=0"

RUN cargo build --jobs 1

EXPOSE 50052

CMD ["cargo", "run"]

FROM debian:bookworm-slim AS production

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app
USER app

COPY --from=builder /app/target/release/card_compose /app/card_compose

EXPOSE 50052

CMD ["./card_compose"]
