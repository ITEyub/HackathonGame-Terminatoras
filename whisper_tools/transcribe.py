#!/usr/bin/env python3
"""
Transcribes all audio files in ../sounds/ using Whisper and renames them
based on the spoken text. Run from whisper_tools/ or anywhere.
"""

import os
import re
import ssl
import sys

# Fix SSL certificate verification on macOS with python.org Python builds
import certifi
ssl._create_default_https_context = lambda: ssl.create_default_context(cafile=certifi.where())
os.environ.setdefault("SSL_CERT_FILE", certifi.where())
os.environ.setdefault("REQUESTS_CA_BUNDLE", certifi.where())

import static_ffmpeg
import whisper

SOUNDS_DIR = os.path.join(os.path.dirname(__file__), "..", "sounds")
AUDIO_EXTENSIONS = {".wav", ".mp3", ".ogg", ".flac", ".aac", ".m4a"}
MAX_NAME_LEN = 60  # chars for the spoken-text portion of the filename

# Subdirectory names (case-insensitive) to skip entirely
SKIP_DIRS = {"death screams", "frontend ui"}


def sanitize(text: str) -> str:
    text = text.strip().rstrip(".")
    text = re.sub(r'[\\/*?:"<>|]', "", text)
    text = re.sub(r"\s+", " ", text)
    return text[:MAX_NAME_LEN].strip()


def unique_path(directory: str, stem: str, ext: str) -> str:
    candidate = os.path.join(directory, stem + ext)
    if not os.path.exists(candidate):
        return candidate
    counter = 2
    while True:
        candidate = os.path.join(directory, f"{stem} ({counter}){ext}")
        if not os.path.exists(candidate):
            return candidate
        counter += 1


def collect_audio_files(root: str):
    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip excluded subdirectories in-place (prevents os.walk from descending)
        dirnames[:] = [
            d for d in dirnames if d.lower() not in SKIP_DIRS
        ]
        rel = os.path.relpath(dirpath, root)
        if any(part.lower() in SKIP_DIRS for part in rel.split(os.sep)):
            continue
        for filename in sorted(filenames):
            _, ext = os.path.splitext(filename)
            if ext.lower() in AUDIO_EXTENSIONS:
                files.append(os.path.join(dirpath, filename))
    return files


def main():
    # Make static ffmpeg available on PATH
    static_ffmpeg.add_paths()

    sounds_dir = os.path.realpath(SOUNDS_DIR)
    if not os.path.isdir(sounds_dir):
        print(f"ERROR: sounds directory not found: {sounds_dir}", file=sys.stderr)
        sys.exit(1)

    audio_files = collect_audio_files(sounds_dir)
    if not audio_files:
        print("No audio files found.")
        return

    print(f"Found {len(audio_files)} audio files. Loading Whisper model (base)...")
    model = whisper.load_model("base")
    print("Model loaded.\n")

    renamed = 0
    skipped = 0
    failed = 0

    for i, filepath in enumerate(audio_files, 1):
        directory = os.path.dirname(filepath)
        filename = os.path.basename(filepath)
        stem, ext = os.path.splitext(filename)

        print(f"[{i}/{len(audio_files)}] {filename}")

        try:
            result = model.transcribe(filepath, fp16=False)
            text = result.get("text", "").strip()
        except Exception as e:
            print(f"  ERROR transcribing: {e}")
            failed += 1
            continue

        if not text:
            print(f"  No speech detected — keeping original name")
            skipped += 1
            continue

        new_stem = sanitize(text)
        if not new_stem:
            print(f"  Empty text after sanitizing — keeping original name")
            skipped += 1
            continue

        new_path = unique_path(directory, new_stem, ext)
        os.rename(filepath, new_path)
        print(f'  → "{os.path.basename(new_path)}"')
        renamed += 1

    print(f"\nDone. Renamed: {renamed}, Kept original: {skipped}, Errors: {failed}")


if __name__ == "__main__":
    main()
