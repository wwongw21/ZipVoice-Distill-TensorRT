"""Rebuild the ZipVoice SVG, PNG and Windows ICO (requires Pillow at build time)."""

from pathlib import Path

from PIL import Image, ImageDraw


ASSETS = Path(__file__).resolve().parents[1] / "assets"
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def draw_icon(size):
    """Draw the same simple shapes in SVG and at four times the output size."""
    scale = size * 4 / 64
    image = Image.new("RGBA", (size * 4, size * 4))
    draw = ImageDraw.Draw(image)
    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" '
        'viewBox="0 0 64 64" role="img" aria-labelledby="title">',
        '  <title id="title">ZipVoice: a Z with sound bars</title>',
    ]

    def rectangle(x, y, width, height, radius, color):
        svg.append(
            f'  <rect x="{x}" y="{y}" width="{width}" height="{height}" '
            f'rx="{radius}" fill="{color}"/>'
        )
        draw.rounded_rectangle(
            tuple(value * scale for value in (x, y, x + width, y + height)),
            radius=radius * scale,
            fill=color,
        )

    rectangle(2, 2, 60, 60, 14, "#10263F")
    rectangle(10, 27, 4, 10, 2, "#44E0D1")
    rectangle(17, 21, 4, 22, 2, "#44E0D1")
    points = ((26, 18), (51, 18), (51, 24), (35, 40), (51, 40),
              (51, 46), (25, 46), (25, 40), (41, 24), (26, 24))
    svg.append(
        '  <polygon points="' + ' '.join(f'{x},{y}' for x, y in points)
        + '" fill="#FFFFFF"/>'
    )
    draw.polygon([(x * scale, y * scale) for x, y in points], fill="#FFFFFF")
    svg.append('</svg>')
    return image.resize((size, size), Image.Resampling.LANCZOS), '\n'.join(svg) + '\n'


def main():
    ASSETS.mkdir(exist_ok=True)
    image, svg = draw_icon(256)
    (ASSETS / "zipvoice.svg").write_text(svg, encoding="utf-8", newline="\n")
    image.save(ASSETS / "zipvoice.png")

    # Draw each size separately for crisp small icons, then let Pillow write ICO.
    # Windows bitmap frames support the tray's Windows PowerShell icon loader.
    frames = [draw_icon(size)[0] for size in SIZES[:-1]]
    image.save(ASSETS / "zipvoice.ico", format="ICO", bitmap_format="bmp",
               sizes=[(size, size) for size in SIZES], append_images=frames)
    print("Built assets/zipvoice.svg, zipvoice.png and zipvoice.ico")


if __name__ == "__main__":
    main()
