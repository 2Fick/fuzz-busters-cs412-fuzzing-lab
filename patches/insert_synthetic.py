#!/usr/bin/env python3
"""
Insert a tiny reversible synthetic heap overflow into pngread.c.
Usage: insert_synthetic.py path/to/pngread.c
"""
import sys
from pathlib import Path

if len(sys.argv) != 2:
    print("Usage: insert_synthetic.py path/to/pngread.c", file=sys.stderr)
    sys.exit(2)

p = Path(sys.argv[1])
if not p.exists():
    print(f"File not found: {p}", file=sys.stderr)
    sys.exit(1)

text = p.read_text()

needle = 'png_memcpy_check(png_ptr, png_ptr->prev_row, png_ptr->row_buf,'
if needle not in text:
    print("Anchor not found; aborting", file=sys.stderr)
    sys.exit(1)

# Find the end of the png_memcpy_check call (the line containing 'rowbytes + 1);')
end_marker = 'png_ptr->rowbytes + 1);'
pos = text.find(end_marker)
if pos == -1:
    print("End marker not found; aborting", file=sys.stderr)
    sys.exit(1)

# Insert after the end_marker line
insert_at = pos + len(end_marker)

injection = (
    "\n/* BEGIN synthetic fuzzing bug (container-only, easy to revert): */\n"
    "if (png_ptr->rowbytes > 0)\n"
    "{\n"
    "    /* Deliberate overflow past prev_row allocation for validation. */\n"
    "    png_ptr->prev_row[png_ptr->rowbytes + 128] = 0xAB;\n"
    "}\n"
    "/* END synthetic fuzzing bug */\n"
)

newtext = text[:insert_at] + injection + text[insert_at:]
backup = p.with_suffix('.c.bak')
backup.write_text(text)
p.write_text(newtext)
print(f"Injected synthetic bug into {p}; backup at {backup}")
