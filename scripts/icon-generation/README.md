# BilineIME icon generation scripts

This folder holds Python scripts for generating first-party BilineIME icon
source images with OpenAI `gpt-image-2`.

The scripts read `OPENAI_API_KEY` from the local environment. Do not write API
keys into this repository.

## What the script generates

`generate_icon_sources.py` creates opaque PNG source images under
`build/generated-icons/gpt-image-2/<run-id>/`. The `build/` folder is ignored by
git.

It does not convert sources into final app assets. Follow-up tooling should turn
selected PNGs into:

- `Resources/Release/AppIcon.icns`
- `Resources/Dev/AppIcon.icns`
- `Resources/Release/menu_icon.pdf`
- `Resources/Dev/menu_icon.pdf`
- a future Settings app icon
- future Settings sidebar template icons

## Official cost and latency notes

OpenAI's image generation guide says `gpt-image-2` cost is estimated from
requested `quality` and `size`, plus text input tokens and any input image tokens
for edits.

Current listed output image costs for `gpt-image-2`:

| Size | Low | Medium | High |
| --- | ---: | ---: | ---: |
| `1024x1024` | `$0.006` | `$0.053` | `$0.211` |
| `1024x1536` | `$0.005` | `$0.041` | `$0.165` |
| `1536x1024` | `$0.005` | `$0.041` | `$0.165` |

Complex prompts may take up to 2 minutes. Square images are typically fastest.
The docs also note that `gpt-image-2` does not currently support transparent
backgrounds, so these prompts request opaque PNGs and leave transparency/template
conversion to later local processing.

Source:
https://developers.openai.com/api/docs/guides/image-generation#cost-and-latency

## Usage

List planned assets:

```bash
python3 scripts/icon-generation/generate_icon_sources.py --list-assets
```

Preview prompts and estimated output cost without an API key:

```bash
python3 scripts/icon-generation/generate_icon_sources.py --dry-run
```

Generate low-cost drafts:

```bash
OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py --quality low
```

Generate one selected final candidate:

```bash
OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py \
  --quality high \
  --asset app_icon_release
```

Generate multiple variants for one asset:

```bash
OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py \
  --quality medium \
  --asset menu_icon_release \
  --variants 4
```

Optional wordmark exploration is excluded by default because generated text still
needs manual verification:

```bash
OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py \
  --quality medium \
  --include-optional
```
