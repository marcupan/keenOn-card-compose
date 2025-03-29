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

    let words: Vec<&str> = text.split_whitespace().collect();

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

pub fn compose_image_with_text(image_base64: &str, text: &str) -> Result<Vec<u8>, Box<dyn Error>> {
    let image_data = STANDARD
        .decode(image_base64)
        .map_err(|e| format!("Failed to decode base64: {}", e))?;

    let img =
        image::load_from_memory(&image_data).map_err(|e| format!("Failed to load image: {}", e))?;

    let mut composed_image =
        RgbaImage::from_pixel(CARD_WIDTH, CARD_HEIGHT, Rgba([255, 255, 255, 255]));

    let overlay_x = (CARD_WIDTH as i32 / 2) - (img.width() as i32 / 2);
    image::imageops::overlay(
        &mut composed_image,
        &img.to_rgba8(),
        overlay_x as i64,
        24,
    );

    let font_data = include_bytes!("../assets/DejaVuSans.ttf");
    let font = FontArc::try_from_slice(font_data)?;

    let scale = PxScale { x: 20.0, y: 20.0 };

    draw_centered_text(
        &mut composed_image,
        Rgba([0, 0, 0, 255]),
        (CARD_WIDTH / 2) as i32,
        (CARD_HEIGHT / 2 + 24) as i32,
        scale,
        &font,
        text,
    );

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

#[cfg(test)]
mod tests {
    use super::*;
    use ab_glyph::FontArc;
    use image::{Rgba, RgbaImage};

    #[test]
    fn test_measure_text_width() {
        let font_data = include_bytes!("../assets/DejaVuSans.ttf");
        let font = FontArc::try_from_slice(font_data).expect("Failed to load font");
        let scale = PxScale::from(20.0);

        let text = "Test";
        let width = measure_text_width(&font, text, scale);

        assert!(width > 0.0);
    }

    #[test]
    fn test_draw_centered_text() {
        let font_data = include_bytes!("../assets/DejaVuSans.ttf");
        let font = FontArc::try_from_slice(font_data).expect("Failed to load font");
        let scale = PxScale::from(20.0);

        let mut image = RgbaImage::new(CARD_WIDTH, CARD_HEIGHT);
        let color = Rgba([0, 0, 0, 255]);
        let text = "Centered Text";

        draw_centered_text(
            &mut image,
            color,
            (CARD_WIDTH / 2) as i32,
            (CARD_HEIGHT / 2) as i32,
            scale,
            &font,
            text,
        );

        let white = Rgba([255, 255, 255, 255]);
        let text_drawn = image.pixels().any(|&pixel| pixel != white);
        assert!(text_drawn);
    }

    #[test]
    fn test_compose_image_with_text() {
        let base64_image = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAApgAAAKYB3X3/OAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAANCSURBVEiJtZZPbBtFFMZ/M7ubXdtdb1xSFyeilBapySVU8h8OoFaooFSqiihIVIpQBKci6KEg9Q6H9kovIHoCIVQJJCKE1ENFjnAgcaSGC6rEnxBwA04Tx43t2FnvDAfjkNibxgHxnWb2e/u992bee7tCa00YFsffekFY+nUzFtjW0LrvjRXrCDIAaPLlW0nHL0SsZtVoaF98mLrx3pdhOqLtYPHChahZcYYO7KvPFxvRl5XPp1sN3adWiD1ZAqD6XYK1b/dvE5IWryTt2udLFedwc1+9kLp+vbbpoDh+6TklxBeAi9TL0taeWpdmZzQDry0AcO+jQ12RyohqqoYoo8RDwJrU+qXkjWtfi8Xxt58BdQuwQs9qC/afLwCw8tnQbqYAPsgxE1S6F3EAIXux2oQFKm0ihMsOF71dHYx+f3NND68ghCu1YIoePPQN1pGRABkJ6Bus96CutRZMydTl+TvuiRW1m3n0eDl0vRPcEysqdXn+jsQPsrHMquGeXEaY4Yk4wxWcY5V/9scqOMOVUFthatyTy8QyqwZ+kDURKoMWxNKr2EeqVKcTNOajqKoBgOE28U4tdQl5p5bwCw7BWquaZSzAPlwjlithJtp3pTImSqQRrb2Z8PHGigD4RZuNX6JYj6wj7O4TFLbCO/Mn/m8R+h6rYSUb3ekokRY6f/YukArN979jcW+V/S8g0eT/N3VN3kTqWbQ428m9/8k0P/1aIhF36PccEl6EhOcAUCrXKZXXWS3XKd2vc/TRBG9O5ELC17MmWubD2nKhUKZa26Ba2+D3P+4/MNCFwg59oWVeYhkzgN/JDR8deKBoD7Y+ljEjGZ0sosXVTvbc6RHirr2reNy1OXd6pJsQ+gqjk8VWFYmHrwBzW/n+uMPFiRwHB2I7ih8ciHFxIkd/3Omk5tCDV1t+2nNu5sxxpDFNx+huNhVT3/zMDz8usXC3ddaHBj1GHj/As08fwTS7Kt1HBTmyN29vdwAw+/wbwLVOJ3uAD1wi/dUH7Qei66PfyuRj4Ik9is+hglfbkbfR3cnZm7chlUWLdwmprtCohX4HUtlOcQjLYCu+fzGJH2QRKvP3UNz8bWk1qMxjGTOMThZ3kvgLI5AzFfo379UAAAAASUVORK5CYII=";
        let text = "Sample Text";

        let result = compose_image_with_text(base64_image, text);

        if let Err(ref e) = result {
            eprintln!("Error composing image: {:?}", e);
        }

        assert!(result.is_ok());
        let image_data = result.unwrap();

        assert!(!image_data.is_empty(), "Image data should not be empty");
    }
}
