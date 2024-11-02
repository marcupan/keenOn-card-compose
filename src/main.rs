use crate::config::Config;
use compose::compose_service_server::{ComposeService, ComposeServiceServer};
use compose::{ComposeRequest, ComposeResponse};
use dotenv::dotenv;
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

        match services::image_service::compose_image_with_text(&req.image_base64, &req.text) {
            Ok(composed_image) => {
                let reply = ComposeResponse { composed_image };
                Ok(Response::new(reply))
            }
            Err(e) => Err(Status::internal(format!("Failed to compose image: {}", e))),
        }
    }
}

#[tokio::main(flavor = "multi_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();

    let config = Config::from_env();

    println!("API Key: {}", config.api_key);

    let addr = format!("0.0.0.0:{}", config.port).parse()?;
    let compose_service = MyComposeService;

    let reflection_service = Builder::configure()
        .register_encoded_file_descriptor_set(compose::FILE_DESCRIPTOR_SET)
        .build_v1()?;

    Server::builder()
        .add_service(ComposeServiceServer::new(compose_service))
        .add_service(reflection_service)
        .serve(addr)
        .await?;

    Ok(())
}
