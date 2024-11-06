# Base image for building the application
FROM rust:slim AS builder

# Set the working directory
WORKDIR /app

# Copy the Cargo.toml and source code
COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Build the application for production
RUN cargo build --release

# Stage for development
FROM rust:slim AS development

# Set the working directory
WORKDIR /app

# Install dependencies for development
RUN rustup component add clippy rustfmt

# Copy the source code and build output from the builder stage
COPY --from=builder /app/target/release/card_compose /app/card_compose
COPY src ./src

# Command to run in development mode
CMD ["cargo", "run"]

# Final stage for production
FROM rust:slim AS production

# Set the working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/target/release/card_compose /app/card_compose

# Set environment variables for production
ENV RUST_LOG=info

# Expose the application port
EXPOSE 4000

# Command to run in production mode
CMD ["./card_compose"]
