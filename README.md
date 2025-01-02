# Image Composition Service

**Image Composition Service** is a microservice within the **KeenOn Card Generate** project. It generates visual learning aids by combining translated text with images.

## Overview

The Image Composition Service takes translated text and overlays it on an image to produce visually engaging learning cards. It connects to the **Central Hub API** via **gRPC** to receive data and return the final visual output.

## Key Features
- **Image Processing**: Combines text and images for custom visuals.
- **Rust Performance**: Utilizes Rust for speed and reliability.
- **gRPC Communication**: Ensures smooth data handling between services.
- **Educational Tools**: Designed to create effective visual aids for learners.

## Technologies Used
- **Rust**: Core language for processing and composition.
- **gRPC**: Communication protocol for interoperability.
- **Docker**: Ensures containerized deployment.
