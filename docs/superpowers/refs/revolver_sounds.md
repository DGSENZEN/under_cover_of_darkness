# Revolver and magic: sounds to source

The revolver and the spells play stand-ins cut from the existing packs until the user sources the real recordings (no procedural audio). Each line is a sound the game wants, where it is played, and what stands in for it now. Drop the recording in through `tools/prepare_sfx.py` under the wanted name, then point the stand-in at it (`Revolver.SOUNDS`, or the call named).

| Wanted | Played from | Stand-in now |
| --- | --- | --- |
| `gunshot`: a heavy revolver ball | `Revolver.SOUNDS` | `explosion` at -7 dB, pitch 1.9 |
| `shellshot`: the shot barrel's shell | `Revolver.SOUNDS` | `explosion` at -4 dB, pitch 1.45 |
| `click_empty`: the hammer on a spent chamber | `Revolver.SOUNDS` | `gear` at -9 dB, pitch 1.7 |
| `hammer`: the hammer nose flipped | `Revolver.SOUNDS` | `gear` at -14 dB, pitch 1.3 |
| `gate`: the loading gate open or shut | `Revolver.SOUNDS` | `unlock` at -10 dB, pitch 1.5 |
| `round_in`: a round dropped into a chamber, a shell into the barrel | `Revolver.SOUNDS` | `coins` at -12 dB, pitch 1.6 |
| A ball into flesh | `Guard._hit_sound` (bullet, shot) | `arrow_flesh` |
| The pistol-whip landing | `Revolver._update_whip` | `thud` |
| The shard's hiss, and its crack on stone | `Shard.launch`, `Shard._hit` | `whoosh_light` pitch 1.6; `ting` pitch 1.7 |
| The ward rising, and a shot stopped in it | `Ward._ready`, `Ward.turned_aside` | `whoosh` pitch 0.55; `whoosh_light` pitch 0.6 |
| Blink's mirror-flash | `Caster._blink_to` | `whoosh_light` pitch 0.7 |
| Empower's beast strength, cast and spent | `Caster._effect`, `Caster.spend_empower` | `heartbeat`; `roar` at -10 dB |
| A spell the pool can't pay for | `PowerPool.refused` | `gear` at -10 dB, pitch 1.9 |
| A body burst | `Gore.burst` | `flesh_heavy`, `bone_crack` |
