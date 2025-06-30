# Image Composition Service

**Image Composition Service** is a microservice within the **KeenOn Card Generate** project. It generates visual learning aids by combining translated text with images.

## Overview

The Image Composition Service takes translated text and overlays it on an image to produce visually engaging learning cards. It connects to the **Central Hub API** via **gRPC** to receive data and return the final visual output.

## Key Features
- **Image Processing**: Combines text and images for custom visuals.
- **Rust Performance**: Utilizes Rust for speed and reliability.
- **gRPC Communication**: Ensures smooth data handling between services.
- **Educational Tools**: Designed to create effective visual aids for learners.

## Setup Instructions

### Prerequisites

- Rust (1.70 or higher)
- Cargo (latest version)
- Docker and Docker Compose (for containerized deployment)
- Image processing libraries (automatically installed via Cargo)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/orchestrator-repo.git
   cd orchestrator-repo/services/keenOn-card-compose
   ```

2. Build the project:
   ```bash
   cargo build
   ```

3. Set up environment variables:
   ```bash
   # Copy the sample environment file
   cp sample.env .env
   # Edit .env with your configuration
   ```

4. Start the service:
   ```bash
   # With Docker (recommended)
   docker-compose up -d

   # Without Docker
   cargo run
   ```

### Running Tests

```bash
# Run all tests
cargo test

# Run tests with coverage (requires cargo-tarpaulin)
cargo tarpaulin
```

## Development Workflow

1. Make changes to the codebase
2. Run linting:
   ```bash
   cargo clippy
   ```
3. Run tests:
   ```bash
   cargo test
   ```
4. Format code:
   ```bash
   cargo fmt
   ```

## Deployment

### Production Deployment

```bash
# Build the Docker image
docker build -t keenon-card-compose:latest .

# Run with Docker Compose
docker-compose -f docker-compose.yml -f docker-compose.production.yml up -d
```

## API Documentation

The service exposes gRPC endpoints defined in the `proto` directory. The main service methods include:

- `ComposeImage`: Combines text and image to create a learning card
- `ApplyTemplate`: Applies a predefined template to the card
- `ResizeImage`: Adjusts image dimensions as needed
- `AddWatermark`: Optionally adds a watermark to the image

## Performance Considerations

The Image Composition Service is written in Rust for optimal performance when processing images. It uses:

- Parallel processing for batch operations
- Memory-efficient image handling
- Optimized rendering algorithms

## Technologies Used
- **Rust**: Core language for processing and composition.
- **gRPC**: Communication protocol for interoperability.
- **Docker**: Ensures containerized deployment.
- **Image Processing Libraries**: For manipulating and combining visual elements.

---

> **Note:** This project is not production-ready but is intended as a demonstration of my learning progress in backend development.
