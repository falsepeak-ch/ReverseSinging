# App Store metadata

`fastlane/metadata/` is generated. Edit `gen_metadata.py` and re-run it:

```bash
python3 Tools/metadata/gen_metadata.py
```

It writes nine `.txt` files for each of the seven store locales and checks every field
against the App Store Connect limit before it finishes, so a description that grew past
4000 characters or a subtitle past 30 fails here rather than at upload.

```bash
bundle exec fastlane metadata     # upload text only
```

## ASO: what the fields are doing

Apple indexes **name, subtitle and keywords**. Nothing else. The description converts —
it does not rank — so it is written for a person deciding whether to install, and the
three indexed fields are written for the search engine.

| field | value | why |
|---|---|---|
| name | `Reverso by Cluso` | highest weight of the three |
| subtitle | `Dub Movie Scenes in Your Voice` | 30/30 — carries `dub`, `movie`, `scenes`, `voice` |
| keywords | `choicer,voicer,dubbing,voiceover,…` | 99/100 |

Three rules the file follows, worth keeping:

1. **No word appears in more than one indexed field.** Apple combines terms across all
   three, so repeating `dub` in the keywords after the subtitle already has it buys
   nothing and costs characters.
2. **No spaces after the commas.** A space is an indexed character spent on nothing.
3. **Stems are not free.** `dubbing`, `voiceover` and `voicer` are separate tokens because
   Apple will not derive them from `dub` and `voice`.

### `choicer` and `voicer`

These target the query people are actually typing. The trend is *The Choicer Voicer*, a
voice-impression game whose dub mode went round TikTok, and whose community packs live on
GameBanana — the same site `DubContentGate` links out to. Reverso's dub mode is what those
players are looking for on a phone.

They are two separate tokens on purpose. Apple builds phrases across the field, so
`choicer` + `voicer` matches both word orders, while neither token on its own is another
product's name — which keeps the listing clear of guideline 2.3.7, the one that bans other
apps' names in metadata. Do not join them into one phrase, and do not put either in the
name or subtitle, where a reviewer reads them.

Every locale keeps `choicer,voicer,dubbing,voiceover` verbatim: the trend query is typed in
English everywhere. The rest of each keyword field is localized, with accents stripped —
Apple matches unaccented queries, and an accent is a character spent for nothing. Accents
stay in the subtitle, which humans read.

## Review notes

`fastlane/metadata/review_information/notes.txt` explains where dub content comes from:
two original scenes that ship with the app, and an ownership gate in front of importing
anything else. This is the most likely rejection vector for the dub mode and it is cheap
to pre-empt — keep it current if the gate or the bundled scenes change.
