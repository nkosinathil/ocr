import io
import logging
from typing import Any, Dict, List

import pytesseract
from pdf2image import convert_from_bytes
from PIL import Image, ImageFilter

from app.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()
pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD


def preprocess_image(image: Image.Image) -> Image.Image:
    grayscale = image.convert("L")
    threshold = grayscale.point(lambda px: 255 if px > 180 else 0, "1")
    sharpened = threshold.filter(ImageFilter.SHARPEN)
    return sharpened


def process_image(image_bytes: bytes, language: str = "eng") -> Dict[str, Any]:
    image = Image.open(io.BytesIO(image_bytes))
    preprocessed = preprocess_image(image)

    data = pytesseract.image_to_data(preprocessed, lang=language, output_type=pytesseract.Output.DICT)

    confidences = [
        int(c) for c, text in zip(data["conf"], data["text"])
        if int(c) > 0 and text.strip()
    ]
    avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0

    text = pytesseract.image_to_string(preprocessed, lang=language).strip()
    word_count = len(text.split()) if text else 0

    logger.info(
        "Processed image: %d words, %.1f%% avg confidence",
        word_count,
        avg_confidence,
    )

    return {
        "text": text,
        "confidence": round(avg_confidence, 2),
        "word_count": word_count,
    }


def process_pdf(pdf_bytes: bytes, language: str = "eng") -> List[Dict[str, Any]]:
    try:
        images = convert_from_bytes(pdf_bytes, dpi=300)
    except Exception:
        logger.exception("Failed to convert PDF to images")
        raise

    results = []
    for page_num, page_image in enumerate(images, start=1):
        preprocessed = preprocess_image(page_image)

        data = pytesseract.image_to_data(
            preprocessed, lang=language, output_type=pytesseract.Output.DICT
        )
        confidences = [
            int(c) for c, text in zip(data["conf"], data["text"])
            if int(c) > 0 and text.strip()
        ]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0

        text = pytesseract.image_to_string(preprocessed, lang=language).strip()
        word_count = len(text.split()) if text else 0

        results.append({
            "page_number": page_num,
            "text": text,
            "confidence": round(avg_confidence, 2),
            "word_count": word_count,
        })

        logger.info(
            "Processed PDF page %d/%d: %d words, %.1f%% confidence",
            page_num,
            len(images),
            word_count,
            avg_confidence,
        )

    return results
