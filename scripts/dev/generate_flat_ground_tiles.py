#!/usr/bin/env python3
"""Procedural flat isometric ground tiles (top face only, transparent outside diamond)."""
from __future__ import annotations

import random
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "world" / "tiles" / "art"
SIZE = 64


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, pixels: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)
        for x in range(SIZE):
            raw.extend(pixels[y * SIZE + x])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", compressed) + _png_chunk(b"IEND", b"")
    path.write_bytes(png)


def in_diamond(x: int, y: int) -> float:
    hw, hh = SIZE / 2.0, SIZE / 2.0
    nx = abs(x + 0.5 - hw) / hw
    ny = abs(y + 0.5 - hh) / hh
    d = nx + ny
    if d > 1.0:
        return -1.0
    return 1.0 - d


def make_tile(base: tuple[int, int, int], jitter: int, seed: int) -> list[tuple[int, int, int, int]]:
    rng = random.Random(seed)
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(SIZE):
        for x in range(SIZE):
            edge = in_diamond(x, y)
            if edge < 0:
                pixels.append((0, 0, 0, 0))
                continue
            shade = 1.0 - edge * 0.18
            n = rng.randint(-jitter, jitter)
            r = max(0, min(255, int((base[0] + n) * shade)))
            g = max(0, min(255, int((base[1] + n) * shade)))
            b = max(0, min(255, int((base[2] + n) * shade)))
            pixels.append((r, g, b, 255))
    return pixels


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    specs = {
        "grass.png": ((115, 184, 92), 12, 42001),
        "dirt.png": ((140, 102, 68), 10, 42002),
        "dirt_path.png": ((158, 120, 78), 8, 42003),
        "pond_water.png": ((69, 125, 196), 6, 42004),
    }
    for name, (rgb, jitter, seed) in specs.items():
        write_png(OUT / name, make_tile(rgb, jitter, seed))
        print(f"wrote {OUT / name}")


if __name__ == "__main__":
    main()
