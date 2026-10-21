"""Insert a lesson's Day Six (optional word study + weekly review) after its Day Five.

Usage: python3 tools/add_day6.py day6-7.json [day6-8B.json ...]
Each file: {"id": "7-6", "summary": ..., "words": [{word, verse, hebrew, translit, strongs, gloss, answers[6]}], "review": [3 answers]}
Then run tools/extract_refs.py so the cited verses get quoted.
"""
import json, sys

WORD_STUDY = [
    "From your reading this week, choose ONE WORD to research. Is there a word that is repeated? Is there a word that strikes you as especially significant or “jumps out” at you? Is there a word that intrigues or puzzles you? Your Word of the Week:",
    "Type in your verse reference at biblehub.com. Click the Interlinear tab (“Int” on a mobile device) at the top in order to find the word in the original language. Click the link to the Strong’s number to view the Lexical Summary. What is the Hebrew word and the Strong’s #?",
    "What are the range of meanings you find when search the Strong’s definitions? What are synonyms or antonyms?",
    "From the column on the right, find several other places in the Old Testament where this word is used. Click on the link to read the verse. What insight does this give you?",
    "Now, type in your verse reference again at biblehub.com, but this time click the Commentaries tab. Browse through these to see if you can gain any additional helpful information.",
    "What has your study taught you? Have you been able to find a point of application? As you have spent time meditating on the meaning of this word in this passage, has God given you any insight into why this word stood out to you today?",
]
REVIEW = [
    "Which of God’s attributes were most clear to you this week?",
    "Which passages or insights were most meaningful to you this week? Explain.",
    "How have you applied what you’ve discovered this week about God, others, or yourself?",
]


def build(src):
    lesson = src["id"].rsplit("-", 1)[0]
    readings, seen = [], set()
    for w in src["words"]:
        ref = w["verse"]
        if ref not in seen:
            seen.add(ref)
            readings.append({"ref": ref, "for": [1, 2, 3, 4, 5, 6]})
    questions = [{"text": t, "wordStudy": i + 1, **({"section": "Optional Word Study"} if i == 0 else {})}
                 for i, t in enumerate(WORD_STUDY)]
    questions += [{"text": t, "answer": a, "n": i + 1, **({"section": "Weekly Review"} if i == 0 else {})}
                  for i, (t, a) in enumerate(zip(REVIEW, src["review"]))]
    return {"id": src["id"], "lesson": lesson, "day": "Day Six", "summary": src["summary"],
            "readings": readings, "questions": questions, "words": src["words"]}


def main(files, path="study.json"):
    study = json.load(open(path))
    for f in files:
        day = build(json.load(open(f)))
        study["days"] = [d for d in study["days"] if d["id"] != day["id"]]
        lesson = day["lesson"]
        last = max(i for i, d in enumerate(study["days"]) if d["lesson"] == lesson)
        study["days"].insert(last + 1, day)
    study["version"] = study.get("version", 0) + 1
    json.dump(study, open(path, "w"), indent=2, ensure_ascii=False)
    print([d["id"] for d in study["days"]], "version", study["version"])


if __name__ == "__main__":
    main(sys.argv[1:])
