"""Measure egg alpha bounds for CSS alignment; source images are never modified."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'src/lib/egg-layout.json'


def main():
    layouts = {}
    for source in sorted((ROOT / 'public/assets/pets').glob('*/Stage_egg.png')):
        with Image.open(source) as image:
            # Ignore nearly transparent fringes when measuring the visible silhouette.
            bounds = image.convert('RGBA').getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
            if bounds is None:
                raise ValueError(f'Empty egg asset: {source}')
            left, top, right, bottom = bounds
            width, height = image.size
            layouts[source.parent.name] = {
                'left': left / width, 'top': top / height,
                'right': right / width, 'bottom': bottom / height,
            }
    OUTPUT.write_text(json.dumps(layouts, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Measured {len(layouts)} egg assets')


if __name__ == '__main__':
    main()
