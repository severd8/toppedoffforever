# Draws the frames dumped by tests/render.lua as PNG images, for a visual check of
# the layout (overlaps, alignment, text running off the edge). An approximation of
# the game's look, not a screenshot.
#   lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

src = sys.argv[1] if len(sys.argv) > 1 else "tests/render-out.json"
outdir = sys.argv[2] if len(sys.argv) > 2 else "tests/render-out"
os.makedirs(outdir, exist_ok=True)

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_COLORS = {
    "GameFontNormal": (255, 209, 0), "GameFontNormalSmall": (255, 209, 0), "GameFontNormalLarge": (255, 209, 0),
    "GameFontHighlight": (255, 255, 255), "GameFontHighlightSmall": (255, 255, 255),
    "GameFontDisableSmall": (128, 128, 128), "NumberFontNormal": (255, 255, 255),
}
_fonts = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONT_BOLD if bold else FONT, max(8, int(size * 0.92)))
    return _fonts[key]


def rgb(c, a=1.0):
    return tuple(int(max(0, min(1, v)) * 255) for v in c[:3]) + (int(a * 255),)


def draw_view(view, scale=2):
    fl, ft, fr, fb = view["frame"]
    pad = 30
    ox, oy = fl - pad, ft - pad - 50
    w = int(fr - fl + pad * 2)
    h = int(fb - ft + pad * 2 + 60)
    img = Image.new("RGBA", (w * scale, h * scale), (40, 44, 36, 255))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))

    def box(it):
        return [(it["l"] - ox) * scale, (it["t"] - oy) * scale, (it["r"] - ox) * scale, (it["b"] - oy) * scale]

    # Background textures (like icon borders) sit just above their parent, under siblings
    def z(it):
        if it.get("layer") == "BACKGROUND" and "p" in it:
            return it["p"] + 0.5
        return it["i"]
    late = []
    for it in sorted(view["items"], key=lambda it: (it.get("fl", 0), z(it))):
        d = ImageDraw.Draw(layer)
        x0, y0, x1, y1 = box(it)
        if x1 < x0 or y1 < y0:
            continue
        clip = it.get("clip")
        if clip:
            cx0, cy0 = (clip[0] - ox) * scale, (clip[1] - oy) * scale
            cx1, cy1 = (clip[2] - ox) * scale, (clip[3] - oy) * scale
            if y1 < cy0 or y0 > cy1:
                continue
        kind, tmpl = it["kind"], it.get("tmpl", "")
        if tmpl == "UIPanelCloseButton" and x1 - x0 < 6 * scale:   # template default size
            x0, x1 = x1 - 26 * scale, x1 + 2 * scale
            cy = (y0 + y1) / 2
            y0, y1 = cy - 13 * scale, cy + 13 * scale
        if kind == "Texture":
            if "color" in it:
                d.rectangle([x0, y0, x1, y1], fill=rgb(it["color"], it["color"][3] if len(it["color"]) > 3 else 1))
            elif "texture" in it and x1 - x0 > 4:
                grey = (70, 70, 70, 255) if it.get("desat") else (150, 110, 60, 255)
                d.rectangle([x0, y0, x1, y1], fill=grey, outline=(20, 20, 20, 255))
        elif kind == "CheckButton":
            s = 16 * scale
            bx, by = x0 + 4 * scale, (y0 + y1) / 2 - s / 2
            d.rectangle([bx, by, bx + s, by + s], fill=(25, 25, 25, 255), outline=(170, 170, 170, 255), width=scale)
            if it.get("checked"):
                d.line([bx + 3 * scale, by + 8 * scale, bx + 7 * scale, by + 13 * scale, bx + 14 * scale, by + 2 * scale],
                       fill=(255, 210, 0, 255), width=3 * scale)
        elif kind == "EditBox":
            # The box itself is drawn by its own fill and border textures; its text goes on top of them
            if it.get("text"):
                late.append((it, clip))
        elif kind == "Button" and tmpl == "UIPanelButtonTemplate":
            d.rounded_rectangle([x0, y0, x1, y1], radius=3 * scale, fill=(125, 18, 12, 255), outline=(200, 160, 60, 255), width=scale)
            if it.get("text"):
                d.text(((x0 + x1) / 2, (y0 + y1) / 2), it["text"], font=font(11 * scale), fill=(255, 209, 0, 255), anchor="mm")
        elif kind == "Button" and tmpl == "UIPanelCloseButton":
            d.rounded_rectangle([x0 + 2 * scale, y0 + 2 * scale, x1 - 2 * scale, y1 - 2 * scale], radius=3 * scale, fill=(140, 20, 15, 255))
            d.text(((x0 + x1) / 2, (y0 + y1) / 2), "x", font=font(12 * scale, True), fill=(255, 220, 200, 255), anchor="mm")
        elif kind == "Slider":
            d.rectangle([x0, (y0 + y1) / 2 - 3 * scale, x1, (y0 + y1) / 2 + 3 * scale], fill=(30, 30, 30, 255), outline=(120, 120, 120, 255))
        elif kind == "FontString" and it.get("text"):
            size = it.get("size", 12)
            color = it.get("tcolor")
            fill = rgb(color) if color else FONT_COLORS.get(it.get("font", ""), (255, 255, 255)) + (255,)
            f = font(size * scale, size >= 14)
            just = it.get("justify", "LEFT")
            ty = (y0 + y1) / 2
            text = it["text"]
            width = x1 - x0
            lines = [text]
            if it.get("fixedw") and width > 0 and d.textlength(text, font=f) > width + 2 * scale:
                words, lines, cur = text.split(" "), [], ""
                for wd in words:
                    trial = (cur + " " + wd).strip()
                    if d.textlength(trial, font=f) <= width or not cur:
                        cur = trial
                    else:
                        lines.append(cur)
                        cur = wd
                lines.append(cur)
            lh = (size + 2) * scale
            top = ty - lh * len(lines) / 2 + lh / 2
            for n, line in enumerate(lines):
                y = top + n * lh
                if just == "CENTER":
                    d.text(((x0 + x1) / 2, y), line, font=f, fill=fill, anchor="mm")
                elif just == "RIGHT":
                    d.text((x1, y), line, font=f, fill=fill, anchor="rm")
                else:
                    d.text((x0, y), line, font=f, fill=fill, anchor="lm")
        if clip:
            mask = Image.new("L", img.size, 0)
            ImageDraw.Draw(mask).rectangle([cx0, cy0, cx1, cy1], fill=255)
            clipped = Image.new("RGBA", img.size, (0, 0, 0, 0))
            clipped.paste(layer, (0, 0), mask)
            img = Image.alpha_composite(img, clipped)
        else:
            img = Image.alpha_composite(img, layer)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for it, clip in late:
        x0, y0, x1, y1 = box(it)
        if clip and (y1 < (clip[1] - oy) * scale or y0 > (clip[3] - oy) * scale):
            continue
        if it.get("justify") == "CENTER":
            d.text(((x0 + x1) / 2, (y0 + y1) / 2), it["text"], font=font(10 * scale), fill=(255, 255, 255, 255), anchor="mm")
        else:
            d.text((x0 + 6 * scale, (y0 + y1) / 2), it["text"], font=font(10 * scale), fill=(255, 255, 255, 255), anchor="lm")
    d.text((6 * scale, 6 * scale), view["name"], font=font(11 * scale), fill=(200, 200, 200, 255))
    return img


views = json.load(open(src))
for v in views:
    name = re.sub(r"[^a-z0-9-]", "", v["name"])
    draw_view(v).save(os.path.join(outdir, name + ".png"))
print("rendered", len(views), "images to", outdir)
