# Third-Party Notices

This file tracks external projects, documents, and samples that influence BilineIME.

It exists for two reasons:

1. to make design and implementation lineage explicit
2. to keep code-reuse and license boundaries visible before third-party code lands in the repository

An entry here does **not** mean the code is bundled in BilineIME.

## Current References

| Source | URL | License | Current role in BilineIME | Reuse status |
| --- | --- | --- | --- | --- |
| Apple InputMethodKit documentation | <https://developer.apple.com/documentation/inputmethodkit> | Apple documentation terms | Primary platform reference for IME architecture and APIs | Documentation reference only |
| Apple QA1644: candidate annotations | <https://developer.apple.com/library/archive/qa/qa1644/_index.html> | Apple documentation terms | Primary reference for using candidate annotations with `IMKCandidates` | Documentation reference only |
| `librime` | <https://github.com/rime/librime> | BSD-3-Clause | Candidate long-term Chinese engine backend | Dependency candidate; not currently bundled |
| Squirrel | <https://github.com/rime/squirrel> | GPL-3.0 | macOS Rime frontend used as an architecture and integration reference | Reference only; do not copy code into this MIT repository under current licensing |
| `libpinyin` | <https://github.com/libpinyin/libpinyin> | GPL-3.0 | Alternative Chinese engine reference during option analysis | Reference only; do not copy code into this MIT repository under current licensing |
| `IMKitSample_2021` | <https://github.com/ensan-hcl/macOS_IMKitSample_2021> | MIT | Bootstrap and packaging reference for a minimal InputMethodKit project | Adaptation candidate with explicit attribution if code is reused |
| `pinyinIME` | <https://pypi.org/project/pinyinIME/> | MIT | Small-engine and sidecar-architecture reference for prototype options | Adaptation candidate with explicit attribution if code is reused |
| `XcodeGen` | <https://github.com/yonaskolb/XcodeGen> | MIT | Development tooling used to generate the Xcode project from `project.yml` | Tooling dependency only; not bundled in app output |
| `swift-format` | <https://github.com/swiftlang/swift-format> | Apache-2.0 | Development tooling used for source formatting conventions | Tooling dependency only; not bundled in app output |

## Project Policy

- Every future third-party dependency, borrowed snippet, or vendored asset must be added to this file in the same change that introduces it.
- If code is adapted from an upstream permissive project, the relevant implementation area must identify the upstream source and preserve the required copyright/license notice.
- If BilineIME ever chooses to incorporate GPL-licensed code, that decision must be explicit and accompanied by a repository-level licensing review.
- If an entry is later removed from the project, its status in this file should be updated rather than silently deleted.
