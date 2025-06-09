use ab_glyph::{Font, FontArc, PxScale, ScaleFont};
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use image::codecs::png::PngEncoder;
use image::imageops::FilterType;
use image::{ImageBuffer, ImageEncoder, Rgba, RgbaImage};
use imageproc::drawing::draw_text_mut;
use log::{info, warn};
use std::error::Error;
use std::io::Cursor;

const CARD_HEIGHT: u32 = 480;
const CARD_WIDTH: u32 = 280;
const HORIZONTAL_PADDING: u32 = 20;
const VERTICAL_PADDING: u32 = 15;
const IMAGE_BOTTOM_MARGIN: u32 = 10;

#[allow(dead_code)]
struct TextMetrics {
    lines: Vec<String>,
    line_height: f32,
    total_height: f32,
}

fn calculate_and_draw_centered_text(
    image: &mut ImageBuffer<Rgba<u8>, Vec<u8>>,
    color: Rgba<u8>,
    center_x: i32,
    start_y: i32,
    scale: PxScale,
    font: &FontArc,
    text: &str,
) -> Result<TextMetrics, Box<dyn Error>> {
    let max_width = CARD_WIDTH - 2 * HORIZONTAL_PADDING;
    let scaled_font = font.as_scaled(scale);
    let line_height_factor = 1.3;
    let line_height = scale.y * line_height_factor;

    let mut lines = Vec::new();
    let mut current_line = String::new();
    let _space_width = scaled_font.h_advance(scaled_font.glyph_id(' '));

    for word in text.split_whitespace() {
        let word_width: f32 = word
            .chars()
            .map(|c| scaled_font.h_advance(scaled_font.glyph_id(c)))
            .sum();

        let test_line = if current_line.is_empty() {
            word.to_string()
        } else {
            format!("{} {}", current_line, word)
        };

        let test_line_width: f32 = test_line
            .chars()
            .map(|c| scaled_font.h_advance(scaled_font.glyph_id(c)))
            .sum();

        if test_line_width <= max_width as f32 {
            current_line = test_line;
        } else {
            if word_width > max_width as f32 && current_line.is_empty() {
                lines.push(word.to_string());
                current_line.clear();
            } else {
                if !current_line.is_empty() {
                    lines.push(current_line);
                }
                current_line = word.to_string();
            }
        }
    }
    if !current_line.is_empty() {
        lines.push(current_line);
    }

    let total_text_height = lines.len() as f32 * line_height;
    let mut current_draw_y = start_y;

    for line in &lines {
        let line_width: f32 = line
            .chars()
            .map(|c| scaled_font.h_advance(scaled_font.glyph_id(c)))
            .sum();
        let line_x = center_x as f32 - line_width / 2.0;

        draw_text_mut(
            image,
            color,
            line_x as i32,
            current_draw_y,
            scale,
            font,
            line,
        );
        current_draw_y += line_height as i32;
    }

    Ok(TextMetrics {
        lines,
        line_height,
        total_height: total_text_height,
    })
}

pub fn compose_image_with_details(
    image_base64: &str,
    translation: &str,
    individual_translations: &[String],
    example_sentences: &[String],
) -> Result<Vec<u8>, Box<dyn Error>> {
    info!("Decoding base64 image...");

    let image_data = STANDARD
        .decode(image_base64)
        .map_err(|e| format!("Failed to decode base64: {}", e))?;
    let img = image::load_from_memory(&image_data)?;

    info!(
        "Loaded image with dimensions: {}x{}",
        img.width(),
        img.height()
    );

    let top_half_height_available = CARD_HEIGHT / 2 - IMAGE_BOTTOM_MARGIN;
    let original_width = img.width();
    let original_height = img.height();
    let aspect_ratio = original_width as f32 / original_height as f32;

    let mut scaled_height = top_half_height_available;
    let mut scaled_width = (scaled_height as f32 * aspect_ratio).round() as u32;

    if scaled_width > CARD_WIDTH {
        scaled_width = CARD_WIDTH;
        scaled_height = (scaled_width as f32 / aspect_ratio).round() as u32;
    }

    info!(
        "Scaling image to fit top half: {}x{}",
        scaled_width, scaled_height
    );

    let mut composed_image =
        RgbaImage::from_pixel(CARD_WIDTH, CARD_HEIGHT, Rgba([255, 255, 255, 255]));

    let image_x = (CARD_WIDTH.saturating_sub(scaled_width) / 2) as i64;
    let image_y: i64 = 0;

    let scaled_image = img.resize_exact(scaled_width, scaled_height, FilterType::Lanczos3);
    info!("Overlaying image at ({}, {})", image_x, image_y);
    image::imageops::overlay(
        &mut composed_image,
        &scaled_image.to_rgba8(),
        image_x,
        image_y,
    );

    info!("Loading font...");

    let font_data = include_bytes!("../assets/NotoSansCJKsc-Regular.otf");
    let font = FontArc::try_from_slice(font_data)?;

    let scale_translation = PxScale { x: 28.0, y: 28.0 };
    let scale_breakdown = PxScale { x: 18.0, y: 18.0 };
    let scale_examples = PxScale { x: 20.0, y: 20.0 };

    let text_color = Rgba([0, 0, 0, 255]);
    let center_x = (CARD_WIDTH / 2) as i32;

    let mut current_y = scaled_height as i32 + IMAGE_BOTTOM_MARGIN as i32 + VERTICAL_PADDING as i32;

    if !translation.is_empty() {
        info!("Drawing translation: '{}'", translation);

        match calculate_and_draw_centered_text(
            &mut composed_image,
            text_color,
            center_x,
            current_y,
            scale_translation,
            &font,
            translation,
        ) {
            Ok(metrics) => {
                current_y += metrics.total_height.round() as i32 + VERTICAL_PADDING as i32;
            }
            Err(err) => warn!("Could not draw translation: {}", err),
        }
    } else {
        info!("No translation text provided.");
    }

    if !individual_translations.is_empty() {
        info!("Drawing individual translations (breakdown)...");

        for breakdown in individual_translations {
            if current_y >= CARD_HEIGHT as i32 - (scale_breakdown.y * 1.5) as i32 {
                warn!("Stopping breakdown drawing - not enough space");

                break;
            }
            match calculate_and_draw_centered_text(
                &mut composed_image,
                text_color,
                center_x,
                current_y,
                scale_breakdown,
                &font,
                breakdown,
            ) {
                Ok(metrics) => {
                    current_y +=
                        metrics.total_height.round() as i32 + (VERTICAL_PADDING / 2) as i32;
                }
                Err(err) => warn!("Could not draw breakdown item '{}': {}", breakdown, err),
            }
        }
        current_y += (VERTICAL_PADDING / 2) as i32;
    } else {
        info!("No individual translations provided.");
    }

    if !example_sentences.is_empty() {
        info!("Drawing example sentences...");

        for sentence in example_sentences {
            if current_y >= CARD_HEIGHT as i32 - (scale_examples.y * 1.5) as i32 {
                warn!("Stopping example sentence drawing - not enough space");

                break;
            }
            match calculate_and_draw_centered_text(
                &mut composed_image,
                text_color,
                center_x,
                current_y,
                scale_examples,
                &font,
                sentence,
            ) {
                Ok(metrics) => {
                    current_y += metrics.total_height.round() as i32 + VERTICAL_PADDING as i32;
                }
                Err(err) => warn!("Could not draw example sentence '{}': {}", sentence, err),
            }
        }
    } else {
        info!("No example sentences provided.");
    }

    info!("Encoding final image to PNG...");

    let mut result = Vec::new();
    let mut cursor = Cursor::new(&mut result);

    PngEncoder::new(&mut cursor).write_image(
        &composed_image,
        composed_image.width(),
        composed_image.height(),
        image::ColorType::Rgba8.into(),
    )?;

    info!("Image composition complete.");

    Ok(result)
}
