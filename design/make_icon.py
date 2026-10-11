"""Build design/AppIcon-1024.png from design/icon-source.png (1254² on black).
Cuts the rounded body out of the black background (mask inset past the dark
anti-aliased rim), fits it to Apple's 824pt body grid on a 1024 canvas, and
adds a soft drop shadow.  Run: python3 design/make_icon.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).parent
L, T, R, B = 61, 61, 1191, 1166      # measured body bounds in the source
RADIUS, INSET, SS = 263, 3, 4         # corner radius, rim trim, supersampling

src = Image.open(HERE / "icon-source.png").convert("RGB")
x0, y0, x1, y1 = L + INSET, T + INSET, R - INSET, B - INSET
W, H = x1 - x0 + 1, y1 - y0 + 1
mask = Image.new("L", (W * SS, H * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [0, 0, W * SS - 1, H * SS - 1], radius=(RADIUS - INSET) * SS, fill=255)
mask = mask.resize((W, H), Image.LANCZOS)
body = src.crop((x0, y0, x1 + 1, y1 + 1)).convert("RGBA")
body.putalpha(mask)

scale = 824 / max(W, H)
bw, bh = round(W * scale), round(H * scale)
body = body.resize((bw, bh), Image.LANCZOS)
ox, oy = (1024 - bw) // 2, (1024 - bh) // 2 - 6

shadow_mask = Image.new("L", (1024, 1024), 0)
shadow_mask.paste(body.getchannel("A"), (ox, oy + 12))
shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
shadow.putalpha(shadow_mask.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.45)))

canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
canvas = Image.alpha_composite(canvas, shadow)
canvas.alpha_composite(body, (ox, oy))
canvas.save(HERE / "AppIcon-1024.png")
print(f"AppIcon-1024.png: body {bw}x{bh} at {ox},{oy}")
