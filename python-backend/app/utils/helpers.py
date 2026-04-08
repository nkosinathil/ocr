import os
import uuid


def generate_stored_filename(original: str) -> str:
    ext = get_file_extension(original)
    unique_name = str(uuid.uuid4())
    return f"{unique_name}{ext}" if ext else unique_name


def get_file_extension(filename: str) -> str:
    _, ext = os.path.splitext(filename)
    return ext.lower()


def detect_upload_type(mime_type: str) -> str:
    if mime_type == "application/pdf":
        return "pdf"
    return "image"


def format_file_size(size_bytes: int) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"
