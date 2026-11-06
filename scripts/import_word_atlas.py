#!/usr/bin/env python3
"""Import illustrations and example sentences from Word Atlas (词光) for words in our books.

Source: https://github.com/designfuchen/word-atlas
Content license: CC BY 4.0, attribution "Word Atlas contributors".

Usage:
    git clone --depth 1 https://github.com/designfuchen/word-atlas.git /tmp/word-atlas
    python3 scripts/import_word_atlas.py /tmp/word-atlas

Outputs (overwritten on every run):
    YiCiQianJin/Illustrations/<id>.webp   original 512px illustrations, copied unmodified
    YiCiQianJin/Data/atlas.json           {lowercased word: {"i": id, "e": [[en, zh], ...], "t": tip}}
"""
import glob
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "YiCiQianJin")
OUT_IMG = os.path.join(APP, "Illustrations")
OUT_JSON = os.path.join(APP, "Data", "atlas.json")


def main(src: str) -> None:
    entries = json.load(open(os.path.join(src, "data", "word-atlas.json"), encoding="utf-8"))
    img_dir = os.path.join(src, "public", "atlas", "img")

    by_word = {}
    for e in entries:
        by_word.setdefault(e["w"].strip().lower(), e)  # first entry wins for duplicate headwords

    wanted = set()
    for path in glob.glob(os.path.join(APP, "Data", "*.json")):
        if os.path.basename(path) == "atlas.json":
            continue
        for w in json.load(open(path, encoding="utf-8")):
            wanted.add(w["word"].strip().lower())

    out = {}
    missing_img = 0
    for word in sorted(wanted):
        e = by_word.get(word)
        if not e:
            continue
        img = os.path.join(img_dir, e["id"] + ".webp")
        has_img = os.path.exists(img)
        missing_img += not has_img
        item = {"e": [[x["en"], x["zh"]] for x in e.get("ex", []) if x.get("en")]}
        if has_img:
            item["i"] = e["id"]
        if e.get("tip"):
            item["t"] = e["tip"]
        out[word] = item

    if os.path.isdir(OUT_IMG):
        shutil.rmtree(OUT_IMG)
    os.makedirs(OUT_IMG)
    for item in out.values():
        if "i" in item:
            shutil.copyfile(os.path.join(img_dir, item["i"] + ".webp"), os.path.join(OUT_IMG, item["i"] + ".webp"))

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)

    images = sum("i" in v for v in out.values())
    size = sum(os.path.getsize(os.path.join(OUT_IMG, n)) for n in os.listdir(OUT_IMG))
    print(f"matched {len(out)} of {len(wanted)} book words; {images} illustrations "
          f"({size / 1e6:.0f} MB); {missing_img} matched words without an image")
    print(f"atlas.json {os.path.getsize(OUT_JSON) / 1e6:.1f} MB")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
