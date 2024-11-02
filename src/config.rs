use std::env;

#[derive(Debug)]
pub struct Config {
    pub api_key: String,
    pub port: u16,
}

impl Config {
    pub fn from_env() -> Self {
        let api_key = env::var("API_KEY").expect("API_KEY must be set");
        let port = env::var("PORT")
            .unwrap_or_else(|_| "50051".to_string())
            .parse()
            .expect("PORT must be a number");

        Config { api_key, port }
    }
}
