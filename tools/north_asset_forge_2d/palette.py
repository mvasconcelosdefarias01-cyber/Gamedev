"""Master 48-color palette. All exported sprite RGB values belong here."""

COLORS = {
    "ink": "#243c47", "shadow": "#283b56", "shadow_violet": "#4d4565",
    "paper": "#f7f4eb", "cream": "#ede4c9", "linen": "#e0e0ce",
    "soil_dark": "#684a52", "soil_mid": "#806044", "soil": "#aa865f",
    "soil_light": "#c6a57b", "soil_sun": "#e0be83",
    "wet_dark": "#4c4b5a", "wet_mid": "#675864", "wet": "#806d69",
    "wet_light": "#a68d80", "wet_glint": "#d0b69a",
    "leaf_dark": "#44566a", "leaf_mid": "#536b50", "leaf": "#80916c",
    "leaf_light": "#a8b883", "leaf_sun": "#ced09a",
    "gold_dark": "#8e6251", "gold_mid": "#ae7b44", "gold": "#e2b55f",
    "gold_light": "#f2d890", "gold_sun": "#f9e8ad",
    "water_dark": "#395c75", "water_mid": "#497578", "water": "#6b9293",
    "water_light": "#a8c9c4", "water_sun": "#d1e1cf",
    "wood_dark": "#5d4b61", "wood_mid": "#745740", "wood": "#b58a65",
    "wood_light": "#d7af81", "wood_sun": "#e9cb93",
    "stone_dark": "#56677a", "stone_mid": "#6a7b78", "stone": "#9ba6a2",
    "stone_light": "#d6d8c9", "skin_dark": "#a47170", "skin": "#d9ac88",
    "skin_light": "#edd0aa", "shirt_dark": "#814b47", "shirt": "#b5715e",
    "blue": "#7694b7", "violet": "#b2abc2", "mint": "#d0dbb1",
}

RAMPS = {
    "wood": ("wood_dark", "wood_mid", "wood", "wood_light", "wood_sun"),
    "soil": ("soil_dark", "soil_mid", "soil", "soil_light", "soil_sun"),
    "wet_soil": ("wet_dark", "wet_mid", "wet", "wet_light", "wet_glint"),
    "grass": ("leaf_dark", "leaf_mid", "leaf", "leaf_light", "leaf_sun"),
    "stone": ("stone_dark", "stone_mid", "stone", "stone_light", "paper"),
    "cloth": ("shirt_dark", "shirt", "gold", "gold_light"),
    "skin": ("skin_dark", "skin", "skin_light", "cream"),
    "foliage": ("shadow", "leaf_dark", "leaf", "leaf_light", "leaf_sun"),
    "metal": ("shadow", "stone_dark", "stone", "stone_light", "paper"),
    "water": ("water_dark", "water_mid", "water", "water_light", "water_sun"),
    "roof": ("shadow_violet", "leaf_dark", "leaf_mid", "leaf", "leaf_light"),
    "sunlight": ("gold_dark", "gold", "gold_light", "gold_sun"),
}

assert len(COLORS) == 48

RGB = {name: tuple(bytes.fromhex(value[1:])) for name, value in COLORS.items()}
ALL_RGB = set(RGB.values())
ORDERED_RGB = tuple(RGB.values())


def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    """Map legacy/generated literals to the declared palette deterministically."""
    return min(ORDERED_RGB, key=lambda c: sum((c[i] - rgb[i]) ** 2 for i in range(3)))
