from __future__ import annotations

import os
import tempfile
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1] / "public" / "assets" / "pets"


def replace_if_smaller(source: Path, temporary: Path) -> tuple[int, int, bool]:
    before = source.stat().st_size
    after = temporary.stat().st_size
    if after < before:
        os.replace(temporary, source)
        return before, after, True
    temporary.unlink(missing_ok=True)
    return before, before, False


def optimize_png(source: Path) -> tuple[int, int, bool]:
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        # Keep the canvas and alpha edges intact while reducing redundant colors.
        optimized = rgba.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        optimized.info["transparency"] = optimized.info.get("transparency")
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False, dir=source.parent) as handle:
            temporary = Path(handle.name)
        optimized.save(temporary, format="PNG", optimize=True, compress_level=9)
    return replace_if_smaller(source, temporary)


def optimize_webp(source: Path) -> tuple[int, int, bool]:
    with Image.open(source) as image:
        frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(image)]
        durations = [frame.info.get("duration", image.info.get("duration", 100)) for frame in ImageSequence.Iterator(image)]
        loop = image.info.get("loop", 0)
        with tempfile.NamedTemporaryFile(suffix=".webp", delete=False, dir=source.parent) as handle:
            temporary = Path(handle.name)
        frames[0].save(
            temporary,
            format="WEBP",
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=loop,
            quality=72,
            alpha_quality=85,
            method=6,
            minimize_size=True,
        )
    return replace_if_smaller(source, temporary)


def main() -> None:
    files = sorted(path for path in ROOT.rglob("*") if path.suffix.lower() in {".png", ".webp"})
    total_before = 0
    total_after = 0
    changed = 0
    for path in files:
        result = optimize_png(path) if path.suffix.lower() == ".png" else optimize_webp(path)
        before, after, replaced = result
        total_before += before
        total_after += after
        changed += int(replaced)
    saved = total_before - total_after
    print(f"files={len(files)} changed={changed}")
    print(f"before={total_before / 1024 / 1024:.2f}MB after={total_after / 1024 / 1024:.2f}MB saved={saved / 1024 / 1024:.2f}MB")


if __name__ == "__main__":
    main()
