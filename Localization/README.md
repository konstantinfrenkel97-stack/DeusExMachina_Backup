# Localization workflow

1. Keep writing Russian text in the usual resource fields.
2. When a text needs translation, add a stable key next to it, for example `god.thor.name` or `dialogue.thor_summon.001.text`.
3. Add that key to `Localization/game.csv` and fill `ru`, `en`, `es`.
4. Empty or missing keys fall back to the original Russian field, so old content keeps working.

Suggested key style:
- `god.<id>.name`
- `god.<id>.ability.<id>.name`
- `god.<id>.ability.<id>.description`
- `dialogue.<dialogue_id>.<line_id>.speaker`
- `dialogue.<dialogue_id>.<line_id>.text`
- `dialogue.<dialogue_id>.<line_id>.choice.<choice_id>`
- `mission.<id>.name`
- `mission.<id>.scene.<scene_id>.title`
- `mission.<id>.scene.<scene_id>.body`
