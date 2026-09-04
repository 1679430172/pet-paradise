"""Measure pet alpha bounds for CSS alignment; source images are never modified."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'src/lib/pet-layout.json'
STAGES = ('egg', 'baby', 'teen', 'adult', 'final')


def main():
    layouts = {}
    for species_dir in sorted((ROOT / 'public/assets/pets').iterdir()):
        if not species_dir.is_dir():
            continue
        species_layouts = {}
        for stage in STAGES:
            source = species_dir / f'Stage_{stage}.png'
            if not source.exists():
                continue
            with Image.open(source) as image:
                # Ignore nearly transparent fringes when measuring the visible silhouette.
                bounds = image.convert('RGBA').getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
                if bounds is None:
                    raise ValueError(f'Empty pet asset: {source}')
                left, top, right, bottom = bounds
                width, height = image.size
                species_layouts[stage] = {
                    'left': left / width, 'top': top / height,
                    'right': right / width, 'bottom': bottom / height,
                }
        if species_layouts:
            layouts[species_dir.name] = species_layouts
    OUTPUT.write_text(json.dumps(layouts, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    asset_count = sum(len(stages) for stages in layouts.values())
    print(f'Measured {asset_count} pet assets across {len(layouts)} species')


if __name__ == '__main__':
    main()
