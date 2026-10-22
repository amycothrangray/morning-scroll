# Morning Scroll

Amy's morning Bible reading app: dark mode, large type, one verse in focus at a time, following Gail's Genesis study. Five minutes of reading unlocks her apps for the day (via an iOS Shortcuts automation; setup steps are in the app's Settings).

- `index.html` is the whole app.
- `study.json` holds the study: each day's verse of the day, summary, passages, questions, answers and quiz. It stays on Amy's Mac (gitignored). `python3 tools/pack.py` writes `study.dat`, the base64 copy the website and iPhone app read, so the study's text isn't picked up by search engines.

## Adding the next lesson

Paste the new lesson pages into Claude and ask to add them to `study.json`, then run `python3 tools/extract_refs.py` and `python3 tools/pack.py`. Each day needs:

- `id` like `"11B-1"`, `lesson`, `day`
- `key` (verse of the day) and a one-line `summary`
- `readings`: passages in reading order, each kept within one chapter, with `for` listing the question numbers it supports
- `questions`: the text exactly as printed; list sub-references in `items`

Scripture text is never stored here. It's fetched live from the ESV API (with Amy's key, saved only on her phone) or, without a key, from the World English Bible.
