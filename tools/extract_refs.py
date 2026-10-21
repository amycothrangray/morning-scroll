"""Find the verses each answer and quiz explanation cites, as full references the Bible APIs understand.

Handles "Matthew 1:3", bare "38:26" (book carried over), "v. 26" / "vv. 14-15" (chapter carried over),
and "Romans 8:1, 33-34" lists. Whole chapters and long ranges are skipped; they aren't worth quoting.
Run after editing study.json:  python3 tools/extract_refs.py
"""
import json, re, sys

BOOKS = ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
         "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah",
         "Esther", "Job", "Psalms", "Psalm", "Proverbs", "Ecclesiastes", "Isaiah", "Jeremiah", "Lamentations",
         "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Micah", "Habakkuk", "Zechariah", "Malachi",
         "Matthew", "Mark", "Luke", "John", "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
         "Ephesians", "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy",
         "2 Timothy", "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John",
         "3 John", "Jude", "Revelation"]
SINGLE = {"Philemon", "2 John", "3 John", "Jude", "Obadiah"}
MAX_VERSES = 6

book_re = "|".join(sorted((re.escape(b) for b in BOOKS), key=len, reverse=True))
TOKEN = re.compile(
    rf"(?P<book>{book_re})\s+(?P<c>\d+)(?::(?P<v>\d+)(?:[-–](?P<v2>\d+))?)?"   # Book 1:2-3 / Book 12
    rf"|(?:\bvv?\.|\b[Vv]erses?)\s*(?P<rv>\d+)(?:[-–](?P<rv2>\d+))?"          # v. 26 / vv. 14-15 / Verse 10
    rf"|(?<![\d:])(?P<bc>\d+):(?P<bv>\d+)(?:[-–](?P<bv2>\d+))?"             # 38:26 (book carried over)
    rf"|(?<=[,;] )(?P<lv>\d+)(?:[-–](?P<lv2>\d+))?(?![\d:])"                # , 33-34 after a reference
)

def default_context(day, qnum):
    reading = next((r for r in day["readings"] if qnum in (r.get("for") or [])), day["readings"][0])
    m = re.match(rf"({book_re})\s+(\d+)", reading["ref"])
    return (m.group(1), int(m.group(2))) if m else ("Genesis", None)

def fmt(book, c, v, v2):
    book = "Psalm" if book == "Psalms" else book
    if book in SINGLE:
        return f"{book} {v}" + (f"-{v2}" if v2 else "")
    return f"{book} {c}:{v}" + (f"-{v2}" if v2 else "")

def refs_in(text, book, chapter):
    # "v. 5" means the passage under discussion: the last reference that named its book, not a bare "35:22".
    out, last_was_ref, vbook, vchapter = [], False, book, chapter
    for m in TOKEN.finditer(text):
        g = m.groupdict()
        if g["book"]:
            book = g["book"]
            if book in SINGLE:
                v, v2, c = int(g["c"]), None, 1
            elif g["v"] is None:
                chapter, last_was_ref = int(g["c"]), False   # whole chapter: remember, don't quote
                vbook, vchapter = book, chapter
                continue
            else:
                c, v, v2 = int(g["c"]), int(g["v"]), g["v2"] and int(g["v2"])
            vbook, vchapter = book, c
        elif g["rv"]:
            if vchapter is None: continue
            book, c, v, v2 = vbook, vchapter, int(g["rv"]), g["rv2"] and int(g["rv2"])
        elif g["bc"]:
            c, v, v2 = int(g["bc"]), int(g["bv"]), g["bv2"] and int(g["bv2"])
        else:
            if not last_was_ref or chapter is None: continue
            c, v, v2 = chapter, int(g["lv"]), g["lv2"] and int(g["lv2"])
        chapter, last_was_ref = c, True
        if v2 and (v2 <= v or v2 - v + 1 > MAX_VERSES):
            continue
        r = fmt(book, c, v, v2)
        if r not in out:
            out.append(r)
    return out

def main(path="study.json"):
    study = json.load(open(path))
    for day in study["days"]:
        for i, q in enumerate(day["questions"]):
            book, chapter = default_context(day, i + 1)
            q["refs"] = refs_in(q.get("answer", ""), book, chapter)
        for z in day.get("quiz") or []:
            book, chapter = default_context(day, 1)
            z["refs"] = refs_in(z.get("why", ""), book, chapter)
    json.dump(study, open(path, "w"), indent=2, ensure_ascii=False)
    return study

if __name__ == "__main__":
    s = main(*sys.argv[1:])
    n = sum(len(q["refs"]) for d in s["days"] for q in d["questions"])
    print(n, "answer references,", sum(len(z["refs"]) for d in s["days"] for z in d.get("quiz", [])), "quiz references")
