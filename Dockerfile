FROM rust:slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y protobuf-compiler

COPY Cargo.toml Cargo.lock build.rs ./
COPY proto ./proto
COPY src ./src

RUN echo "Checking /app before build" && ls -la /app

RUN cargo build --release || (echo "Build failed" && exit 1)

RUN echo "Checking /app/target/release after build" && ls -la /app/target/release

FROM rust:slim AS production

WORKDIR /app

COPY --from=builder /app/target/release/card_compose /app/card_compose

ENV RUST_LOG=info

EXPOSE 50052

CMD ["./card_compose"]
