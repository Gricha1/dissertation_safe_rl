import xml.etree.ElementTree as ET
import json

NS = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
path = r"c:\Grisha\mipt\asp\disser\dissertation\diplom_final\tools\_avtoreferat_tit\word\document.xml"
root = ET.parse(path).getroot()
body = root.find(NS + "body")


def g(el, tag, attr="val"):
    if el is None:
        return None
    c = el.find(NS + tag)
    return None if c is None else c.get(NS + attr)


def para_info(p, idx):
    pPr = p.find(NS + "pPr")
    texts = []
    run_details = []
    has_tab = False
    for r in p.findall(NS + "r"):
        if r.find(NS + "tab") is not None:
            has_tab = True
        t = "".join((x.text or "") for x in r.findall(NS + "t"))
        if not t:
            continue
        rPr = r.find(NS + "rPr")
        run_details.append(
            {
                "t": t,
                "b": g(rPr, "b"),
                "i": g(rPr, "i"),
                "sz": g(rPr, "sz"),
            }
        )
        texts.append(t)
    text = "".join(texts).strip()
    if not text:
        return None
    p_rPr = pPr.find(NS + "rPr") if pPr is not None else None
    return {
        "i": idx,
        "text": text,
        "jc": g(pPr, "jc"),
        "before": g(pPr, "spacing", "before"),
        "after": g(pPr, "spacing", "after"),
        "line": g(pPr, "spacing", "line"),
        "left": g(pPr, "ind", "left"),
        "first": g(pPr, "ind", "firstLine"),
        "hanging": g(pPr, "ind", "hanging"),
        "p_b": g(p_rPr, "b"),
        "p_sz": g(p_rPr, "sz"),
        "has_tab": has_tab,
        "runs": run_details,
    }


paras = []
for i, p in enumerate(body.findall(NS + "p")):
    info = para_info(p, i)
    if info:
        paras.append(info)

out_path = r"c:\Grisha\mipt\asp\disser\dissertation\diplom_final\tools\_avtoreferat_tit\paras_full.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(paras, f, ensure_ascii=False, indent=2)

print("paras", len(paras))
for x in paras:
    print(
        f"P{x['i']:02d} jc={x['jc']} L={x['left']} F={x['first']} H={x['hanging']} "
        f"bef={x['before']} aft={x['after']} line={x['line']} tab={x['has_tab']} p_sz={x['p_sz']}"
    )
    print("  ", x["text"][:120])
    for r in x["runs"]:
        print(f"    {r['t']!r} b={r['b']} i={r['i']} sz={r['sz']}")
