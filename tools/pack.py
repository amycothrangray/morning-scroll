"""Write study.dat, the encoded copy of study.json that the website and app read.

study.json stays on this Mac only (it's in .gitignore). Base64 keeps Gail's questions and the answers
out of search engines and GitHub search; it isn't a lock. Run after any edit:  python3 tools/pack.py
"""
import base64, json, shutil

study = json.load(open("study.json"))
data = base64.b64encode(json.dumps(study, ensure_ascii=False, separators=(",", ":")).encode()).decode()
with open("study.dat", "w") as f:
    f.write("\n".join(data[i:i + 100] for i in range(0, len(data), 100)) + "\n")
shutil.copy("study.dat", "ios/MorningScroll/study.dat")
print("study.dat written, version", study.get("version"))
