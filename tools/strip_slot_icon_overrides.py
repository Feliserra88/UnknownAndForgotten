#!/usr/bin/env python3
"""Remove persisted Icon / TextureRect overrides under item and equipment slots in .tscn files."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = list(ROOT.glob("ui/**/*.tscn"))
SLOT_PARENT_MARKERS = ("/UfEquipment", "/LootGrid/Slot_", "/Slot_")


def should_strip(node_line: str) -> bool:
	if not node_line.startswith("[node name="):
		return False
	if "parent=" not in node_line:
		return False
	parent = node_line.split("parent=", 1)[1]
	if not any(marker in parent for marker in SLOT_PARENT_MARKERS):
		return False
	header = node_line.split("]", 1)[0]
	if 'type="TextureRect"' in node_line:
		return True
	if header.startswith('[node name="Icon"'):
		return True
	if header.startswith('[node name="@TextureRect'):
		return True
	if "_TextureRect_" in header:
		return True
	return False


def clean_file(path: Path) -> int:
	text = path.read_text(encoding="utf-8")
	lines = text.splitlines()
	out: list[str] = []
	i = 0
	removed = 0
	while i < len(lines):
		line = lines[i]
		if should_strip(line):
			removed += 1
			i += 1
			while i < len(lines) and not lines[i].startswith("[node name=") and not lines[i].startswith(
				"[ext_resource"
			):
				i += 1
			continue
		out.append(line)
		i += 1
	if removed:
		path.write_text("\n".join(out) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")
	return removed


def main() -> None:
	total = 0
	for path in FILES:
		count = clean_file(path)
		if count:
			print(f"{path.relative_to(ROOT)}: removed {count} ghost TextureRect blocks")
			total += count
	print(f"Done. Removed {total} blocks across {len(FILES)} files scanned.")


if __name__ == "__main__":
	main()
