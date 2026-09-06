#!/usr/bin/env python3
import json
import shutil
import tempfile
import uuid
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
DOCS = ROOT / "Documents"
DATA_PATH = TOOLS / "konferencii_list.json"
TEMPLATE = TOOLS / "otzyv_template"
OUT = DOCS / "список конференций.docx"


def w(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def run_props(*, bold=False, italic=False, underline=False) -> str:
    parts = [
        '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>',
        '<w:sz w:val="28"/>',
        '<w:szCs w:val="28"/>',
    ]
    if bold:
        parts += ["<w:b/>", "<w:bCs/>"]
    if italic:
        parts += ["<w:i/>", "<w:iCs/>"]
    if underline:
        parts += ['<w:u w:val="single"/>']
    return "<w:rPr>" + "".join(parts) + "</w:rPr>"


def para_title(text: str) -> str:
    return (
        f'<w:p><w:pPr><w:jc w:val="center"/><w:spacing w:after="0" w:line="360" w:lineRule="auto"/>'
        f'</w:pPr><w:r>{run_props(bold=True)}<w:t xml:space="preserve">{w(text)}</w:t></w:r></w:p>'
    )


def para_simple(num: int, text: str) -> str:
    return (
        f'<w:p><w:pPr><w:jc w:val="both"/><w:spacing w:after="0" w:line="360" w:lineRule="auto"/>'
        f'<w:ind w:firstLine="709"/></w:pPr>'
        f'<w:r>{run_props()}<w:t xml:space="preserve">{w(f"{num}. {text}")}</w:t></w:r></w:p>'
    )


def para_conf(num: int, prefix: str, talk: str, *, poster: bool = False) -> str:
    intro = " с постерным докладом «" if poster else " с докладом «"
    return (
        f'<w:p><w:pPr><w:jc w:val="both"/><w:spacing w:after="0" w:line="360" w:lineRule="auto"/>'
        f'<w:ind w:firstLine="709"/></w:pPr>'
        f'<w:r>{run_props()}<w:t xml:space="preserve">{w(f"{num}. {prefix}{intro}")}</w:t></w:r>'
        f'<w:r>{run_props(underline=True)}<w:t xml:space="preserve">{w(talk)}</w:t></w:r>'
        f'<w:r>{run_props()}<w:t xml:space="preserve">».</w:t></w:r></w:p>'
    )


def para_sub(text: str) -> str:
    return (
        f'<w:p><w:pPr><w:jc w:val="both"/><w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/>'
        f'<w:ind w:firstLine="709"/></w:pPr>'
        f'<w:r>{run_props(italic=True)}<w:t xml:space="preserve">{w(text)}</w:t></w:r></w:p>'
    )


def main() -> None:
    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    body = [
        para_title(data["title"]),
        '<w:p><w:pPr><w:spacing w:after="0" w:line="360" w:lineRule="auto"/></w:pPr></w:p>',
    ]
    num = 1
    for entry in data["entries"]:
        if entry.get("simple"):
            body.append(para_simple(num, entry["text"]))
        else:
            body.append(para_conf(num, entry["prefix"], entry["talk"], poster=entry.get("poster", False)))
        num += 1

    document_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n'
        "  <w:body>\n"
        + "\n".join(body)
        + '\n    <w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        + '<w:pgMar w:top="1134" w:right="850" w:bottom="1134" w:left="1701" '
        + 'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>\n'
        "  </w:body>\n"
        "</w:document>\n"
    )
    core_xml = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        f"<dc:title>{w(data['title'])}</dc:title></cp:coreProperties>\n"
    )

    for path in DOCS.glob("*.docx"):
        if "konferenc" in path.name.lower() or path.name.startswith("\ufffd"):
            path.unlink(missing_ok=True)

    work = Path(tempfile.gettempdir()) / f"konf_{uuid.uuid4()}"
    shutil.copytree(TEMPLATE, work)
    (work / "word" / "document.xml").write_text(document_xml, encoding="utf-8")
    (work / "docProps" / "core.xml").write_text(core_xml, encoding="utf-8")
    OUT.unlink(missing_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in work.rglob("*"):
            if file_path.is_file():
                zf.write(file_path, file_path.relative_to(work).as_posix())
    shutil.rmtree(work)
    print(OUT)
    print(f"size: {OUT.stat().st_size}")


if __name__ == "__main__":
    main()
