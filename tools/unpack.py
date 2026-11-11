"""Turn the .dat files back into editable .json: study.dat -> study.json, wildflower.dat -> wildflower.json.

Run this first if your study.json is older than the one on GitHub (for example after the review banks were added),
so a later pack.py doesn't drop anything:  python3 tools/unpack.py
It won't overwrite a .json that already exists unless you add --force.
"""
import base64, json, os, sys

force = "--force" in sys.argv
for name in ["study", "wildflower"]:
    if not os.path.exists(f"{name}.dat"):
        continue
    if os.path.exists(f"{name}.json") and not force:
        print(f"{name}.json already exists; add --force to replace it")
        continue
    book = json.loads(base64.b64decode("".join(open(f"{name}.dat").read().split())).decode())
    json.dump(book, open(f"{name}.json", "w"), ensure_ascii=False, indent=2)
    print(f"{name}.json written, version {book.get('version')}, {len(book.get('days', []))} days, {len(book.get('reviews', []))} review banks")
