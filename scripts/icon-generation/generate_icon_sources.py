#!/usr/bin/env python3
"""Generate BilineIME icon source images with OpenAI gpt-image-2.

This script creates opaque PNG source images only. Follow-up tooling should
convert selected source images into macOS .icns files and template PDFs.

Usage:
  python3 scripts/icon-generation/generate_icon_sources.py --dry-run
  OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py --quality low
  OPENAI_API_KEY=... python3 scripts/icon-generation/generate_icon_sources.py --quality high --asset app_icon_release
"""

from __future__ import annotations

import argparse
import base64
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from decimal import Decimal
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request


API_URL = "https://api.openai.com/v1/images/generations"
DEFAULT_MODEL = "gpt-image-2"
DEFAULT_OUTPUT_DIR = Path("build/generated-icons/gpt-image-2")

# Official docs examples for gpt-image-2 common sizes, output image cost only.
# This excludes prompt text tokens and input image tokens for edits.
KNOWN_OUTPUT_COST_USD = {
    ("1024x1024", "low"): Decimal("0.006"),
    ("1024x1024", "medium"): Decimal("0.053"),
    ("1024x1024", "high"): Decimal("0.211"),
    ("1024x1536", "low"): Decimal("0.005"),
    ("1024x1536", "medium"): Decimal("0.041"),
    ("1024x1536", "high"): Decimal("0.165"),
    ("1536x1024", "low"): Decimal("0.005"),
    ("1536x1024", "medium"): Decimal("0.041"),
    ("1536x1024", "high"): Decimal("0.165"),
}


BASE_STYLE = """
BilineIME is a macOS Chinese-first bilingual input method. Its visual system
should feel original, first-party, compact, and precise. The core metaphor is
two clean parallel composition lines, a pinyin cursor, and a quiet English
preview layer. Do not imitate SF Symbols, Heroicons, Apple system icons, Rime
icons, or any open-source icon pack. Avoid keyboards, flags, Apple logos,
Chinese characters, watermarks, signatures, and UI screenshots.
""".strip()


MONOCHROME_GLYPH_RULES = """
Create a monochrome black glyph on a pure white background. Use a centered,
vector-friendly mark with generous padding. Keep the silhouette simple enough to
survive at 16 to 18 pt after conversion. No gray, gradients, shadows, texture,
border, text, letters, Chinese characters, watermark, or background decoration.
""".strip()


@dataclass(frozen=True)
class AssetSpec:
    name: str
    purpose: str
    size: str
    prompt: str
    optional: bool = False


ASSETS = [
    AssetSpec(
        name="brand_mark",
        purpose="Primary BilineIME brand mark source.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}

Create the primary BilineIME brand mark. Center an original abstract symbol
made from two clean flowing parallel composition lines and a small cursor-like
vertical stroke. It should imply Chinese pinyin composition plus a second
preview layer without using literal text. Make it polished, balanced, memorable,
and readable at small sizes. Opaque square background. No text.
""".strip(),
    ),
    AssetSpec(
        name="app_icon_release",
        purpose="Release input method app icon source for AppIcon.icns.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}

Create a finished macOS app icon for BilineIME Release. Use the BilineIME
abstract mark: two refined parallel composition lines and a subtle cursor
stroke, rendered as a premium native macOS icon. Keep the mark bold enough to
read at 16 px, with controlled depth and a clean square icon composition.
Opaque background. No text, letters, Chinese characters, keyboard, or watermark.
""".strip(),
    ),
    AssetSpec(
        name="app_icon_dev",
        purpose="Dev input method app icon source for AppIcon.icns.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}

Create a finished macOS app icon for BilineIME Dev. It should share the Release
icon structure and BilineIME abstract mark, but include a tiny, non-textual dev
distinction such as a small corner notch, dot, or construction accent. The dev
mark must remain readable at 16 px and must not rely on letters or words.
Opaque background. No text, Chinese characters, keyboard, or watermark.
""".strip(),
    ),
    AssetSpec(
        name="settings_app_icon",
        purpose="Biline Settings app icon source for a future Settings AppIcon.icns.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}

Create a macOS Settings companion app icon for Biline Settings. Use the
BilineIME abstract mark integrated with a restrained settings metaphor, such as
a precise control dial or small adjustment track. Keep it clearly related to the
main app icon but distinct as a configuration app. Opaque square background. No
text, letters, Chinese characters, gear cliche, keyboard, or watermark.
""".strip(),
    ),
    AssetSpec(
        name="menu_icon_release",
        purpose="Release input source and status/menu bar icon source.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design the Release menu bar glyph for BilineIME. It should be the simplest
possible version of the BilineIME mark: two parallel composition lines and a
tiny cursor stroke. The shape must work as a macOS template icon after
conversion to an 18 x 18 pt PDF.
""".strip(),
    ),
    AssetSpec(
        name="menu_icon_dev",
        purpose="Dev input source and status/menu bar icon source.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design the Dev menu bar glyph for BilineIME. It should match the Release glyph
silhouette but include a tiny non-textual dev distinction, such as one small dot
or notch. The shape must work as a macOS template icon after conversion to an
18 x 18 pt PDF.
""".strip(),
    ),
    AssetSpec(
        name="sidebar_translation",
        purpose="Settings sidebar icon for translation configuration.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design a Settings sidebar glyph for translation configuration. Use an abstract
two-layer language preview motif, not a globe. It should visually belong to the
BilineIME icon family and convert cleanly to a 24 x 24 pt template PDF.
""".strip(),
    ),
    AssetSpec(
        name="sidebar_input_settings",
        purpose="Settings sidebar icon for input settings.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design a Settings sidebar glyph for input settings. Suggest pinyin composition,
candidate tuning, or precise controls without using a keyboard or generic
slider icon. It should visually belong to the BilineIME icon family and convert
cleanly to a 24 x 24 pt template PDF.
""".strip(),
    ),
    AssetSpec(
        name="sidebar_appearance",
        purpose="Settings sidebar icon for appearance settings.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design a Settings sidebar glyph for appearance settings. Suggest theme, panel
surface, or visual polish without using a generic paint palette. It should
visually belong to the BilineIME icon family and convert cleanly to a 24 x
24 pt template PDF.
""".strip(),
    ),
    AssetSpec(
        name="sidebar_status",
        purpose="Settings sidebar icon for status and diagnostics.",
        size="1024x1024",
        prompt=f"""
{BASE_STYLE}
{MONOCHROME_GLYPH_RULES}

Design a Settings sidebar glyph for status and diagnostics. Suggest readiness,
connection, or health state without using a generic checkmark circle. It should
visually belong to the BilineIME icon family and convert cleanly to a 24 x
24 pt template PDF.
""".strip(),
    ),
    AssetSpec(
        name="wordmark_concept",
        purpose="Optional wordmark exploration; verify text manually.",
        size="1536x1024",
        optional=True,
        prompt=f"""
{BASE_STYLE}

Create a horizontal brand lockup concept for BilineIME with the abstract
BilineIME mark on the left and the product name "BilineIME" on the right.
Use clean modern typography and generous spacing. Because generated text can be
imperfect, prioritize composition and brand direction over final production
lettering. Opaque background. No extra words or watermark.
""".strip(),
    ),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate BilineIME icon source PNGs with gpt-image-2."
    )
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--quality",
        choices=["low", "medium", "high", "auto"],
        default="low",
        help="Use low/medium for drafts; high for selected final assets.",
    )
    parser.add_argument(
        "--asset",
        action="append",
        default=[],
        help="Asset name to generate. Repeat for multiple. Defaults to required assets.",
    )
    parser.add_argument(
        "--include-optional",
        action="store_true",
        help="Include optional assets such as wordmark_concept.",
    )
    parser.add_argument("--variants", type=int, default=1, help="Images per asset.")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--list-assets", action="store_true")
    parser.add_argument("--timeout", type=int, default=180)
    return parser.parse_args()


def selected_assets(args: argparse.Namespace) -> list[AssetSpec]:
    by_name = {asset.name: asset for asset in ASSETS}
    if args.list_assets:
        return []
    if args.asset:
        unknown = [name for name in args.asset if name not in by_name]
        if unknown:
            raise SystemExit(f"Unknown asset(s): {', '.join(unknown)}")
        return [by_name[name] for name in args.asset]
    return [asset for asset in ASSETS if args.include_optional or not asset.optional]


def estimate_output_cost(
    assets: list[AssetSpec], quality: str, variants: int
) -> tuple[Decimal, list[str]]:
    total = Decimal("0")
    missing: list[str] = []
    if quality == "auto":
        return total, [asset.name for asset in assets]
    for asset in assets:
        cost = KNOWN_OUTPUT_COST_USD.get((asset.size, quality))
        if cost is None:
            missing.append(asset.name)
        else:
            total += cost * variants
    return total, missing


def print_asset_list() -> None:
    for asset in ASSETS:
        suffix = " optional" if asset.optional else ""
        print(f"{asset.name:24} {asset.size:11} {asset.purpose}{suffix}")


def request_image(api_key: str, payload: dict, timeout: int) -> dict:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    if organization := os.environ.get("OPENAI_ORG_ID"):
        headers["OpenAI-Organization"] = organization
    if project := os.environ.get("OPENAI_PROJECT_ID"):
        headers["OpenAI-Project"] = project

    request = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise SystemExit(f"OpenAI API error {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise SystemExit(f"OpenAI API request failed: {error}") from error


def write_manifest(path: Path, manifest: dict) -> None:
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


def main() -> int:
    args = parse_args()
    if args.variants < 1:
        raise SystemExit("--variants must be at least 1")

    if args.list_assets:
        print_asset_list()
        return 0

    assets = selected_assets(args)
    total, missing = estimate_output_cost(assets, args.quality, args.variants)
    print(
        f"Selected {len(assets)} asset(s), {args.variants} variant(s) each, "
        f"quality={args.quality}."
    )
    if missing:
        print(
            "Estimated output cost: partial/unavailable for "
            + ", ".join(missing)
            + "."
        )
    else:
        print(
            "Estimated output cost, excluding text/input-image tokens: "
            f"${total:.3f}"
        )

    if args.dry_run:
        for asset in assets:
            print(f"\n[{asset.name}] {asset.size}\n{asset.prompt}")
        return 0

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is required unless --dry-run is used.")

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.out_dir / run_id
    out_dir.mkdir(parents=True, exist_ok=True)

    manifest = {
        "generated_at": run_id,
        "model": args.model,
        "quality": args.quality,
        "output_format": "png",
        "background": "opaque",
        "variants": args.variants,
        "api_url": API_URL,
        "assets": [],
    }

    for asset in assets:
        payload = {
            "model": args.model,
            "prompt": asset.prompt,
            "size": asset.size,
            "quality": args.quality,
            "output_format": "png",
            "background": "opaque",
            "n": args.variants,
        }
        print(f"Generating {asset.name} ({asset.size}, {args.quality})...")
        response = request_image(api_key, payload, timeout=args.timeout)
        files: list[str] = []
        for index, item in enumerate(response.get("data", []), start=1):
            image_base64 = item.get("b64_json")
            if not image_base64:
                raise SystemExit(f"No b64_json returned for {asset.name}.")
            output_path = out_dir / f"{asset.name}__{args.quality}__v{index}.png"
            output_path.write_bytes(base64.b64decode(image_base64))
            files.append(str(output_path))
            print(f"  wrote {output_path}")
        manifest["assets"].append(
            {
                **asdict(asset),
                "files": files,
            }
        )
        write_manifest(out_dir / "manifest.json", manifest)

    print(f"Manifest: {out_dir / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
