from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "public" / "assets" / "pets"
STAGES = {
    "egg": 1,
    "baby": 4,
    "teen": 9,
    "adult": 14,
    "final": 20,
}


for species_dir in sorted(path for path in ROOT.iterdir() if path.is_dir()):
    for stage, level in STAGES.items():
        source = species_dir / f"Lv_{level:02d}.png"
        target = species_dir / f"Stage_{stage}.png"
        if source.exists():
            target.write_bytes(source.read_bytes())

    for duplicate in species_dir.glob("Lv_*.png"):
        duplicate.unlink()

print("Consolidated pet PNG assets to five stage masters per species")
