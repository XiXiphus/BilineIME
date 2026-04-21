# Third-Party Notices

This file tracks external projects, documents, samples, data, and runtime
components that influence BilineIME.

It exists for two reasons:

1. to make design and implementation lineage explicit
2. to keep code-reuse and license boundaries visible before third-party code lands in the repository

The reuse status column states whether the referenced code or data is bundled.

## Current References

| Source | URL | License | Current role in BilineIME | Reuse status |
| --- | --- | --- | --- | --- |
| Apple InputMethodKit documentation | <https://developer.apple.com/documentation/inputmethodkit> | Apple documentation terms | Primary platform reference for IME architecture and APIs | Documentation reference only |
| Apple QA1644: candidate annotations | <https://developer.apple.com/library/archive/qa/qa1644/_index.html> | Apple documentation terms | Primary reference for using candidate annotations with `IMKCandidates` | Documentation reference only |
| `librime` | <https://github.com/rime/librime> | BSD-3-Clause | Chinese engine backend | Vendored source under `Vendor/librime`; runtime dylib is bundled in the IME app |
| `glog` | <https://github.com/google/glog> | BSD-3-Clause | `librime` logging dependency | Bundled as `libglog.2.dylib` in the Homebrew runtime path; may be statically linked into `librime.1.dylib` in the vendored build path |
| `gflags` | <https://github.com/gflags/gflags> | BSD-3-Clause | Runtime dependency of the Homebrew `librime`/`glog` build | Bundled as `libgflags.2.3.dylib` when the dynamic Rime runtime is packaged |
| `leveldb` | <https://github.com/google/leveldb> | BSD-3-Clause | `librime` user dictionary storage dependency | Bundled as `libleveldb.1.dylib` in the Homebrew runtime path; may be statically linked into `librime.1.dylib` in the vendored build path |
| Snappy | <https://github.com/google/snappy> | BSD-3-Clause | Runtime dependency of the Homebrew `leveldb` build | Bundled as `libsnappy.1.dylib` when present in the dynamic dependency closure |
| `marisa-trie` | <https://github.com/s-yata/marisa-trie> | BSD-2-Clause OR LGPL-2.1-or-later | Trie dependency used by `librime` and OpenCC | Bundled as `libmarisa.0.dylib` in the Homebrew runtime path; may be statically linked into `librime.1.dylib` in the vendored build path |
| OpenCC | <https://github.com/BYVoid/OpenCC> | Apache-2.0 | Simplified/traditional conversion used by Rime | Bundled as `libopencc.1.3.dylib` in the Homebrew runtime path or statically linked in the vendored build path; selected OpenCC conversion data is copied under `RimeRuntime/share/opencc` |
| `yaml-cpp` | <https://github.com/jbeder/yaml-cpp> | MIT | YAML parser dependency used by `librime` | Bundled as `libyaml-cpp.0.9.dylib` in the Homebrew runtime path; may be statically linked into `librime.1.dylib` in the vendored build path |
| `rime-prelude` | <https://github.com/rime/rime-prelude> | LGPL-3.0 | Reference for Rime default configuration structure and presets | Vendored source reference under `Vendor/rime-prelude`; no upstream file is copied verbatim into app runtime |
| `rime-luna-pinyin` | <https://github.com/rime/rime-luna-pinyin> | LGPL-3.0 | Pinyin spelling algebra and source-side tokenizer seed | Vendored under `Vendor/rime-luna-pinyin`; `pinyin.yaml` is bundled, while `luna_pinyin.dict.yaml` is used from the source tree and is not copied into app runtime |
| `rime-essay` | <https://github.com/rime/rime-essay> | LGPL-3.0 | Historical Rime preset vocabulary reference | Vendored source reference only; not bundled in the runtime |
| `rime-ice` | <https://github.com/iDvel/rime-ice> | GPL-3.0-only | Simplified Chinese dictionary baseline | Vendored under `Vendor/rime-ice` at `2bd2983c6c74ea49b3a013f150ade7f3b8a27515`; only core `rime_ice.dict.yaml` and selected `cn_dicts` are bundled |
| `rime-ice` upstream dictionary sources | <https://github.com/iDvel/rime-ice> | Mixed; see upstream attribution | Data provenance for bundled `rime-ice` dictionaries, including upstream-noted sources such as `rime-essay-simp`, THUOCL, and Tencent AI Lab Chinese Word Vectors | Bundled indirectly through selected `Vendor/rime-ice` dictionary files; no separate source trees are vendored |
| Squirrel | <https://github.com/rime/squirrel> | GPL-3.0 | macOS Rime frontend used as an architecture and integration reference | Reference only; code is not copied |
| `libpinyin` | <https://github.com/libpinyin/libpinyin> | GPL-3.0 | Alternative Chinese engine reference during option analysis | Reference only; code is not copied |
| `IMKitSample_2021` | <https://github.com/ensan-hcl/macOS_IMKitSample_2021> | MIT | Bootstrap and packaging reference for a minimal InputMethodKit project | Adaptation candidate with explicit attribution if code is reused |
| `pinyinIME` | <https://pypi.org/project/pinyinIME/> | MIT | Small-engine and sidecar-architecture reference for prototype options | Adaptation candidate with explicit attribution if code is reused |
| Heroicons | <https://github.com/tailwindlabs/heroicons> | MIT | Source of the current `menu_icon.pdf` and `AppIcon.icns` input-method icon assets | Bundled asset adaptation for menu/input-source and app icon |
| `XcodeGen` | <https://github.com/yonaskolb/XcodeGen> | MIT | Development tooling used to generate the Xcode project from `project.yml` | Tooling dependency only; not bundled in app output |
| `swift-format` | <https://github.com/swiftlang/swift-format> | Apache-2.0 | Development tooling used for source formatting conventions | Tooling dependency only; not bundled in app output |

## Project Policy

- Every future third-party dependency, borrowed snippet, or vendored asset must be added to this file in the same change that introduces it.
- If code or data is adapted from an upstream project, the relevant implementation area must identify the upstream source and preserve the required copyright/license notice.
- GPL-licensed bundled components require the repository-level GPL license and explicit notice updates in the same change.
- Binary app distributions must include this file and the required upstream license texts, either alongside the app or in another customary documentation location.
- If an entry is later removed from the project, its status in this file should be updated rather than silently deleted.
- Generated artifacts from tooling listed here, such as `BilineIME.xcodeproj`, are not source of truth and should not be committed unless the repository policy changes explicitly.
