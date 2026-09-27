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

The rest comes from free packs off the web, unpacked under
~/Downloads/AUCOD Web SFX/ (WEB below), each in a folder named after its
archive (CC0 but for one, credited in CREDITS.md):
Kenney's Impact Sounds and RPG Audio, and from OpenGameArt HaelDB's yelling
sounds, artisticdude's swishes, qubodup's
impacts, Zane Little's deep bone breaks, rubberduck's 80 RPG, 100 and
breaking/falling packs, Julie Damsgaard's dull explosion, congusbongus's
footsteps (CC-BY 3.0); for the duelist cicifyre's female voices and congusbongus's female screams; for the
score Mixkit's cinematic effects (under Mixkit's free licence) and William
Hector's war drums.

The score (MUSIC below) is kept in stereo: its stings go to audio/sfx/ like
any sound, its loops to audio/music/, each cut to whole bars of the drums'
130 bpm (the heartbeat and the brass exactly one and two bars, the drums
their own eight), so the layers stay in step however long they play.

The guards' voices (VOICES below: their murmur of talk, laughs, sighs,
coughs, grunts, breathing, snores, a gasp) come from the Sonniss GDC bundles
and free packs under ~/Downloads/AUCOD Web SFX/voices/ (credited in
CREDITS.md). A voice entry is cut one of four ways: "whole" (each file from
where its sound starts to where it dies away), "split" (the separate sounds in
one take: single breaths, snores, coughs), "stretch" (long stretches of talk
the game plays a part of: GuardVoice's murmur), or "join" (short phrases put
one after another into one stretch of talk).

    python3 tools/prepare_sfx.py --only=murmur,laugh,...

cuts only those groups and leaves every other file as it is;

    python3 tools/prepare_sfx.py --fire

makes only the fire beds (FIRE_LOOPS). The lights' sounds (CRACKLES,
LAYERED) are cut from the NOX Essentials (CC0), the 400 Sounds Pack and
FilmCow's recorded effects (approved by the user), the TomMusic torch and
Kenney's RPG audio; a layered sound is several recordings laid together.

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
FEMALE = "RPG_Voice_Starter_Pack/RPG Voice Starter Pack/Type 3/"
MIXKIT = "mixkit/"
MUSIC_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")
# The drums' tempo: every loop of the score is whole bars of it.
BAR = 4 * 60.0 / 130.0
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
    # Voices. Yours is the third man's in the pack: the grunt of being cut,
    # and of effort (a heavy blow, a kick, hauling yourself up). The guards
    # speak with the others: cut, dying, the brute's roar, the grunt of a low
    # sweep.
    ("hurt_1", W(YELLS + "3grunt3.wav"), None, None, 0.08),
    ("hurt_2", W(YELLS + "3grunt4.wav"), None, None, 0.08),
    ("hurt_3", W(YELLS + "3grunt5.wav"), None, None, 0.08),
    ("effort_1", W(YELLS + "3grunt1.wav"), None, None, 0.08),
    ("effort_2", W(YELLS + "3grunt2.wav"), None, None, 0.08),
    ("effort_3", W(YELLS + "3grunt6.wav"), None, None, 0.1),
    ("pain_1", W(YELLS + "1yell13.wav"), None, None, 0.08),
    ("pain_2", W(YELLS + "1yell14.wav"), None, None, 0.08),
    ("pain_3", W(YELLS + "1yell9.wav"), None, None, 0.08),
    ("pain_4", W(YELLS + "1yell10.wav"), None, None, 0.08),
    ("pain_5", W(YELLS + "2yell10.wav"), None, None, 0.08),
    ("pain_6", W(YELLS + "2yell1.wav"), None, None, 0.08),
    ("death_1", W(YELLS + "yell10.wav"), None, None, 0.25),
    ("death_2", W(YELLS + "yell11.wav"), None, None, 0.25),
    ("death_3", W(YELLS + "2yell4.wav"), None, None, 0.25),
    ("death_4", W(YELLS + "yell2.wav"), None, None, 0.25),
    ("death_5", W(YELLS + "yell5.wav"), None, None, 0.25),
    ("death_6", W(YELLS + "2yell11.wav"), None, None, 0.25),
    ("roar_1", W(YELLS + "yell4.wav"), None, None, 0.15),
    ("roar_2", W(YELLS + "yell7.wav"), None, None, 0.15),
    ("roar_3", W(YELLS + "yell12.wav"), None, None, 0.12),
    ("grunt_1", W(YELLS + "2yell9.wav"), None, None, 0.08),
    ("grunt_2", W(YELLS + "1yell15.wav"), None, None, 0.08),
    ("grunt_3", W(YELLS + "2yell3.wav"), None, None, 0.08),
    # Your own heart, when you are near done (Sfx: faster and louder as your
    # health goes): single beats out of the score's heartbeat.
    ("heartbeat_1", W(MIXKIT + "2630_cinematic_mystery_heartbeat_transition.wav"), 1.66, 2.1, 0.08),
    ("heartbeat_2", W(MIXKIT + "2630_cinematic_mystery_heartbeat_transition.wav"), 2.11, 2.6, 0.08),
    ("heartbeat_3", W(MIXKIT + "2630_cinematic_mystery_heartbeat_transition.wav"), 2.6, 3.06, 0.08),
    # What you carry, moving with you at a run: belt and buckle.
    ("gear_1", W(KENNEY_RPG + "clothBelt.ogg"), None, None, 0.05),
    ("gear_2", W(KENNEY_RPG + "clothBelt2.ogg"), None, None, 0.05),
    ("gear_3", W(KENNEY_RPG + "metalClick.ogg"), None, None, 0.04),
    # The duelist: a woman's voice (the pack's third, and lowest): the cry
    # of a blow put in, of being cut; screams for her death.
    ("grunt_f_1", W(FEMALE + "attack1.wav"), None, None, 0.06),
    ("grunt_f_2", W(FEMALE + "attack2.wav"), None, None, 0.06),
    ("grunt_f_3", W(FEMALE + "attack3.wav"), None, None, 0.06),
    ("roar_f_1", W(FEMALE + "attack2.wav"), None, None, 0.06),
    ("roar_f_2", W(FEMALE + "attack3.wav"), None, None, 0.06),
    ("pain_f_1", W(FEMALE + "damaged1.wav"), None, None, 0.06),
    ("pain_f_2", W(FEMALE + "damaged2.wav"), None, None, 0.06),
    ("pain_f_3", W(FEMALE + "damaged3.wav"), None, None, 0.06),
    ("death_f_1", W("female_screams/1.ogg"), None, None, 0.1),
    ("death_f_2", W("female_screams/2.ogg"), None, None, 0.15),
    ("death_f_3", W("female_screams/3.ogg"), None, None, 0.15),
    ("death_f_4", W("female_screams/4.ogg"), None, None, 0.12),
]

# The guards' voices (GuardVoice): (group, [files under WEB], mode, count,
# fade-out). For "split" the count is how many sounds to take from each file;
# for "stretch" it is the stretch's length in seconds.
ALBA = "voices/oga_alba_mac/alba_mac_universalspurts/"
SONNISS = "voices/sonniss/"
PROTO = "voices/oga_misc/proto-germanic-voices/"
VOICES = [
    # Talk heard as a murmur under the subtitles: a small group speaking in
    # tongues, a man in a made-up tongue, a man in Proto-Germanic.
    ("murmur", [SONNISS + "SH101_Human_SpeakingInTongues_SmallGroup_Fienup_002.wav"], "stretch", 6.0, 0.3),
    ("murmur", [SONNISS + "cartoon voices male made up language 8.wav"], "whole", 0, 0.15),
    ("murmur", [PROTO + n for n in ["acknowledge_01.wav", "acknowledge_02.wav", "ready.wav", "acknowledge_03.wav", "selected_01.wav", "acknowledge_04.wav"]], "join", 0, 0.15),
    ("murmur", [PROTO + n for n in ["annoyed_01.wav", "attack_01.wav", "selected_02.wav", "annoyed_02.wav", "work_complete.wav", "attack_02.wav"]], "join", 0, 0.15),
    ("laugh", [ALBA + "(laugh)_0%d.wav" % i for i in range(1, 5)], "whole", 0, 0.1),
    ("laugh", [SONNISS + "Kieuk,laughter,male,60s,OhioCarolina,heeing,restrained,chuckle,mouthclicks.wav",
               SONNISS + "VOICE of God - Game Phrase - 'Laugh' (intense) 02, DRY.wav",
               SONNISS + "voice_fun_man_character_deep_laugh_11.wav"], "whole", 0, 0.12),
    # A sigh: a long breath out.
    ("sigh", [ALBA + "Phew_0%d.wav" % i for i in range(1, 5)] + [ALBA + "Haa_01.wav"], "whole", 0, 0.12),
    ("sigh_f", ["voices/oga_female/silly_me.ogg"], "whole", 0, 0.12),
    ("cough", [ALBA + "(cough)_0%d.wav" % i for i in range(1, 5)], "whole", 0, 0.08),
    ("cough", ["voices/oga_misc/old-man-cough.flac", "voices/oga_misc/sickness.wav"], "split", 2, 0.08),
    ("spit", [SONNISS + "ALE SPIT HIT FACE_02*.wav"], "split", 2, 0.08),
    ("grunt_effort", [ALBA + "(grunt)_0%d.wav" % i for i in range(1, 5)], "whole", 0, 0.08),
    ("grunt_effort", [SONNISS + "Hand-to-Hand Combat - Vocal Excursion - Male - Powering Up 14.wav",
                      SONNISS + "EMOTE Joshua, Man, Pain Hurt Grunt Big 03.wav",
                      "voices/oga_qubodup/slightscreams/slightscream-01.flac",
                      "voices/oga_qubodup/slightscreams/slightscream-02.flac"], "whole", 0, 0.08),
    # "Hm?": a man's eye caught.
    ("hm", [ALBA + "Hmm_0%d.wav" % i for i in range(1, 5)] + [ALBA + "Huh_01.wav", SONNISS + "EMOTE Robert, Man, Curiosity 09, Mic A.wav"], "whole", 0, 0.08),
    # Breathing hard: single breaths out; frightened ones.
    ("breath_heavy", [ALBA + "(breath out)_0%d.wav" % i for i in range(1, 7)], "whole", 0, 0.1),
    ("breath_scared", [SONNISS + "HUMAN BREATH Male_Mouth Inhale and Exhale Like Got Frightened Intermittent _C.wav"], "split", 4, 0.1),
    ("breath_scared", [SONNISS + "scared breath 12.wav"], "whole", 0, 0.1),
    ("breath_scared", [ALBA + "(breathing)_panicked.wav"], "split", 3, 0.1),
    ("yawn", [ALBA + "(yawn)_0%d.wav" % i for i in range(1, 5)], "whole", 0, 0.2),
    ("yawn", [SONNISS + "HUMAN BREATH Male_ Sleepy Yawn_E.wav"], "split", 2, 0.2),
    ("snore", [SONNISS + "Snooring_Man_Close_Voice_Sleep_Human.WAV"], "split", 6, 0.2),
    # A catch of the breath: the moment a man knows.
    ("gasp", [ALBA + "(gasp)_0%d.wav" % i for i in range(1, 5)] + [SONNISS + "VOXScrm_Male in Shock 4_344 Audio_Screaming.wav"], "whole", 0, 0.08),
    ("gasp", [SONNISS + "Scream,Male,Mid Thirties,Mouth Covered,Gasps,Fast,Shriek,Panic.wav"], "split", 2, 0.08),
]

# The score, in stereo (see above). Stings: (name, source, start, end,
# fade-out, reversed). SCORE_LOOPS: (name, source, start, end, kind, argument):
# "crossfade" a free loop, its ends overlapped by `argument` seconds;
# "bars" cut from `start` and stretched or padded to `argument` whole bars.
STINGS = [
    # Noticed, and looking into it: a large swell (the hum rising to its
    # height), or the terror sweep turned round to rise instead of fall.
    ("sting_suspicious_1", W(MIXKIT + "2900_deep_cinematic_wind_hum.wav"), 0.0, 6.4, 1.6, False),
    ("sting_suspicious_2", W(MIXKIT + "677_terror_sweep_of_darkness.wav"), 0.0, 4.4, 0.12, True),
    # Seen: the rush sucked in to a hit, or the sweep of darkness falling.
    ("sting_combat_1", W(MIXKIT + "1469_reverse_cinematic_impact_trailer.wav"), 0.0, 1.6, 0.3, False),
    ("sting_combat_2", W(MIXKIT + "677_terror_sweep_of_darkness.wav"), 0.0, 4.6, 1.0, False),
    # The fight turning for the worse.
    ("sting_escalate_1", W(MIXKIT + "1287_big_cinematic_impact.wav"), 0.2, 4.8, 1.2, False),
    ("sting_escalate_2", W(MIXKIT + "2353_cinematic_drama_riser.wav"), 0.4, 4.0, 1.2, False),
]

SCORE_LOOPS = [
    ("music_drone", W(MIXKIT + "2900_deep_cinematic_wind_hum.wav"), 0.5, 8.4, "crossfade", 2.0),
    # Four beats of the heartbeat, one bar of the drums.
    ("music_pulse", W(MIXKIT + "2630_cinematic_mystery_heartbeat_transition.wav"), 1.674, 3.554, "beats", 1),
    ("music_drums", W("single/horde_war_drums_by_william_hector.wav"), 0.0, None, "whole", 8),
    # A brass stab on every other downbeat.
    ("music_severe", W(MIXKIT + "1093_cinematic_transition_brass_hum.wav"), 0.31, 3.7, "bars", 2),
]

# The places, as loops: indoors at night, a cave, a forest at night (and
# each of them in rain).
AMBIENCES = [
    # A torch burning (Torch.gd: each one crackles where it is).
    ("torch_loop", "OGG Files/SFX/Torch/Torch Loop.ogg"),
    ("interior_night", LOOPS + "Interior Night/Inside Night.ogg"),
    ("interior_night_rain", LOOPS + "Interior Night/Inside Night Rain.ogg"),
    ("cave", LOOPS + "Cave/Cave.ogg"),
    ("cave_rain", LOOPS + "Cave/Cave Rain.ogg"),
    ("forest_night", LOOPS + "Forest Night/Forest Night.ogg"),
    ("forest_night_rain", LOOPS + "Forest Night/Forest Night Rain.ogg"),
]


# Lights and fire (scripts/Visual/Torch.gd, LightFixture.gd). From the user's
# NOX Essentials (CC0), the 400 Sounds Pack and FilmCow's recorded effects
# (both approved by the user, Sept 27 2026), the TomMusic torch and Kenney.
NOX = os.path.expanduser("~/Downloads/Essentials_Series_NOX_SOUND/Nature_Essentials_NOX_SOUND/")
FOUR_HUNDRED = os.path.expanduser("~/Downloads/400 Sounds Pack/")
FILMCOW = os.path.expanduser("~/Downloads/FilmCow Recorded SFX/")
TOM_TORCH = os.path.join(PACK, TORCH)

# Fire beds, looped whole (NOX made them loops): mono, a low-pass (Hz) and a
# pitch where given, to audio/ambience/<name>.wav (a looping WAV); a length
# (s) cuts a long one short, its end crossfaded into its start.
FIRE_LOOPS = [
    ("fire_small", NOX + "Ambiance_Firecamp_Small_Loop_Mono.wav", None, 1.0, None),
    ("fire_medium", NOX + "Ambiance_Firecamp_Medium_Loop_Mono.wav", None, 1.0, None),
    ("fire_big", NOX + "Ambiance_Fire_Big_Loop_Mono.wav", 5000, 1.0, None),
    # A hearth's chimney draw: a calm wind, dark and slow.
    ("chimney", NOX + "Ambiance_Wind_Calm_Loop_Stereo.wav", 900, 0.7, 12.0),
]

# Crackles: the sharp snaps inside a fire bed, the bed filtered away first
# (a high-pass, Hz), each cut short: (group, sources, takes, high-pass).
CRACKLES = [
    ("crackle", [NOX + "Ambiance_Firecamp_Medium_Loop_Mono.wav", NOX + "Ambiance_Firecamp_Small_Loop_Mono.wav"], 6, 700),
    ("coal_pop", [NOX + "Ambiance_Fire_Big_Loop_Mono.wav"], 4, 300),
]

# Layered: a sound made of several recordings laid together: (name, layers,
# fade-out), each layer (source, start, end, gain dB, offset s, low-pass Hz
# or None, pitch). A start/end of None is found on its own.
LAYERED = [
    ("ignite_torch_1", [(TOM_TORCH + "Light Torch with Starting Loop 1.wav", None, 1.4, 0.0, 0.0, None, 1.0),
                        (FOUR_HUNDRED + "Environment/fire_lighting.wav", None, None, -6.0, 0.0, None, 1.0)], 0.35),
    ("ignite_torch_2", [(TOM_TORCH + "Light Torch with Starting Loop 2.wav", None, 1.4, 0.0, 0.0, None, 1.0),
                        (FOUR_HUNDRED + "Environment/fire_lighting.wav", None, None, -7.0, 0.05, None, 0.94)], 0.35),
    ("snuff_1", [(FOUR_HUNDRED + "Environment/air_burst.wav", None, 0.15, 0.0, 0.0, None, 1.0),
                 (FILMCOW + "gas leak.wav", 0.3, 0.7, -10.0, 0.05, 6000, 1.0)], 0.2),
    ("snuff_2", [(FOUR_HUNDRED + "Environment/air_burst.wav", None, 0.12, 0.0, 0.0, None, 1.12),
                 (FILMCOW + "gas leak.wav", 1.1, 1.5, -11.0, 0.04, 6000, 1.0)], 0.2),
    ("douse_1", [(FOUR_HUNDRED + "Environment/water_splashing.wav", None, 0.5, 0.0, 0.0, None, 1.0),
                 (FILMCOW + "gas leak.wav", 0.2, 1.1, -4.0, 0.08, None, 1.0)], 0.4),
    ("douse_2", [(FOUR_HUNDRED + "Environment/water_splashing.wav", None, 0.5, 0.0, 0.0, None, 0.9),
                 (FILMCOW + "gas leak.wav", 1.0, 1.9, -5.0, 0.06, None, 0.95)], 0.4),
    ("log_settle_1", [(FILMCOW + "footstep on branch heavy.wav", None, None, 0.0, 0.0, None, 0.85),
                      (W(KENNEY_RPG + "chop.ogg"), None, None, -8.0, 0.0, 2000, 0.8)], 0.2),
    ("log_settle_2", [(FILMCOW + "footstep on branch light.wav", None, None, 0.0, 0.0, None, 0.8),
                      (W(KENNEY_RPG + "chop.ogg"), None, None, -9.0, 0.01, 2000, 0.7)], 0.2),
    ("log_settle_3", [(FILMCOW + "footstep on branch heavy.wav", None, None, -1.0, 0.0, None, 0.7),
                      (W(KENNEY_RPG + "chop.ogg"), None, None, -8.0, 0.02, 1800, 0.9)], 0.2),
    ("lantern_creak_1", [(W(KENNEY_RPG + "creak1.ogg"), None, None, 0.0, 0.0, None, 1.3),
                         (FILMCOW + "metal latch 1.wav", None, None, -10.0, 0.02, None, 1.2)], 0.15),
    ("lantern_creak_2", [(W(KENNEY_RPG + "creak2.ogg"), None, None, 0.0, 0.0, None, 1.3),
                         (FILMCOW + "metal latch 1.wav", None, None, -11.0, 0.05, None, 1.35)], 0.15),
    ("lantern_creak_3", [(W(KENNEY_RPG + "creak3.ogg"), None, None, 0.0, 0.0, None, 1.25),
                         (FILMCOW + "metal latch 1.wav", None, None, -12.0, 0.03, None, 1.1)], 0.15),
] + [
    # A lantern's bail rattling in the hand: FilmCow's chain, short.
    ("bail_rattle_%d" % (i + 1), [(FILMCOW + "chain %d.wav" % n, None, None, 0.0, 0.0, 4000, 1.15)], 0.05)
    for i, n in enumerate((2, 4, 6, 8))
]
# Layered takes no longer than this (s); a bail rattle no longer than 0.25 s.
LAYERED_LONGEST = {"bail_rattle": 0.25}


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


def split_events(x, count, gap=0.18, threshold_db=-26.0, shortest=0.08, longest=2.5, lead=0.02, tail=0.12):
    """The separate sounds in `x` (seconds, [start, end]): runs where its 20 ms
    envelope stands above `threshold_db` of the peak, parted by at least `gap`
    of quiet, each `shortest` to `longest` long; the loudest `count`, in
    order."""
    a = np.abs(x)
    peak = max(a.max(), 1e-9)
    w = max(int(0.02 * RATE), 1)
    env = np.convolve(a, np.ones(w) / w, mode="same")
    loud = env > peak * 10 ** (threshold_db / 20)
    events = []
    i = 0
    n = len(x)

    while i < n:
        if not loud[i]:
            i += 1
            continue

        start = i
        quiet = 0

        while i < n and quiet < int(gap * RATE):
            quiet = 0 if loud[i] else quiet + 1
            i += 1

        end = i - quiet
        length = (end - start) / RATE

        if shortest <= length <= longest:
            events.append([max(start / RATE - lead, 0.0), min(end / RATE + tail, n / RATE), float(env[start:end].max())])

    events.sort(key=lambda e: -e[2])
    chosen = sorted(events[:count], key=lambda e: e[0])
    return [[e[0], e[1]] for e in chosen]


def voice_slices(sources, mode, count, fade_out):
    """The slices of a VOICES entry."""
    out = []

    if mode == "join":
        pieces = []

        for source in sources:
            if os.path.exists(W(source)):
                whole = decode(W(source), 0.0, 1e9)
                first, last = auto_bounds(whole)
                pieces += [whole[first:last], np.zeros(int(0.18 * RATE))]

        return [fade(np.concatenate(pieces), 0.02, fade_out)] if pieces else []

    for source in sources:
        path = W(source)

        if not os.path.exists(path):
            print("  (missing: %s)" % source)
            continue

        whole = decode(path, 0.0, 1e9)

        if mode == "whole":
            first, last = auto_bounds(whole)
            out.append(fade(whole[first:last], 0.006, fade_out))
        elif mode == "split":
            for start, end in split_events(whole, count):
                out.append(fade(whole[int(start * RATE):int(end * RATE)], 0.006, fade_out))
        elif mode == "stretch":
            first, last = auto_bounds(whole)
            body = whole[first:last]
            step = int(count * RATE)

            for at in range(0, max(len(body) - step // 2, 1), step):
                piece = body[at:at + step]

                if len(piece) > RATE:
                    out.append(fade(piece, 0.08, fade_out))

    return out


def decode_filtered(path, start, end, filters=None):
    """decode(), through ffmpeg filters first (a pitch, a low- or high-pass)."""
    command = ["ffmpeg", "-v", "error", "-i", path]

    if filters:
        command += ["-af", ",".join(filters)]

    raw = subprocess.run(command + ["-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    mono = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64).mean(axis=1)

    if start is None or end is None:
        first, last = auto_bounds(mono)
        start = first / RATE if start is None else start
        end = last / RATE if end is None else end

    return mono[int(start * RATE):int(end * RATE)]


def _filters(lowpass=None, pitch=1.0, highpass=None):
    filters = []

    if abs(pitch - 1.0) > 1e-6:
        filters += ["asetrate=%d" % int(RATE * pitch), "aresample=%d" % RATE]

    if lowpass:
        filters.append("lowpass=f=%d" % lowpass)

    if highpass:
        filters.append("highpass=f=%d" % highpass)

    return filters


def layered(layers, fade_out, longest=None):
    """Recordings laid together, each at its gain and offset."""
    pieces = []

    for source, start, end, gain_db, offset, lowpass, pitch in layers:
        x = decode_filtered(source, start, end, _filters(lowpass, pitch))
        x = x * 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9) * 10 ** (gain_db / 20)
        pieces.append(np.concatenate([np.zeros(int(offset * RATE)), x]))

    mixed = np.zeros(max(len(p) for p in pieces))

    for piece in pieces:
        mixed[:len(piece)] += piece

    if longest:
        mixed = mixed[:int(longest * RATE)]

    return fade(mixed, 0.004, fade_out)


def snaps(x, count, apart=0.08, lead=0.004, length=0.09):
    """The loudest `count` sharp peaks in `x`, at least `apart` seconds from
    each other (a crackle is a couple of milliseconds: an envelope would
    smear it away), each cut `lead` before to `length` after."""
    a = np.abs(x)
    order = np.argsort(-a)
    chosen = []

    for i in order:
        if len(chosen) == count or a[i] < a[order[0]] * 0.15:
            break

        if all(abs(int(i) - c) > apart * RATE for c in chosen):
            chosen.append(int(i))

    return [(max(c / RATE - lead, 0.0), min(c / RATE + length, len(x) / RATE)) for c in sorted(chosen)]


def crackles(sources, count, highpass):
    out = []
    each = max(count // len(sources), 1)

    for source in sources:
        whole = decode_filtered(source, 0.0, 1e9, _filters(highpass=highpass))

        for start, end in snaps(whole, each):
            out.append(fade(whole[int(start * RATE):int(end * RATE)], 0.002, 0.04))

    return out


FIRE_IMPORT = """[remap]

importer="wav"
type="AudioStreamWAV"

[deps]

source_file="res://audio/ambience/{name}.wav"

[params]

force/8_bit=false
force/mono=true
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=2
"""


def prepare_fire_loops():
    """The fire beds, as WAVs that loop (this ffmpeg has no Vorbis encoder;
    Godot loops a WAV itself: edit/loop_mode 2 in its import settings)."""
    os.makedirs(AMBIENCE_OUT, exist_ok=True)

    for name, source, lowpass, pitch, length in FIRE_LOOPS:
        x = decode_filtered(source, 0.0, 1e9, _filters(lowpass, pitch))

        if length:
            # Its last 1.5 s laid over its first, equal power: a seamless loop.
            n = int(1.5 * RATE)
            x = x[:int(length * RATE) + n].copy()
            t = np.linspace(0.0, np.pi * 0.5, n)
            x[:n] = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
            x = x[:-n]

        x = peak_normalise(x, -3.0)
        write_wav(os.path.join(AMBIENCE_OUT, name + ".wav"), x)
        importer = os.path.join(AMBIENCE_OUT, name + ".wav.import")

        if not os.path.exists(importer):
            with open(importer, "w") as out:
                out.write(FIRE_IMPORT.format(name=name))

        print("%-12s fire loop, %.2f s, %.1f LUFS" % (name, len(x) / RATE, loudness(x)))


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


def decode_stereo(path, start, end):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    x = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    last = len(x) if end is None else int(end * RATE)
    return x[int(start * RATE):last]


def write_wav_stereo(path, x):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-", path],
        input=pcm.tobytes(), check=True,
    )


def stretch(x, samples):
    """Resampled to exactly `samples` long (speed and pitch together)."""
    old = np.linspace(0.0, 1.0, len(x))
    new = np.linspace(0.0, 1.0, samples)
    return np.stack([np.interp(new, old, x[:, c]) for c in range(2)], axis=1)


def loudness_stereo(x):
    return loudness(x.mean(axis=1))


def peak_normalise(x, db=PEAK_LIMIT_DB):
    return x * 10 ** (db / 20) / max(np.abs(x).max(), 1e-9)


def make_loop(x, kind, argument):
    """A seamless loop out of `x` (see LOOPS)."""
    if kind == "crossfade":
        n = int(argument * RATE)
        body = x[:-n].copy()
        t = np.linspace(0.0, np.pi * 0.5, n)[:, None]
        # Equal power: the end fades out over the start fading in.
        body[:n] = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
        return body

    if kind == "beats":
        # Each beat's slot evened out, then the lot stretched to whole bars.
        slots = 4 * int(argument)
        length = len(x) // slots
        x = x[:length * slots].copy()
        levels = [np.sqrt((x[i * length:(i + 1) * length] ** 2).mean()) for i in range(slots)]
        target = float(np.mean(levels))

        for i in range(slots):
            x[i * length:(i + 1) * length] *= target / max(levels[i], 1e-9)

        return stretch(x, int(round(argument * BAR * RATE)))

    if kind == "bars":
        want = int(round(argument * BAR * RATE))
        x = fade_stereo(x[:want], 0.004, 0.4)
        return np.concatenate([x, np.zeros((want - len(x), 2))]) if len(x) < want else x

    # "whole": already a loop of `argument` bars.
    return x


def fade_stereo(x, fade_in, fade_out):
    return np.stack([fade(x[:, c], fade_in, fade_out) for c in range(2)], axis=1)


def prepare_score():
    groups = {}

    for name, source, start, end, fade_out, backwards in STINGS:
        x = decode_stereo(source, start, end)

        if backwards:
            x = x[::-1].copy()

        x = peak_normalise(fade_stereo(x, 0.01, fade_out))
        groups.setdefault(re.sub(r"_\d+$", "", name), []).append([name, x, loudness_stereo(x)])

    # A sting's takes match the quietest of them, like any sound's.
    for group, members in groups.items():
        level = min(m[2] for m in members)

        for name, x, own in members:
            write_wav_stereo(os.path.join(OUT, name + ".wav"), x * 10 ** ((level - own) / 20))

        print("%-18s sting, %d take(s), %.1f LUFS" % (group, len(members), level))

    os.makedirs(MUSIC_OUT, exist_ok=True)

    for name, source, start, end, kind, argument in SCORE_LOOPS:
        x = peak_normalise(make_loop(decode_stereo(source, start, end), kind, argument), -3.0)
        write_wav_stereo(os.path.join(MUSIC_OUT, name + ".wav"), x)
        print("%-18s loop, %.3f s (%.2f bars), %.1f LUFS" % (name, len(x) / RATE, len(x) / RATE / BAR, loudness_stereo(x)))


def main():
    only = None
    args = []

    for a in sys.argv[1:]:
        if a.startswith("--only="):
            only = set(a.split("=", 1)[1].split(","))
        elif a == "--fire":
            prepare_fire_loops()
            return
        else:
            args.append(a)

    pack = args[0] if args else PACK
    os.makedirs(OUT, exist_ok=True)
    groups = {}

    for group, sources, mode, count, fade_out in VOICES:
        if only is not None and group not in only:
            continue

        for x in voice_slices(sources, mode, count, fade_out):
            # The game reads eight takes of a sound at most.
            if len(groups.get(group, [])) >= 8:
                break

            name = "%s_%d" % (group, len(groups.get(group, [])) + 1)
            x = x * 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)
            groups.setdefault(group, []).append([name, x, loudness(x)])

    for name, source, start, end, fade_out in SOUNDS:
        group = re.sub(r"_\d+$", "", name)

        if only is not None and group not in only:
            continue

        x = fade(decode(os.path.join(pack, source), start, end), 0.006, fade_out)
        # Every slice as loud as it can be without clipping, then measured.
        x *= 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)

        if group in PUNCHED:
            x = compress(x)
            x *= 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)

        groups.setdefault(group, []).append([name, x, loudness(x)])

    for group, sources, count, highpass in CRACKLES:
        if only is not None and group not in only:
            continue

        for x in crackles(sources, count, highpass):
            x = x * 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)
            name = "%s_%d" % (group, len(groups.get(group, [])) + 1)
            groups.setdefault(group, []).append([name, x, loudness(x)])

    for name, layers, fade_out in LAYERED:
        group = re.sub(r"_\d+$", "", name)

        if only is not None and group not in only:
            continue

        x = layered(layers, fade_out, LAYERED_LONGEST.get(group))
        x *= 10 ** (PEAK_LIMIT_DB / 20) / max(np.abs(x).max(), 1e-9)
        groups.setdefault(group, []).append([name, x, loudness(x)])

    # Variations match the quietest of them.
    for group, members in groups.items():
        level = min(m[2] for m in members)

        for name, x, own in members:
            write_wav(os.path.join(OUT, name + ".wav"), x * 10 ** ((level - own) / 20))

        print("%-12s %d file(s), %.1f LUFS" % (group, len(members), level))

    if only is not None:
        return

    prepare_score()
    os.makedirs(AMBIENCE_OUT, exist_ok=True)

    for name, source in AMBIENCES:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(pack, source), "-c", "copy",
                        os.path.join(AMBIENCE_OUT, name + ".ogg")], check=True)
        print("%-12s ambience loop" % name)

    prepare_fire_loops()


if __name__ == "__main__":
    main()
