#!/usr/bin/env python3
"""Patch GNU libiconv 1.18's POSIX-only getdtablesize fallback for WASI.

Source archive integrity is checked by build-libiconv before this patch.
"""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-libiconv-wasi.py SOURCE_DIRECTORY")

source = Path(sys.argv[1])
candidates = [source / "srclib/getdtablesize.c", source / "lib/getdtablesize.c"]
existing = [path for path in candidates if path.is_file()]
if not existing:
    raise SystemExit("GNU libiconv getdtablesize.c not found; upstream layout changed")

for path in existing:
    text = path.read_text()
    old_header = "# include <sys/resource.h>"
    new_header = "# ifndef __wasi__\n#  include <sys/resource.h>\n# endif"
    old_func = "getdtablesize (void)\n{\n  struct rlimit lim;"
    new_func = "getdtablesize (void)\n{\n# ifdef __wasi__\n  return INT_MAX;\n# else\n  struct rlimit lim;"
    old_tail = "  return INT_MAX;\n}"
    new_tail = "  return INT_MAX;\n# endif\n}"
    if all(mark in text for mark in [new_header, new_func, new_tail]):
        print(f"Already patched: {path}", file=sys.stderr)
        continue
    for mark in [old_header, old_func, old_tail]:
        if text.count(mark) != 1:
            raise SystemExit(f"Unexpected Gnulib source in {path}; refusing blind patch")
    path.write_text(text.replace(old_header, new_header)
                   .replace(old_func, new_func)
                   .replace(old_tail, new_tail))
    print(f"Applied WASI getdtablesize fallback: {path}", file=sys.stderr)
