# Status: VFX withdrawn at user request

The experimental muzzle, magic, shader and generated-texture changes were rolled back to the branch baseline on 2026-10-23. Ammo UI, the requested heavier recoil, and range launch/reset conveniences remain. Rejected files are archived outside the project at /tmp/rejected-combat-vfx-2026-10-23. The following records the rejected iterations, not the current implementation.

# Gun and magic feel polish

Goal: strengthen the existing revolver and casting presentation for another gameplay test, following the user's Deadlock/comic/Hellboy direction.

Keep damage, ammunition, spell costs, cast times, weapon cadence and aiming unchanged. Use original code-built graphics, existing audio, and existing hand poses. Work in the existing revolver-magic checkout.

- [x] Increase the recoil pose's displacement and camera impulse; keep a longer visible settling tail without changing fire timing.
- [x] Add short, bounded, scene-owned graphic bursts: ink silhouette, warm muzzle core, faceted smoke, distinct school colors. Respect Fx.enabled and FX render layers.
- [x] Animate casting anticipation and release; improve glass and smoke circles and Ward's fading silhouette. Keep collision and damage unchanged.
- [x] Run revolver, caster, gunfight and gym checks; capture windowed effects stills; reopen the playable gym.

Review focus: effects must survive projectile deletion, expire and remain bounded during repeated casts, stay out of lightgem rendering, and avoid hiding targets. Early cancellation must remain free and must not emit release effects.

Playtest: launch `res://maps/combat_gym.tscn -- --range` to start at the targets with the revolver, extra ammunition, and invulnerability. F5 resets the range.

Validation: 71 focused checks passed before the final visual-only adjustments; windowed captures in /tmp/revolver-polish-final. Final regression result recorded below.

Final verification: revolver 25/25, caster 27/27, gunfight 5/5, gym 9/9, graphic burst lifecycle 5/5. Windowed captures inspected; updated range launched and visually confirmed. Changes remain uncommitted in revolver-magic.

Second playtest pass: compact unboxed ammo count/reserve, selected-barrel marks and reload indicator. Muzzle flash attached to the actual gun muzzle in viewmodel space; magic release attached to the palm circle. Replaced flat starbursts with bore-aligned flame, glass splinters and tapered smoke curls, retaining exaggerated comic timing. Ammo UI tests cover firing, reserves, reload, barrel switch and holster.

Third pass, explicitly requested by user: inspected and documented actual reference imagery in ../refs/combat-vfx-references.md. Replaced burst/smoke presentation with custom muzzle, smoke, flowing spirit, and faceted-glass shaders plus shared viewmodel projection. Increased flash size/emission, shader edge contrast and release wave; restrained release-light overexposure after dark-stage capture. All 76 focused checks passed; GPU stage compiled all shaders and produced lit and dark captures without errors.
