extends RefCounted
## The first settings' calls (master volume, the awareness marks), kept for
## the code and tests that use them: they read and write GameSettings, which
## now holds every setting in the same file under the same keys.
const GameSettingsScript := preload("res://scripts/Settings/GameSettings.gd")

## Where they are kept (GameSettings.path). Tests point this elsewhere (and
## reload), so a run never changes the player's own.
static var path: String:
	get:
		return GameSettingsScript.current_path()
	set(value):
		GameSettingsScript.use_path(value)


## Linear master gain, 0–1.
static func master_volume() -> float:
	return float(GameSettingsScript.value("audio/master_volume"))


## Clamps linear gain to 0–1 (anything not a number is full), applies it to
## Master, and saves.
static func set_master_volume(value: float) -> void:
	GameSettingsScript.set_value("audio/master_volume", value if is_finite(value) else 1.0)


## The marks over men noticing you (StealthHUD's awareness marks), and the
## ticks as one makes you out.
static func awareness_marks() -> bool:
	return bool(GameSettingsScript.value("hud/awareness_marks"))


static func set_awareness_marks(on: bool) -> void:
	GameSettingsScript.set_value("hud/awareness_marks", on)


## Forget what was read: the next ask reads the file again (tests).
static func reread() -> void:
	GameSettingsScript.reread()
