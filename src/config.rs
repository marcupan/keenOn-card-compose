use std::env;

#[derive(Debug)]
pub struct Config {
    pub port: u16,
}

impl Config {
    pub fn from_env() -> Self {
        let port = env::var("PORT")
            .unwrap_or_else(|_| "50051".to_string())
            .parse()
            .expect("PORT must be a number");

        Config { port }
    }
}
