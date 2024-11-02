use std::fs;

fn main() {
    fs::create_dir_all("target/descriptor").unwrap();

    tonic_build::configure()
        .file_descriptor_set_path("target/descriptor/compose.bin")
        .compile_protos(&["proto/compose.proto"], &["proto"])
        .unwrap();
}
