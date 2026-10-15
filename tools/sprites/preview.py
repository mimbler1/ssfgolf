"""Review sheet for one frame: native size, 4x nearest-neighbour, and gameplay size on a backdrop.

usage: python tools/sprites/preview.py <character dir> <frame name> <out.png>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import spritekit as sk


def checker(w: int, h: int, cell: int = 8) -> Image.Image:
    img = Image.new("RGBA", (w, h), (58, 62, 76, 255))
    d = ImageDraw.Draw(img)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(70, 75, 90, 255))
    return img


def main() -> None:
    char_dir, frame, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    pal = sk.Palette.load(char_dir / "palette.txt")
    rows = sk.read_grid(char_dir / "src" / f"{frame}.txt")
    errs = sk.grid_errors(rows, pal, 96, 128)
    if errs:
        print("\n".join(errs))
    img = sk.render(rows, pal)
    big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)

    pad = 16
    W = pad + img.width + pad + big.width + pad + 260 + pad
    H = pad + big.height + pad
    sheet = Image.new("RGBA", (W, H), (30, 32, 40, 255))
    x = pad
    sheet.alpha_composite(checker(img.width, img.height, 4), (x, pad))
    sheet.alpha_composite(img, (x, pad))
    x += img.width + pad
    sheet.alpha_composite(checker(big.width, big.height, 16), (x, pad))
    sheet.alpha_composite(big, (x, pad))
    x += big.width + pad
    # gameplay size: 1 sprite px = 1 world px at camera zoom 1 (1080p viewport)
    scene = Image.new("RGBA", (260, big.height), (140, 205, 240, 255))
    d = ImageDraw.Draw(scene)
    ground = big.height - 120
    d.rectangle([0, ground, 260, big.height], fill=(84, 168, 72, 255))
    d.rectangle([0, ground, 260, ground + 3], fill=(120, 205, 90, 255))
    scene.alpha_composite(img, (130 - 48, ground - 124))
    d.ellipse([130 + 44 - 3, ground - 6, 130 + 44 + 3, ground], fill=(255, 255, 255, 255), outline=(32, 20, 30, 255))
    sheet.alpha_composite(scene, (x, pad))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print("bbox", sk.opaque_bbox(rows), "->", out)


if __name__ == "__main__":
    main()
