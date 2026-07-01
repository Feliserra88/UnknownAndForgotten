#!/usr/bin/env python3
"""Poll PixelLab MCP job status and download completed art into assets/world/."""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS_FILE = ROOT / "local" / "pixellab_jobs.json"

# job_id -> (mcp_get_tool, output_path)
# Filled by pixellab_queue_art.py after queueing.


def _download(url: str, dest: Path) -> None:
	dest.parent.mkdir(parents=True, exist_ok=True)
	print(f"download {url} -> {dest}")
	urllib.request.urlretrieve(url, dest)


def _poll_isometric(job_id: str, dest: Path) -> bool:
	# Requires MCP; this script documents paths. Use Cursor MCP get_isometric_tile in practice.
	return False


def main() -> int:
	if not JOBS_FILE.exists():
		print(f"No jobs file at {JOBS_FILE}")
		return 1
	jobs = json.loads(JOBS_FILE.read_text(encoding="utf-8"))
	print(f"Loaded {len(jobs)} jobs from {JOBS_FILE}")
	for entry in jobs:
		print(f"  {entry.get('kind')} {entry.get('id')} -> {entry.get('dest')}")
	print("Use MCP get_* tools in Cursor to download when status=completed.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
