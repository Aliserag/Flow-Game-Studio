"""
Centralised prompt templates for WARBAND sprite generation.

Each archetype/enemy has a description, negative description, and silhouette
note (anchoring to art-bible §6). The wrapper script composes the final prompt
sent to PixelLab.
"""

ARCHETYPE_PROMPTS = {
    "chieftain": {
        "description": (
            "Mighty orc chieftain warrior, broad-shouldered, dark green skin, "
            "prominent tusks, heavy brow ridge, hunched forward-leaning stance, "
            "gold-trimmed leather chestplate, axe in hand, banner pole on back, "
            "side-on view, gritty pixel art, mud-and-rust color palette"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, blurry, high-resolution detail, "
            "fantasy elf, pointed ears, clean smiling face, bright neon, "
            "cute style, chibi, anime, modern weapons"
        ),
    },
    "berserker": {
        "description": (
            "Orc berserker, BARE-CHESTED, lean and sinewy, wild dark hair "
            "with blood-painted tips, forward-leaning aggressive stance, "
            "two-handed axe held wide, side-on view, dark green skin with "
            "warm undertone, gritty pixel art"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, armor on chest, calm pose, "
            "clean face, fantasy hero, bright colors, anime, chibi"
        ),
    },
    "brute": {
        "description": (
            "Massive orc brute, EXTREMELY WIDE SHOULDERS, small head set low "
            "between shoulders, club and wooden shield, planted stance, "
            "leather and rust-iron armor, gritty pixel art, side-on view"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, lean build, agile pose, "
            "tall thin figure, elven, bright colors, anime, chibi"
        ),
    },
    "archer": {
        "description": (
            "Tall lean orc archer, small alert head, bow drawn one arm "
            "extended forward, quiver of arrows on back, dark green skin, "
            "side-on view, gritty pixel art, leather armor"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, broad shoulders, heavy armor, "
            "melee weapon, chibi, anime, bright colors"
        ),
    },
    "cleaver": {
        "description": (
            "Orc cleaver butcher, medium build, one arm raised high holding "
            "a heavy butcher cleaver dripping with old blood, leather apron, "
            "side-on view, gritty pixel art"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, lean archer, ranged weapon, "
            "clean apron, anime, chibi, bright colors"
        ),
    },
    "shaman": {
        "description": (
            "Orc shaman witch-doctor, BONE CROWN on head with two spike "
            "bones protruding upward, holding bone staff with glowing green "
            "magic crystal, draped ritual cloth body, magic green sigil on "
            "chest, side-on view, gritty pixel art"
        ),
        "negative_description": (
            "anti-aliasing, smooth gradient, modern clothing, smiling face, "
            "fairy, fantasy elf wizard, bright colors, anime, chibi"
        ),
    },
}

ENEMY_PROMPTS = {
    "bandit-thug": {
        "description": (
            "Desperate human bandit thug, dirty pale skin, ragged tunic, "
            "rusty knife, slouched posture, side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, smooth gradient, anime, chibi, heroic pose",
    },
    "bandit-archer": {
        "description": (
            "Thin human bandit archer, dirty hair, bow drawn, quiver on back, "
            "ragged dark clothing, side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, smooth gradient, anime, heavy armor",
    },
    "bandit-captain": {
        "description": (
            "Human bandit captain, wiry build, red bandana, sword and dark "
            "chestplate, gold insignia, side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, smooth gradient, anime, clean uniform, knight",
    },
    "farmhand": {
        "description": (
            "Frightened human farmhand, pale skin, simple tunic, pitchfork, "
            "side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, heroic pose, armor",
    },
    "village-guard": {
        "description": (
            "Human village watch guard, mail and helmet, stoic stance, "
            "club at side, side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, fantasy hero, plate armor",
    },
    "hedge-witch": {
        "description": (
            "Hedge witch, pointed dark hat, dark robe, glowing green eyes, "
            "side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, fairy, bright colors, smiling",
    },
    "mastiff": {
        "description": (
            "War mastiff dog, low broad body, muscular, four legs, dark fur, "
            "spiked collar, snarling, side view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, cute puppy, cartoon",
    },
    "hunter": {
        "description": (
            "Forest hunter human, leather cap, bow drawn, quiver of arrows, "
            "side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, plate armor, magic",
    },
    "veteran-mercenary": {
        "description": (
            "Veteran human mercenary, scarred face, cold-steel helmet and "
            "mail, sword, gold campaign medals, side-on view, gritty pixel art"
        ),
        "negative_description": "anti-aliasing, anime, clean face, paladin, bright",
    },
    "iron-warden-boss": {
        "description": (
            "MASSIVE iron warden boss enemy, full iron plate armor, helmet "
            "with crest, glowing forge marks on chest plate, imposing wide "
            "stance, twice the size of normal humans, side-on view, "
            "gritty pixel art, ember orange glow accents"
        ),
        "negative_description": "anti-aliasing, anime, paladin, light bright knight, chibi",
    },
}

GEAR_OVERLAY_PROMPTS = {
    # Gear overlays are used with init_image (the base body) + masked inpainting.
    # Description is what to inpaint into the masked area.
    "weapon_iron-sword-common": "iron sword held in right hand, basic blade, leather grip",
    "weapon_twohanded-axe-common": "two-handed iron axe held wide, broad blade",
    "weapon_short-bow-common": "short hunting bow drawn in left hand",
    "weapon_club-common": "spiked wooden club in right hand",
    "weapon_rusty-knife-common": "small rusty knife held low",
    "weapon_cleaver-common": "heavy butcher cleaver dripping old blood",
    "weapon_bone-staff-common": "carved bone staff with small green magic crystal at top",
    "chest_leather-tunic-common": "rough leather tunic covering torso, simple stitching",
    "offhand_wooden-shield-common": "round wooden shield in left hand, weathered planks, iron boss",
    "accessory_warband-banner-uncommon": "warband banner on tall pole strapped to back, red cloth with gold sigil",
}


def archetype_prompt(archetype_id: str) -> dict:
    if archetype_id in ARCHETYPE_PROMPTS:
        return ARCHETYPE_PROMPTS[archetype_id]
    raise KeyError(f"No prompt defined for archetype '{archetype_id}'")


def enemy_prompt(enemy_id: str) -> dict:
    if enemy_id in ENEMY_PROMPTS:
        return ENEMY_PROMPTS[enemy_id]
    raise KeyError(f"No prompt defined for enemy '{enemy_id}'")


def gear_prompt(gear_key: str) -> str:
    if gear_key in GEAR_OVERLAY_PROMPTS:
        return GEAR_OVERLAY_PROMPTS[gear_key]
    raise KeyError(f"No prompt defined for gear '{gear_key}'")
