"""Render the application identity at native Windows icon sizes."""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent.parent
target = root / "target"
target.mkdir(exist_ok=True)
scale = 32
image = Image.new("RGBA", (32 * scale, 32 * scale), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)


def box(coords):
    return tuple(round(value * scale) for value in coords)


ink = "#0a121a"
draw.rounded_rectangle(box((1, 2, 31, 30)), radius=5 * scale, fill=ink)
draw.rounded_rectangle(box((2, 3, 30, 29)), radius=4 * scale, fill="#ffffff")
draw.rounded_rectangle(box((4, 5, 28, 27)), radius=2 * scale, fill="#40f2a6")
draw.rounded_rectangle(box((7, 8, 25, 24)), radius=scale, outline=ink, width=2 * scale)
draw.line(box((7, 19, 25, 19)), fill=ink, width=2 * scale)
draw.line(box((16, 19, 16, 24)), fill=ink, width=2 * scale)
image = image.resize((256, 256), Image.Resampling.LANCZOS)
image.save(target / "touchpad.ico", sizes=[(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)])
image.save(target / "application-icon.png")
print("APPLICATION-ICON-OK: 16/20/24/32/40/48/64/128/256 px")
