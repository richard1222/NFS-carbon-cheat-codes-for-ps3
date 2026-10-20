"""Assert carbon_mem.ps1's code table still matches the codelist exactly.

Why this exists: the tool writes to memory. If its table drifts from the
codelist -- someone edits one and not the other -- the tool will confidently
write the WRONG VALUE to an address, and nothing in the tool would notice.

This has already happened once on the Yakuza set (a hand-reordered .ncl
silently dropped two lines). So the check is automated, not eyeballed.

It parses both:
  codelists/Need For Speed Carbon BLUS30016 01.00.ncl   (the source of truth)
  tools/carbon_mem.ps1                                  (the table in the tool)
and fails if any address/value pair differs, or if counts differ.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
NCL = ROOT / "codelists" / "Need For Speed Carbon BLUS30016 01.00.ncl"
PS1 = HERE / "carbon_mem.ps1"

# "0 0013CDEC 91630058"  -- an Artemis code line
CODE_RE = re.compile(r"^0\s+([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]{8})\s*$", re.M)

# inside the ps1:  @{ Addr = "005015B4"; Value = "60000000" }
PAIR_RE = re.compile(r'Addr\s*=\s*"([0-9A-Fa-f]{8})"\s*;\s*Value\s*=\s*"([0-9A-Fa-f]{8})"')

# code names in the ps1 table:  Name  = "ASM ..."
NAME_RE = re.compile(r'Name\s*=\s*"([^"]+)"')

# code names in the ncl are "#" section headers. The real structure is:
#
#     #
#     ASM Infinite Bullet Time      <- the name
#     0                              <- code type
#     jgduff1                        <- author
#     0 005015B4 60000000            <- code lines
#
# Comment blocks look identical at the '#' but are followed by more '#' lines
# or prose. Rather than guess with a regex, walk the file line by line.


def parse_ncl(text: str) -> tuple[list[tuple[str, str]], list[str]]:
    """Return ([(addr, value), ...], [name, ...]) from the codelist."""
    pairs = [(m.group(1).upper(), m.group(2).upper()) for m in CODE_RE.finditer(text)]

    lines = text.splitlines()
    names: list[str] = []
    i = 0
    while i < len(lines):
        # a section header is a line that is exactly '#'
        if lines[i].strip() == "#" and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            # a real header: the next line is NOT blank, NOT another '#',
            # and the line after that is the code type '0'
            if nxt and not nxt.startswith("#") and i + 2 < len(lines) and lines[i + 2].strip() == "0":
                names.append(nxt)
        i += 1
    return pairs, names


def parse_ps1(text: str) -> tuple[list[tuple[str, str]], list[str]]:
    pairs = [(m.group(1).upper(), m.group(2).upper()) for m in PAIR_RE.finditer(text)]
    names = [n.strip() for n in NAME_RE.findall(text)]
    return pairs, names


def main() -> int:
    for p in (NCL, PS1):
        if not p.exists():
            print(f"  MISSING: {p}")
            return 2

    ncl_pairs, ncl_names = parse_ncl(NCL.read_text(encoding="utf-8"))
    ps1_pairs, ps1_names = parse_ps1(PS1.read_text(encoding="utf-8"))

    print(f"  codelist : {len(ncl_pairs)} code line(s), {len(ncl_names)} code name(s)")
    print(f"  tool     : {len(ps1_pairs)} table entry(ies), {len(ps1_names)} code name(s)")
    print()

    fails = 0

    # ---- addresses and values ------------------------------------------------
    if len(ncl_pairs) != len(ps1_pairs):
        print(f"  FAIL: count differs -- codelist {len(ncl_pairs)}, tool {len(ps1_pairs)}")
        fails += 1
    for i, (a, b) in enumerate(zip(ncl_pairs, ps1_pairs)):
        if a != b:
            print(f"  FAIL: entry {i}: codelist {a[0]}={a[1]}  tool {b[0]}={b[1]}")
            fails += 1

    # ---- names ---------------------------------------------------------------
    if len(ncl_names) != len(ps1_names):
        print(f"  FAIL: name count differs -- codelist {len(ncl_names)}, tool {len(ps1_names)}")
        print(f"        codelist names: {ncl_names}")
        print(f"        tool names    : {ps1_names}")
        fails += 1
    else:
        for a, b in zip(ncl_names, ps1_names):
            if a != b:
                print(f"  FAIL: name: codelist {a!r}  tool {b!r}")
                fails += 1

    # ---- every tool address must be exactly 8 hex chars ---------------------
    for a, _ in ps1_pairs:
        if len(a) != 8:
            print(f"  FAIL: address {a} is not 8 hex chars")
            fails += 1

    print()
    if fails:
        print(f"  {fails} problem(s) -- tool CANNOT be trusted as-is")
        return 1

    print(f"  PASS: {len(ncl_pairs)}/{len(ncl_pairs)} identical -- tool cannot drift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
