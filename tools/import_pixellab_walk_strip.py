#!/usr/bin/env python3
"""Build horizontal walk strip PNGs from PixelLab animation frame URLs."""
import sys
import urllib.request
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("pip install Pillow", file=sys.stderr)
    sys.exit(1)

PIXEL_TO_VIEW = {"south": "front", "north": "back", "east": "side_right"}
WALK_HFRAMES = 8


def download(url: str) -> Image.Image:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    from io import BytesIO
    return Image.open(BytesIO(data)).convert("RGBA")


def build_strip(base_url: str, out_path: Path, hframes: int = WALK_HFRAMES) -> None:
    # PixelLab v3: frame 0 is reference idle; use frames 1..hframes for walk loop
    frames: list[Image.Image] = []
    for i in range(1, hframes + 1):
        url = base_url.replace("{i}", str(i))
        frames.append(download(url))
    fw, fh = frames[0].size
    strip = Image.new("RGBA", (fw * len(frames), fh))
    for i, img in enumerate(frames):
        strip.paste(img, (i * fw, 0))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out_path)
    print(f"Saved {out_path} ({len(frames)} frames)")


def main() -> None:
    if len(sys.argv) < 4:
        print("Usage: import_pixellab_walk_strip.py <out_dir> <direction> <url_template>")
        print("  url_template example: https://.../south/{i}.png")
        sys.exit(1)
    out_dir = Path(sys.argv[1])
    direction = sys.argv[2]
    url_template = sys.argv[3]
    view = PIXEL_TO_VIEW.get(direction)
    if not view:
        sys.exit(f"Unknown direction: {direction}")
    build_strip(url_template, out_dir / f"{view}_walk.png")


if __name__ == "__main__":
    main()
