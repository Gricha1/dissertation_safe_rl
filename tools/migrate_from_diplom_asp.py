# -*- coding: utf-8 -*-
"""Convert diplom_asp/content/*.tex (extarticle sections) to Dissertation/part*.tex (memoir chapters)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASP_CONTENT = ROOT.parent / "diplom_asp" / "content"
DISS_DIR = ROOT / "Dissertation"

MAPPING = [
    ("part1.tex", "overview.tex"),
    ("part2.tex", "world_models.tex"),
    ("part3.tex", "hierarchical_safe_exploration.tex"),
    ("part4.tex", "multimodal_safety.tex"),
]


def convert_extarticle_to_memoir(text: str) -> str:
    text = text.replace("\\subsubsection{", "<<<SUBSECTION>>>")
    text = text.replace("\\subsection{", "\\section{")
    text, _ = re.subn(r"\\section\{", r"\\chapter{", text, count=1)
    return text.replace("<<<SUBSECTION>>>", "\\subsection{")


def main() -> None:
    for out_name, src_name in MAPPING:
        src = ASP_CONTENT / src_name
        if not src.exists():
            raise SystemExit(f"Missing source: {src}")
        body = convert_extarticle_to_memoir(src.read_text(encoding="utf-8"))
        header = (
            "% Auto-generated from diplom_asp/content/{} — do not edit by hand;\n"
            "% re-run tools/migrate_from_diplom_asp.py after changing source.\n"
        ).format(src_name)
        (DISS_DIR / out_name).write_text(header + body, encoding="utf-8")
        print(f"Wrote {DISS_DIR / out_name}")


if __name__ == "__main__":
    main()
