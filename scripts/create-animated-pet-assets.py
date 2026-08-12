import math
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1] / "public" / "assets" / "pets"
STAGES = {
    "egg": (1, 2.8, 2.0, 0.018),
    "baby": (4, 1.6, 7.0, 0.022),
    "teen": (9, 1.0, 5.0, 0.016),
    "adult": (14, 0.25, 3.0, 0.008),
    "final": (20, 0.18, 4.0, 0.006),
}
FRAME_COUNT = 16
FRAME_MS = 150
CANVAS = 512


def frame_for(source: Image.Image, phase: float, stage: str, rotation: float, lift: float, breathe: float) -> Image.Image:
    wave = math.sin(phase)
    secondary = math.sin(phase * 2)
    scale_x = 1 + breathe * wave
    scale_y = 1 - breathe * 0.7 * wave
    width = max(1, round(CANVAS * scale_x))
    height = max(1, round(CANVAS * scale_y))
    transformed = source.resize((width, height), Image.Resampling.LANCZOS)
    transformed = transformed.rotate(rotation * secondary, Image.Resampling.BICUBIC, expand=True)
    if stage == "final":
        transformed = ImageEnhance.Brightness(transformed).enhance(1 + 0.035 * (wave + 1) / 2)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - transformed.width) // 2
    y = (CANVAS - transformed.height) // 2 - round(lift * (wave + 1) / 2)
    canvas.alpha_composite(transformed, (x, y))
    return canvas


created = 0
for species_dir in sorted(path for path in ROOT.iterdir() if path.is_dir()):
    for stage, (level, rotation, lift, breathe) in STAGES.items():
        source = Image.open(species_dir / f"Stage_{stage}.png").convert("RGBA")
        frames = [
            frame_for(source, 2 * math.pi * index / FRAME_COUNT, stage, rotation, lift, breathe)
            for index in range(FRAME_COUNT)
        ]
        output = species_dir / f"Stage_{stage}.webp"
        frames[0].save(
            output,
            save_all=True,
            append_images=frames[1:],
            duration=FRAME_MS,
            loop=0,
            format="WEBP",
            quality=84,
            method=4,
            minimize_size=True,
        )
        created += 1

print(f"Created {created} animated pet assets")
