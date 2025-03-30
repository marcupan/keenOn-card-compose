use crate::config::Config;
use compose::compose_service_server::{ComposeService, ComposeServiceServer};
use compose::{ComposeRequest, ComposeResponse};
use dotenv::dotenv;
use env_logger;
use log::{error, info};
use tonic::{transport::Server, Request, Response, Status};
use tonic_reflection::server::Builder;

mod config;
mod services;
mod compose {
    tonic::include_proto!("compose");
    pub const FILE_DESCRIPTOR_SET: &[u8] = include_bytes!("../target/descriptor/compose.bin");
}

pub struct MyComposeService;

#[tonic::async_trait]
impl ComposeService for MyComposeService {
    async fn compose_image(
        &self,
        request: Request<ComposeRequest>,
    ) -> Result<Response<ComposeResponse>, Status> {
        let req = request.into_inner();

        match services::image_service::compose_image_with_text(
            &req.image_base64,
            &req.text,
            &req.sentences,
        ) {
            Ok(composed_image) => {
                info!("Successfully composed image");
                let reply = ComposeResponse { composed_image };
                Ok(Response::new(reply))
            }
            Err(err) => {
                error!("Failed to compose image: {}", err);
                Err(Status::internal(format!(
                    "Failed to compose image: {}",
                    err
                )))
            }
        }
    }
}

#[tokio::main(flavor = "multi_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    env_logger::init();

    let config = Config::from_env();

    let addr = format!("0.0.0.0:{}", config.port).parse()?;
    let compose_service = MyComposeService;

    let reflection_service = Builder::configure()
        .register_encoded_file_descriptor_set(compose::FILE_DESCRIPTOR_SET)
        .build_v1()?;

    info!("Starting server on address: {}", addr);
    Server::builder()
        .add_service(ComposeServiceServer::new(compose_service))
        .add_service(reflection_service)
        .serve(addr)
        .await?;

    Ok(())
}
