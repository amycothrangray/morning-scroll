# Morning Scroll

Amy's morning Bible reading app: dark mode, large type, one verse in focus at a time, following Gail's Genesis study. Five minutes of reading unlocks her apps for the day (via an iOS Shortcuts automation; setup steps are in the app's Settings).

- `index.html` is the whole app.
- `study.json` holds the study: each day's verse of the day, summary, passages, questions, answers and quiz. It stays on Amy's Mac (gitignored). `python3 tools/pack.py` writes `study.dat`, the base64 copy the website and iPhone app read, so the study's text isn't picked up by search engines.
- `wildflower.json` is a second book, Ruth Chou Simons's *The Way of the Wildflower*, for the weeks the study is on break. Same arrangement: gitignored, and `pack.py` writes `wildflower.dat` beside `study.dat`. Home shows a Genesis / Wildflower switcher once the book has at least one day in it.

## Adding the next lesson

Paste the new lesson pages into Claude and ask to add them to `study.json`, then run `python3 tools/extract_refs.py` and `python3 tools/pack.py`. Each day needs:

- `id` like `"11B-1"`, `lesson`, `day`
- `key` (verse of the day) and a one-line `summary`
- `readings`: passages in reading order, each kept within one chapter, with `for` listing the question numbers it supports
- `questions`: the text exactly as printed; list sub-references in `items`

Scripture text is never stored here. It's fetched live from the ESV API (with Amy's key, saved only on her phone) or, without a key, from the World English Bible.

## Review banks

Each lesson has two review banks in `study.json`'s top-level `reviews` list: one for Days One–Three (`part: 1`) and one for Days Four–Six (`part: 2`). Each bank has `id` like `"8B-R1"`, `lesson`, `part`, `title`, `days` (the day ids it covers), `summary`, and `items`, the questions. Item types: `mc`, `tf`, `whosaid`, `blank`, `order`, `sequence`, `match`, `refmatch` and `memory`. Any item can carry `ref` so the verse is fetched and shown written out. Scripture is still never stored: a `blank` or `order` game builds itself from the fetched verse.

A review shows in the day list right after its last day. Switching days or reviews from the reader's top bar keeps the five-minute timer running; the page she's on when it runs out gets the check.

If `study.json` isn't on this machine, `python3 tools/unpack.py` rebuilds it from `study.dat` (add `--force` to overwrite one that's there). Run `pack.py` afterwards as usual.

On the iPhone, a review opens the website's review page inside the app (`index.html?embed=1&review=<id>`), so the website has to be live with the review games before the iPhone can show them.

## Adding a meditation from The Way of the Wildflower

Paste the meditation (or photos of its pages) into Claude and ask to add it to `wildflower.json`, then run `python3 tools/pack.py`. Each day needs:

- `id` like `"wf-3"`, `lesson` (the part of the book: `"The Way of Dependency"`, `"The Way of Freedom"`…), `day` like `"Day 3"`, and `title`
- `key`: the verse the meditation is built on. Scripture is still fetched live, never stored. Add `readings` for a longer passage, read one verse at a time like the study
- `body`: the meditation as a list of paragraphs
- `truth`, `prayer` and `wildflower` (`{"name", "fact"}`) when the page has them

Bump `version` after every change so the iPhone app takes the new copy. A day scrolls like a study day: verse of the day, passage, then the meditation and its cards scroll freely, and five minutes unlocks the apps.
