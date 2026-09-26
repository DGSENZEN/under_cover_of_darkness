#!/usr/bin/env python3
"""Turns the sound pack's recordings into the game's sound effects.

    python3 tools/prepare_sfx.py [path to "Free Fantasy SFX Pack By TomMusic"]

Every entry in SOUNDS below takes a slice of one recording, folds it to mono
(the game places it in 3D), fades its ends, and writes it to audio/sfx/ under
the name the game plays it by (see scripts/Audio/Sfx.gd). The variations of
one sound are matched in loudness, so a random pick is never suddenly louder;
how loud each sound plays in the mix is Sfx.gd's GAIN table.

The slices start where the sound starts to matter. A sword swing's loudest
moment sits a few hundredths of a second in, where the blade is fastest on
screen; an arrow's thunk sits at the start, where it hits. The pack's files
have up to 0.2 s of lead-in, which in a game reads as lag.

A slice given as None, None is found on its own: from just before the sound
starts to where it has died away (auto_bounds). The pack's footsteps, doors
and torches are cut that way.

The pack's ambience loops are copied whole to audio/ambience/ (they loop on
their own; Ambience.gd plays them).

The rest comes from free packs off the web (CC0 but for two, credited in
CREDITS.md), unpacked under ~/Downloads/AUCOD Web SFX/ (WEB below), each in a
folder named after its archive: Kenney's Impact Sounds and RPG Audio, and from
OpenGameArt HaelDB's yelling sounds, artisticdude's swishes, qubodup's
impacts, Zane Little's deep bone breaks, rubberduck's 80 RPG, 100 and
breaking/falling packs, Julie Damsgaard's dull explosion, congusbongus's
footsteps (CC-BY 3.0) and tcarisland's orchestral stinger (CC-BY 4.0).

Needs ffmpeg and numpy.
"""

import os
import re
import subprocess
import sys
import tempfile

import numpy as np

RATE = 44100
PACK = os.path.expanduser("~/Downloads/Free Fantasy SFX Pack By TomMusic")
ATTACKS = "WAV Files/SFX/Attacks"
SWORD = ATTACKS + "/Sword Attacks Hits and Blocks/"
BOW = ATTACKS + "/Bow Attacks Hits and Blocks/"
FOOT = "WAV Files/SFX/Footsteps/"
DOORS = "WAV Files/SFX/Doors Gates and Chests/"
TORCH = "WAV Files/SFX/Torch/"
CRAFT = "WAV Files/SFX/Chopping and Mining/"
LOOPS = "OGG Files/BGS Loops/"
WEB = os.path.expanduser("~/Downloads/AUCOD Web SFX")


def W(path):
    """A file in the web packs (absolute, so it ignores the pack path)."""
    return os.path.join(WEB, path)


KENNEY_IMPACT = "kenney_impact-sounds/Audio/"
KENNEY_RPG = "kenney_rpg-audio/Audio/"
YELLS = "yelling_sounds/yelling sounds/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "sfx")
AMBIENCE_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "ambience")
PEAK_LIMIT_DB = -1.0

# (game name, recording, start s, end s, fade-out s)
SOUNDS = [
    # A blade cutting the air: the player's swings (pitched per weapon) and
    # the guards'.
    ("whoosh_1", SWORD + "Sword Attack 1.wav", 0.105, 0.450, 0.09),
    ("whoosh_2", SWORD + "Sword Attack 2.wav", 0.115, 0.445, 0.09),
    ("whoosh_3", SWORD + "Sword Attack 3.wav", 0.205, 0.460, 0.08),
    # Steel into a body.
    ("flesh_1", SWORD + "Sword Impact Hit 1.wav", 0.0, 0.450, 0.08),
    ("flesh_2", SWORD + "Sword Impact Hit 2.wav", 0.0, 0.470, 0.08),
    ("flesh_3", SWORD + "Sword Impact Hit 3.wav", 0.0, 0.450, 0.08),
    # Steel on steel: a blow caught on a blade.
    ("clang_1", SWORD + "Sword Blocked 1.wav", 0.0, 0.500, 0.08),
    ("clang_2", SWORD + "Sword Blocked 2.wav", 0.0, 0.500, 0.08),
    ("clang_3", SWORD + "Sword Blocked 3.wav", 0.0, 0.300, 0.06),
    # A blow turned aside at the last instant.
    ("parry_1", SWORD + "Sword Parry 1.wav", 0.010, 0.250, 0.06),
    ("parry_2", SWORD + "Sword Parry 2.wav", 0.010, 0.250, 0.06),
    ("parry_3", SWORD + "Sword Parry 3.wav", 0.010, 0.250, 0.06),
    # Drawing and sheathing: the slide starts part way, so it seats while the
    # other hand is still reaching.
    ("blade_draw_1", SWORD + "Sword Unsheath 1.wav", 0.100, 0.620, 0.10),
    ("blade_draw_2", SWORD + "Sword Unsheath 2.wav", 0.100, 0.620, 0.10),
    ("sheath_1", SWORD + "Sword Sheath 1.wav", 0.200, 0.700, 0.08),
    ("sheath_2", SWORD + "Sword Sheath 2.wav", 0.200, 0.700, 0.08),
    # The bow. Each "Bow Attack" is a creak, then the release: the creak is
    # the draw, the release is the loose.
    ("bow_draw_1", BOW + "Bow Attack 2.wav", 0.0, 0.205, 0.02),
    ("bow_draw_2", BOW + "Bow Attack 1.wav", 0.0, 0.135, 0.02),
    ("twang_1", BOW + "Bow Attack 1.wav", 0.150, 0.340, 0.06),
    ("twang_2", BOW + "Bow Attack 2.wav", 0.230, 0.400, 0.05),
    # An arrow into the world, and into a man.
    ("arrow_thunk_1", BOW + "Bow Blocked 1.wav", 0.030, 0.500, 0.10),
    ("arrow_thunk_2", BOW + "Bow Blocked 2.wav", 0.185, 0.580, 0.10),
    ("arrow_thunk_3", BOW + "Bow Blocked 3.wav", 0.185, 0.600, 0.10),
    ("arrow_flesh_1", BOW + "Bow Impact Hit 1.wav", 0.030, 0.550, 0.10),
    ("arrow_flesh_2", BOW + "Bow Impact Hit 2.wav", 0.160, 0.620, 0.10),
    ("arrow_flesh_3", BOW + "Bow Impact Hit 3.wav", 0.175, 0.620, 0.10),
    ("bow_out", BOW + "Bow Take Out 1.wav", 0.0, 0.840, 0.08),
    ("bow_away", BOW + "Bow Put Away 1.wav", 0.0, 0.950, 0.10),
]

# Feet, on each floor the pack has: yours (soft boots) and a guard's (mail
# over them: the "Chain" takes), at a walk and at a run, and pushing off and
# coming down. Grass is walked on as dirt.
for _surface in ["Stone", "Wood", "Dirt", "Water"]:
    _s = _surface.lower()

    for _i in range(1, 6):
        SOUNDS.append(("step_%s_%d" % (_s, _i), FOOT + "%s/%s Walk %d.wav" % (_surface, _surface, _i), None, None, 0.05))
        SOUNDS.append(("step_%s_run_%d" % (_s, _i), FOOT + "%s/%s Run %d.wav" % (_surface, _surface, _i), None, None, 0.05))
        SOUNDS.append(("step_%s_chain_%d" % (_s, _i), FOOT + "%s/%s Chain Walk %d.wav" % (_surface, _surface, _i), None, None, 0.05))
        SOUNDS.append(("step_%s_chain_run_%d" % (_s, _i), FOOT + "%s/%s Chain Run %d.wav" % (_surface, _surface, _i), None, None, 0.05))

    SOUNDS.append(("jump_%s" % _s, FOOT + "%s/%s Jump.wav" % (_surface, _surface), None, None, 0.05))
    SOUNDS.append(("land_%s" % _s, FOOT + "%s/%s Land.wav" % (_surface, _surface), None, None, 0.05))
    SOUNDS.append(("land_%s_chain" % _s, FOOT + "%s/%s Chain Land.wav" % (_surface, _surface), None, None, 0.05))

SOUNDS += [
    # Doors, locks and chests.
    ("door_open_1", DOORS + "Door Open 1.wav", None, None, 0.12),
    ("door_open_2", DOORS + "Door Open 2.wav", None, None, 0.12),
    ("door_close_1", DOORS + "Door Close 1.wav", None, None, 0.1),
    ("door_close_2", DOORS + "Door Close 2.wav", None, None, 0.1),
    ("unlock", DOORS + "Lock Unlock.wav", None, None, 0.1),
    ("chest_open_1", DOORS + "Chest Open 1.wav", None, None, 0.12),
    ("chest_open_2", DOORS + "Chest Open 2.wav", None, None, 0.12),
    ("chest_close_1", DOORS + "Chest Close 1.wav", None, None, 0.1),
    ("chest_close_2", DOORS + "Chest Close 2.wav", None, None, 0.1),
    ("gate_open", DOORS + "Gate Open.wav", None, None, 0.1),
    ("gate_close", DOORS + "Gate Close.wav", None, None, 0.1),
    # Fire: a torch lit (a powder barrel's fuse, a man set alight), and the
    # crackle of one burning, in short takes out of the torch's loop.
    ("ignite_1", TORCH + "Light Torch 1.wav", None, None, 0.2),
    ("ignite_2", TORCH + "Light Torch 2.wav", None, None, 0.1),
    ("burning_1", TORCH + "Torch Loop.wav", 1.0, 1.9, 0.25),
    ("burning_2", TORCH + "Torch Loop.wav", 3.1, 4.0, 0.25),
    ("burning_3", TORCH + "Torch Loop.wav", 5.4, 6.3, 0.25),
    ("burning_4", TORCH + "Torch Loop.wav", 7.7, 8.6, 0.25),
    # A wooden club's dull knock: blows that do not cut (a straw man, a
    # blackjack, a boot on a wall).
    ("thud_1", TORCH + "Torch Impact 1.wav", None, None, 0.08),
    ("thud_2", TORCH + "Torch Impact 2.wav", None, None, 0.08),
    # A blade biting into wood (the axe's chop), and glancing off stone (the
    # pick): a sword that met a door or a wall.
    ("thud_wood_1", CRAFT + "chop 1.wav", 0.19, 0.50, 0.08),
    ("thud_wood_2", CRAFT + "chop 2.wav", 0.015, 0.09, 0.03),
    ("thud_wood_3", CRAFT + "chop 3.wav", 0.19, 0.36, 0.06),
    ("thud_wood_4", CRAFT + "chop 4.wav", 0.075, 0.21, 0.05),
    ("clank_1", CRAFT + "mine 1.wav", 0.176, 0.28, 0.05),
    ("clank_2", CRAFT + "mine 2.wav", 0.083, 0.21, 0.05),
    ("clank_3", CRAFT + "mine 3.wav", 0.147, 0.215, 0.03),
    ("clank_4", CRAFT + "mine 4.wav", 0.006, 0.157, 0.05),
    ("clank_5", CRAFT + "mine 5.wav", 0.087, 0.23, 0.05),
]

SOUNDS += [
    # Air: a quick swish (a dodge, a feint, a kick's swing), and the heavier
    # rush laid under a power blow.
    ("whoosh_light_1", W("swishes/swishes/swish-10.wav"), None, None, 0.03),
    ("whoosh_light_2", W("swishes/swishes/swish-11.wav"), None, None, 0.03),
    ("whoosh_light_3", W("swishes/swishes/swish-12.wav"), None, None, 0.03),
    ("whoosh_light_4", W("swishes/swishes/swish-13.wav"), None, None, 0.03),
    ("whoosh_heavy_1", W("swishes/swishes/swish-3.wav"), None, None, 0.05),
    ("whoosh_heavy_2", W("swishes/swishes/swish-8.wav"), None, None, 0.05),
    ("whoosh_heavy_3", W("swishes/swishes/swish-4.wav"), None, None, 0.05),
    # Flesh, heavily: wet meat struck (under a heavy cut; hacking at a body).
    ("flesh_heavy_1", W("qubodupImpact/qubodupImpact/qubodupImpactMeat01.ogg"), None, None, 0.1),
    ("flesh_heavy_2", W("qubodupImpact/qubodupImpact/qubodupImpactMeat02.ogg"), None, None, 0.1),
    # Bone giving way: a limb or a head coming off. Cut from just before the
    # crack, so it lands with the blow.
    ("bone_crack_1", W("deep_breaks/Deep Break 1.wav"), 0.124, None, 0.1),
    ("bone_crack_2", W("deep_breaks/Deep Break 2.wav"), 0.162, None, 0.1),
    ("bone_crack_3", W("deep_breaks/Deep Break 3.wav"), 0.246, None, 0.1),
    ("bone_crack_4", W("deep_breaks/Deep Break 4.wav"), 0.465, None, 0.1),
    ("bone_crack_5", W("deep_breaks/Deep Break 6.wav"), 0.347, None, 0.1),
    ("bone_crack_6", W("deep_breaks/Deep Break 7.wav"), 0.271, None, 0.1),
    ("bone_crack_7", W("deep_breaks/Deep Break 8.wav"), 0.167, None, 0.1),
    ("bone_crack_8", W("deep_breaks/Deep Break 9.wav"), 0.065, None, 0.08),
    # A boot into a body; bodies hitting the floor.
    ("kick_1", W(KENNEY_IMPACT + "impactPunch_heavy_000.ogg"), None, None, 0.06),
    ("kick_2", W(KENNEY_IMPACT + "impactPunch_heavy_001.ogg"), None, None, 0.06),
    ("kick_3", W(KENNEY_IMPACT + "impactPunch_heavy_002.ogg"), None, None, 0.06),
    ("kick_4", W(KENNEY_IMPACT + "impactPunch_heavy_003.ogg"), None, None, 0.06),
    ("kick_5", W(KENNEY_IMPACT + "impactPunch_heavy_004.ogg"), None, None, 0.06),
    ("body_fall_1", W(KENNEY_IMPACT + "impactSoft_heavy_000.ogg"), None, None, 0.08),
    ("body_fall_2", W(KENNEY_IMPACT + "impactSoft_heavy_001.ogg"), None, None, 0.08),
    ("body_fall_3", W(KENNEY_IMPACT + "impactSoft_heavy_002.ogg"), None, None, 0.08),
    ("body_fall_4", W(KENNEY_IMPACT + "impactSoft_heavy_003.ogg"), None, None, 0.08),
    ("body_fall_5", W(KENNEY_IMPACT + "impactSoft_heavy_004.ogg"), None, None, 0.08),
    # A guard knocked aside: iron.
    ("guard_break_1", W(KENNEY_IMPACT + "impactMetal_heavy_000.ogg"), None, None, 0.05),
    ("guard_break_2", W(KENNEY_IMPACT + "impactMetal_heavy_001.ogg"), None, None, 0.05),
    ("guard_break_3", W(KENNEY_IMPACT + "impactMetal_heavy_003.ogg"), None, None, 0.05),
    # The glint: a thin ring of steel.
    ("ting_1", W(KENNEY_IMPACT + "impactPlate_light_000.ogg"), None, None, 0.08),
    ("ting_2", W(KENNEY_IMPACT + "impactPlate_light_002.ogg"), None, None, 0.08),
    ("ting_3", W(KENNEY_IMPACT + "impactPlate_light_003.ogg"), None, None, 0.08),
    # Carpet and metal underfoot; a boot scuffing stone.
    ("step_carpet_1", W(KENNEY_IMPACT + "footstep_carpet_000.ogg"), None, None, 0.03),
    ("step_carpet_2", W(KENNEY_IMPACT + "footstep_carpet_001.ogg"), None, None, 0.03),
    ("step_carpet_3", W(KENNEY_IMPACT + "footstep_carpet_003.ogg"), None, None, 0.03),
    ("step_metal_1", W("footsteps_congusbongus/footsteps/metal/0.ogg"), None, None, 0.05),
    ("step_metal_2", W("footsteps_congusbongus/footsteps/metal/1.ogg"), None, None, 0.05),
    ("step_metal_3", W("footsteps_congusbongus/footsteps/metal/2.ogg"), None, None, 0.05),
    ("step_metal_4", W("footsteps_congusbongus/footsteps/metal/3.ogg"), None, None, 0.05),
    ("step_metal_5", W("footsteps_congusbongus/footsteps/metal/4.ogg"), None, None, 0.05),
    ("step_metal_6", W("footsteps_congusbongus/footsteps/metal/5.ogg"), None, None, 0.05),
    ("scuff_1", W(KENNEY_IMPACT + "footstep_concrete_000.ogg"), None, None, 0.03),
    ("scuff_2", W(KENNEY_IMPACT + "footstep_concrete_003.ogg"), None, None, 0.03),
    ("scuff_3", W(KENNEY_IMPACT + "footstep_concrete_004.ogg"), None, None, 0.03),
    # Cloth and leather: moving, taking hold, picking up.
    ("cloth_1", W(KENNEY_RPG + "cloth1.ogg"), None, None, 0.05),
    ("cloth_2", W(KENNEY_RPG + "cloth2.ogg"), None, None, 0.05),
    ("cloth_3", W(KENNEY_RPG + "cloth3.ogg"), None, None, 0.05),
    ("cloth_4", W(KENNEY_RPG + "cloth4.ogg"), None, None, 0.05),
    ("grab_1", W(KENNEY_RPG + "handleSmallLeather.ogg"), None, None, 0.05),
    ("grab_2", W(KENNEY_RPG + "handleSmallLeather2.ogg"), None, None, 0.05),
    ("pickup_1", W(KENNEY_RPG + "beltHandle1.ogg"), None, None, 0.05),
    ("pickup_2", W(KENNEY_RPG + "beltHandle2.ogg"), None, None, 0.05),
    # Rope and chain; a rope giving way.
    ("creak_rope_1", W(KENNEY_RPG + "creak1.ogg"), None, None, 0.08),
    ("creak_rope_2", W(KENNEY_RPG + "creak2.ogg"), None, None, 0.08),
    ("creak_rope_3", W(KENNEY_RPG + "creak3.ogg"), None, None, 0.08),
    ("rattle_chain_1", W("80-CC0-RPG-SFX/chain_01.ogg"), None, None, 0.06),
    ("rattle_chain_2", W("80-CC0-RPG-SFX/chain_02.ogg"), None, None, 0.06),
    ("rattle_chain_3", W("80-CC0-RPG-SFX/chain_03.ogg"), None, None, 0.08),
    ("rope_snap_1", W("sfx_breaking_and_falling/bfh1_wood_breaking_01.ogg"), None, None, 0.08),
    ("rope_snap_2", W("sfx_breaking_and_falling/bfh1_wood_breaking_02.ogg"), None, None, 0.08),
    # What you carry: coin, keys; a locked door tried.
    ("coins_1", W(KENNEY_RPG + "handleCoins.ogg"), None, None, 0.05),
    ("coins_2", W(KENNEY_RPG + "handleCoins2.ogg"), None, None, 0.05),
    ("coins_3", W("80-CC0-RPG-SFX/item_coins_01.ogg"), None, None, 0.05),
    ("keys_1", W("100-CC0-SFX/key_open_01.ogg"), None, None, 0.05),
    ("keys_2", W("100-CC0-SFX/key_open_02.ogg"), None, None, 0.05),
    ("door_rattle_1", W(KENNEY_RPG + "metalLatch.ogg"), None, None, 0.05),
    ("door_rattle_2", W("80-CC0-RPG-SFX/lock_01.ogg"), None, None, 0.05),
    ("door_rattle_3", W("80-CC0-RPG-SFX/lock_03.ogg"), None, None, 0.05),
    # The powder barrel.
    ("explosion", W("single/dull_explosion.wav"), 0.0, 3.0, 0.6),
    # Voices. Yours (the grunt of being cut); theirs: cut, dying, the
    # brute's roar, the grunt of a low sweep.
    ("hurt_1", W(YELLS + "3grunt3.wav"), None, None, 0.08),
    ("hurt_2", W(YELLS + "3grunt4.wav"), None, None, 0.08),
    ("hurt_3", W(YELLS + "3grunt5.wav"), None, None, 0.08),
    ("pain_1", W(YELLS + "1yell13.wav"), None, None, 0.08),
    ("pain_2", W(YELLS + "1yell14.wav"), None, None, 0.08),
    ("pain_3", W(YELLS + "1yell9.wav"), None, None, 0.08),
    ("pain_4", W(YELLS + "1yell10.wav"), None, None, 0.08),
    ("pain_5", W(YELLS + "2yell10.wav"), None, None, 0.08),
    ("pain_6", W(YELLS + "3yell3.wav"), None, None, 0.08),
    ("death_1", W(YELLS + "3yell1.wav"), None, None, 0.25),
    ("death_2", W(YELLS + "3yell9.wav"), None, None, 0.25),
    ("death_3", W(YELLS + "3yell6.wav"), None, None, 0.25),
    ("death_4", W(YELLS + "yell10.wav"), None, None, 0.25),
    ("death_5", W(YELLS + "yell11.wav"), None, None, 0.25),
    ("death_6", W(YELLS + "2yell4.wav"), None, None, 0.25),
    ("roar_1", W(YELLS + "yell4.wav"), None, None, 0.15),
    ("roar_2", W(YELLS + "yell7.wav"), None, None, 0.15),
    ("roar_3", W(YELLS + "3yell14.wav"), None, None, 0.15),
    ("grunt_1", W(YELLS + "3grunt1.wav"), None, None, 0.08),
    ("grunt_2", W(YELLS + "2yell9.wav"), None, None, 0.08),
    ("grunt_3", W(YELLS + "3yell4.wav"), None, None, 0.08),
    # The music of being noticed: the stinger's low opening swell, and the
    # chord it lands on.
    ("sting_suspicious", W("single/orchestral_stinger_dramatic_entrance.wav"), 0.0, 1.35, 0.45),
    ("sting_combat", W("single/orchestral_stinger_dramatic_entrance.wav"), 1.62, 3.3, 0.6),
]

# The places, as loops: indoors at night, a cave, a forest at night (and
# each of them in rain).
AMBIENCES = [
    ("interior_night", LOOPS + "Interior Night/Inside Night.ogg"),
    ("interior_night_rain", LOOPS + "Interior Night/Inside Night Rain.ogg"),
    ("cave", LOOPS + "Cave/Cave.ogg"),
    ("cave_rain", LOOPS + "Cave/Cave Rain.ogg"),
    ("forest_night", LOOPS + "Forest Night/Forest Night.ogg"),
    ("forest_night_rain", LOOPS + "Forest Night/Forest Night Rain.ogg"),
]


# Blows are squeezed a little: the first spike of an impact is far louder
# than the body behind it, so at the same peak they sounded thin. A gentle
# compressor brings the body up; nothing else is touched.
PUNCHED = {"flesh", "clang", "parry", "arrow_flesh", "arrow_thunk", "twang"}


def decode(path, start, end):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    stereo = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    mono = stereo.mean(axis=1)

    if start is None or end is None:
        first, last = auto_bounds(mono)
        start = first / RATE if start is None else start
        end = last / RATE if end is None else end

    return mono[int(start * RATE):int(end * RATE)]


def auto_bounds(x, lead=0.004, tail=0.04, onset_db=-30.0, floor_db=-42.0):
    """Where a recording's sound is: from `lead` before it first rises within
    `onset_db` of its peak, to `tail` after its 10 ms envelope last sits above
    `floor_db` of the peak."""
    a = np.abs(x)
    peak = max(a.max(), 1e-9)
    onset = int(np.argmax(a > peak * 10 ** (onset_db / 20)))
    w = max(int(0.01 * RATE), 1)
    env = np.convolve(a, np.ones(w) / w, mode="same")
    above = np.where(env > peak * 10 ** (floor_db / 20))[0]
    last = int(above[-1]) if len(above) else len(x) - 1
    return max(onset - int(lead * RATE), 0), min(last + int(tail * RATE), len(x))


def fade(x, fade_in, fade_out):
    x = x.copy()
    n_in = min(int(fade_in * RATE), len(x))
    n_out = min(int(fade_out * RATE), len(x))

    if n_in > 0:
        x[:n_in] *= np.linspace(0.0, 1.0, n_in) ** 2

    if n_out > 0:
        x[-n_out:] *= np.cos(np.linspace(0.0, np.pi * 0.5, n_out)) ** 2

    return x


def compress(x, threshold_db=-16.0, ratio=4.0, knee_db=6.0, lookahead=0.0015, release=0.06):
    """Look-ahead compressor: the envelope sees each spike before it arrives,
    so the spike itself is turned down (a plain compressor lets it through
    and squeezes only the body, which is the wrong way round here)."""
    reach = max(int(lookahead * RATE), 1)
    padded = np.pad(np.abs(x), reach)
    peak = np.lib.stride_tricks.sliding_window_view(padded, 2 * reach + 1).max(axis=1)
    r = np.exp(-1.0 / (release * RATE))
    env = np.empty_like(peak)
    e = 0.0

    for i, v in enumerate(peak):
        e = v if v > e else r * e + (1 - r) * v
        env[i] = e

    db = 20 * np.log10(np.maximum(env, 1e-9))
    over = db - threshold_db
    # Soft knee: the ratio eases in over knee_db around the threshold.
    reduce = np.where(
        over <= -knee_db / 2, 0.0,
        np.where(over >= knee_db / 2, over * (1 - 1 / ratio),
                 (1 - 1 / ratio) * (over + knee_db / 2) ** 2 / (2 * knee_db)))
    return x * 10 ** (-reduce / 20)


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-", path],
        input=pcm.tobytes(), check=True,
    )


def loudness(x):
    """Momentary loudness (EBU R128, LUFS): the loudest 0.4 s, as heard."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
        temp = handle.name

    try:
        write_wav(temp, x)
        log = subprocess.run(
            ["ffmpeg", "-nostats", "-i", temp, "-af", "apad=pad_dur=0.4,ebur128", "-f", "null", "-"],
            capture_output=True, text=True,
        ).stderr
    finally:
        os.remove(temp)

    values = [float(v) for v in re.findall(r"M:\s*(-?[0-9.]+)", log)]
    return max(values) if values else -99.0


def main():
    pack = sys.argv[1] if len(sys.argv) > 1 else PACK
    os.makedirs(OUT, exist_ok=True)
    groups = {}

    for name, source, start, end, fade_out in SOUNDS:
        x = fade(decode(os.path.join(pack, source), start, end), 0.006, fade_out)
        group = re.sub(r"_\d+$", "", name)
        # Every slice as loud as it can be without clipping, then measured.
        x *= 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)

        if group in PUNCHED:
            x = compress(x)
            x *= 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)

        groups.setdefault(group, []).append([name, x, loudness(x)])

    # Variations match the quietest of them.
    for group, members in groups.items():
        level = min(m[2] for m in members)

        for name, x, own in members:
            write_wav(os.path.join(OUT, name + ".wav"), x * 10 ** ((level - own) / 20))

        print("%-12s %d file(s), %.1f LUFS" % (group, len(members), level))

    os.makedirs(AMBIENCE_OUT, exist_ok=True)

    for name, source in AMBIENCES:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(pack, source), "-c", "copy",
                        os.path.join(AMBIENCE_OUT, name + ".ogg")], check=True)
        print("%-12s ambience loop" % name)


if __name__ == "__main__":
    main()
