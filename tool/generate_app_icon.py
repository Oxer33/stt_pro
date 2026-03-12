from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
MASTER_SIZE = 1024

ANDROID_TARGETS = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

IOS_TARGETS = {
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": 20,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": 40,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": 60,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": 29,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": 58,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": 87,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": 40,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": 80,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": 120,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": 120,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": 180,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png": 76,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png": 152,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png": 167,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": 1024,
}


def vertical_gradient(
    size: tuple[int, int],
    top_color: tuple[int, int, int],
    bottom_color: tuple[int, int, int],
) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(
            round(top_color[index] * (1 - t) + bottom_color[index] * t)
            for index in range(3)
        )
        for x in range(width):
            pixels[x, y] = (*color, 255)
    return image


def radial_glow(
    size: tuple[int, int],
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int],
    opacity: int,
) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    pixels = image.load()
    cx, cy = center
    for y in range(height):
        for x in range(width):
            dx = x - cx
            dy = y - cy
            distance = math.sqrt(dx * dx + dy * dy)
            if distance >= radius:
                continue
            strength = 1 - distance / radius
            alpha = int(opacity * (strength ** 2))
            if alpha <= 0:
                continue
            pixels[x, y] = (*color, alpha)
    return image


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def add_texture(base: Image.Image) -> None:
    draw = ImageDraw.Draw(base)
    for offset, alpha in ((-70, 58), (120, 32)):
        draw.arc(
            (-130 + offset, 110, 860 + offset, 1110),
            start=220,
            end=330,
            fill=(255, 255, 255, alpha),
            width=9,
        )
    for offset, alpha in ((35, 28),):
        draw.arc(
            (170 + offset, -130, 1170 + offset, 880),
            start=28,
            end=138,
            fill=(8, 34, 29, alpha),
            width=14,
        )


def draw_shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, alpha: int) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    base.alpha_composite(shadow)


def draw_back_card(base: Image.Image) -> None:
    shadow_box = (420, 190, 820, 580)
    draw_shadow(base, shadow_box, radius=98, alpha=140)

    card = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    card_box = (434, 204, 808, 568)
    card_radius = 94

    card_gradient = vertical_gradient(
        (card_box[2] - card_box[0], card_box[3] - card_box[1]),
        (255, 170, 98),
        (201, 97, 40),
    )
    card_mask = Image.new("L", card_gradient.size, 0)
    card_mask_draw = ImageDraw.Draw(card_mask)
    card_mask_draw.rounded_rectangle(
        (0, 0, card_gradient.size[0], card_gradient.size[1]),
        radius=card_radius,
        fill=255,
    )
    card.paste(card_gradient, card_box[:2], card_mask)

    draw.line((530, 316, 715, 316), fill=(82, 31, 9, 190), width=20)
    draw.line((530, 378, 745, 378), fill=(82, 31, 9, 150), width=20)
    draw.line((530, 440, 678, 440), fill=(82, 31, 9, 120), width=20)

    highlight = radial_glow(
        base.size,
        center=(690, 250),
        radius=220,
        color=(255, 240, 216),
        opacity=80,
    )
    card = ImageChops.screen(card, highlight)
    base.alpha_composite(card)


def draw_front_bubble(base: Image.Image) -> None:
    shadow_box = (150, 250, 710, 785)
    draw_shadow(base, shadow_box, radius=128, alpha=150)

    bubble = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(bubble)
    bubble_box = (170, 268, 698, 760)
    bubble_radius = 128
    fill = (252, 247, 238, 255)

    draw.rounded_rectangle(bubble_box, radius=bubble_radius, fill=fill)
    tail = [(290, 675), (375, 760), (455, 676)]
    draw.polygon(tail, fill=fill)
    draw.rounded_rectangle((244, 660, 470, 720), radius=30, fill=fill)

    draw.rounded_rectangle(
        (170, 268, 698, 760),
        radius=bubble_radius,
        outline=(255, 255, 255, 100),
        width=5,
    )
    draw.polygon(tail, outline=(255, 255, 255, 90), width=5)

    glaze = radial_glow(
        base.size,
        center=(350, 340),
        radius=220,
        color=(255, 255, 255),
        opacity=75,
    )
    bubble = ImageChops.screen(bubble, glaze)
    base.alpha_composite(bubble)


def draw_waveform(base: Image.Image) -> None:
    draw = ImageDraw.Draw(base)
    bars = [
        (290, 384, 332, 614, (15, 107, 94, 255)),
        (350, 336, 396, 666, (22, 35, 31, 255)),
        (415, 294, 467, 708, (201, 107, 59, 255)),
        (487, 342, 533, 662, (22, 35, 31, 255)),
        (551, 390, 593, 612, (15, 107, 94, 255)),
    ]
    for left, top, right, bottom, color in bars:
        draw.rounded_rectangle((left, top, right, bottom), radius=24, fill=color)

    for left, top, right, bottom, _ in bars:
        height = bottom - top
        shine = Image.new("RGBA", base.size, (0, 0, 0, 0))
        shine_draw = ImageDraw.Draw(shine)
        shine_draw.rounded_rectangle(
            (left + 6, top + 8, left + 18, top + height * 0.55),
            radius=10,
            fill=(255, 255, 255, 80),
        )
        base.alpha_composite(shine)

    draw.rounded_rectangle(
        (268, 718, 602, 740),
        radius=11,
        fill=(15, 107, 94, 210),
    )
    draw.rounded_rectangle(
        (268, 748, 528, 768),
        radius=10,
        fill=(201, 107, 59, 180),
    )


def draw_spark(base: Image.Image) -> None:
    spark = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(spark)
    cx, cy = 736, 292
    draw.polygon(
        [
            (cx, cy - 40),
            (cx + 12, cy - 12),
            (cx + 40, cy),
            (cx + 12, cy + 12),
            (cx, cy + 40),
            (cx - 12, cy + 12),
            (cx - 40, cy),
            (cx - 12, cy - 12),
        ],
        fill=(255, 244, 225, 235),
    )
    draw.ellipse((782, 346, 806, 370), fill=(255, 244, 225, 210))
    draw.ellipse((766, 374, 780, 388), fill=(255, 244, 225, 180))
    spark = spark.filter(ImageFilter.GaussianBlur(1.2))
    base.alpha_composite(spark)


def build_master_icon() -> Image.Image:
    base = vertical_gradient((MASTER_SIZE, MASTER_SIZE), (7, 21, 19), (17, 82, 72))
    base.alpha_composite(
        radial_glow(
            base.size,
            center=(780, 190),
            radius=380,
            color=(239, 127, 59),
            opacity=155,
        )
    )
    base.alpha_composite(
        radial_glow(
            base.size,
            center=(240, 890),
            radius=420,
            color=(13, 150, 132),
            opacity=110,
        )
    )
    add_texture(base)
    draw_back_card(base)
    draw_front_bubble(base)
    draw_waveform(base)
    draw_spark(base)

    mask = rounded_rect_mask(MASTER_SIZE, 232)
    final_image = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))
    final_image.paste(base, (0, 0), mask)
    return final_image


def save_icon(image: Image.Image, relative_path: str, size: int) -> None:
    output_path = ROOT / relative_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(output_path)


def main() -> None:
    master = build_master_icon()

    master_path = ROOT / "assets/branding/app_icon_master.png"
    preview_path = ROOT / "assets/branding/app_icon_preview.png"
    master_path.parent.mkdir(parents=True, exist_ok=True)
    master.save(master_path)
    master.save(preview_path)

    for relative_path, size in {**ANDROID_TARGETS, **IOS_TARGETS}.items():
        save_icon(master, relative_path, size)

    print(f"Generated icon assets from {master_path}")


if __name__ == "__main__":
    main()
