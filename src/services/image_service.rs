use ab_glyph::{Font, FontArc, PxScale, ScaleFont};
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use image::codecs::png::PngEncoder;
use image::ImageEncoder;
use image::{ImageBuffer, Rgba, RgbaImage};
use imageproc::drawing::draw_text_mut;
use std::error::Error;
use std::io::Cursor;

const CARD_HEIGHT: u32 = 480;
const CARD_WIDTH: u32 = 280;
const HORIZONTAL_PADDING: u32 = 20;
const TEXT_START_Y: u32 = CARD_HEIGHT / 2 + 24;

fn measure_text_width(font: &FontArc, text: &str, scale: PxScale) -> f32 {
    let scaled_font = font.as_scaled(scale);
    text.chars()
        .map(|c| scaled_font.h_advance(scaled_font.glyph_id(c)))
        .sum()
}

fn draw_centered_text(
    image: &mut ImageBuffer<Rgba<u8>, Vec<u8>>,
    color: Rgba<u8>,
    x: i32,
    y: i32,
    scale: PxScale,
    font: &FontArc,
    text: &str,
) {
    let max_width = CARD_WIDTH - 2 * HORIZONTAL_PADDING;
    let words = text.split_whitespace().collect::<Vec<&str>>();
    let mut lines = Vec::new();
    let mut current_line = String::new();

    for word in words {
        let test_line = if current_line.is_empty() {
            word.to_string()
        } else {
            format!("{} {}", current_line, word)
        };
        let width = measure_text_width(font, &test_line, scale);
        if width > max_width as f32 {
            lines.push(current_line);
            current_line = word.to_string();
        } else {
            current_line = test_line;
        }
    }
    if !current_line.is_empty() {
        lines.push(current_line);
    }
    let line_height = scale.y * 1.2;
    let total_text_height = lines.len() as f32 * line_height;
    let start_y = y as f32 - total_text_height / 2.0;
    for (i, line) in lines.iter().enumerate() {
        let width = measure_text_width(font, &line, scale);
        let line_x = x as f32 - width / 2.0;
        let line_y = start_y + i as f32 * line_height;
        draw_text_mut(
            image,
            color,
            line_x as i32,
            line_y as i32,
            scale,
            font,
            line,
        );
    }
}

pub fn compose_image_with_text(
    image_base64: &str,
    text: &str,
    sentences: &[String],
) -> Result<Vec<u8>, Box<dyn Error>> {
    let image_data = STANDARD
        .decode(image_base64)
        .map_err(|e| format!("Failed to decode base64: {}", e))?;
    let img = image::load_from_memory(&image_data)?;

    let top_half_height = CARD_HEIGHT / 2;
    let original_width = img.width();
    let original_height = img.height();
    let aspect_ratio = original_width as f32 / original_height as f32;

    let scaled_width = (top_half_height as f32 * aspect_ratio) as u32;

    let final_width = std::cmp::min(scaled_width, CARD_WIDTH);
    let final_height = (final_width as f32 / aspect_ratio) as u32;

    let mut composed_image =
        RgbaImage::from_pixel(CARD_WIDTH, CARD_HEIGHT, Rgba([255, 255, 255, 255]));

    let image_x = (CARD_WIDTH / 2) as i32 - (final_width / 2) as i32;
    let image_y = 0;

    let scaled_image = img.resize(
        final_width,
        final_height,
        image::imageops::FilterType::Lanczos3,
    );
    image::imageops::overlay(
        &mut composed_image,
        &scaled_image.to_rgba8(),
        image_x as i64,
        image_y as i64,
    );

    let font_data = include_bytes!("../assets/NotoSansCJKsc-Regular.otf");
    let font = FontArc::try_from_slice(font_data)?;
    let scale = PxScale { x: 20.0, y: 20.0 };

    let mut current_y = TEXT_START_Y as i32;
    draw_centered_text(
        &mut composed_image,
        Rgba([0, 0, 0, 255]),
        (CARD_WIDTH / 2) as i32,
        current_y,
        scale,
        &font,
        text,
    );
    current_y += (scale.y * 1.5) as i32;

    for sentence in sentences {
        draw_centered_text(
            &mut composed_image,
            Rgba([0, 0, 0, 255]),
            (CARD_WIDTH / 2) as i32,
            current_y,
            scale,
            &font,
            sentence,
        );
        current_y += (scale.y * 1.5) as i32;

        if current_y > CARD_HEIGHT as i32 {
            break;
        }
    }

    let mut result = Vec::new();
    let mut cursor = Cursor::new(&mut result);
    PngEncoder::new(&mut cursor).write_image(
        &composed_image,
        composed_image.width(),
        composed_image.height(),
        image::ColorType::Rgba8.into(),
    )?;
    Ok(result)
}
