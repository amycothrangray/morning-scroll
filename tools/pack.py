"""Write the .dat files the website and app read: study.dat from study.json, wildflower.dat from wildflower.json.

The .json files stay on this Mac only (they're in .gitignore). Base64 keeps Gail's questions and answers, and the
book's meditations, out of search engines and GitHub search; it isn't a lock. Run after any edit:  python3 tools/pack.py
"""
import base64, json, os, shutil

BOOKS = ["study", "wildflower"]   # Gail's Genesis study; the devotional read while the study is on break

for name in BOOKS:
    if not os.path.exists(f"{name}.json"):
        continue
    book = json.load(open(f"{name}.json"))
    data = base64.b64encode(json.dumps(book, ensure_ascii=False, separators=(",", ":")).encode()).decode()
    with open(f"{name}.dat", "w") as f:
        f.write("\n".join(data[i:i + 100] for i in range(0, len(data), 100)) + "\n")
    shutil.copy(f"{name}.dat", f"ios/MorningScroll/{name}.dat")
    print(f"{name}.dat written, version {book.get('version')}, {len(book.get('days', []))} days")
