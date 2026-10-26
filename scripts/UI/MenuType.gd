class_name MenuType
## The menu's typefaces (SIL Open Font License, see assets/fonts/README.md):
## deco capitals for the title, book small capitals for the choices and
## headings, a book serif for page text. The system serif stands behind each.
const POIRET := preload("res://assets/fonts/PoiretOne-Regular.ttf")
const CORMORANT_SC := preload("res://assets/fonts/CormorantSC-Medium.ttf")
const GARAMOND := preload("res://assets/fonts/CormorantGaramond-Variable.ttf")
const GARAMOND_ITALIC := preload("res://assets/fonts/CormorantGaramond-Italic-Variable.ttf")

static var _fallback: SystemFont

static func title() -> Font:
	return _with_fallback(POIRET)

static func choice() -> Font:
	return _with_fallback(CORMORANT_SC)

static func body() -> Font:
	return _weighted(GARAMOND, 500)

static func body_italic() -> Font:
	return _weighted(GARAMOND_ITALIC, 500)

static func _weighted(font: FontFile, weight: int) -> Font:
	var face := FontVariation.new()
	face.base_font = _with_fallback(font)
	face.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return face

static func _with_fallback(font: FontFile) -> FontFile:
	if _fallback == null:
		_fallback = SystemFont.new()
		_fallback.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "serif"])
	if not font.fallbacks.has(_fallback):
		font.fallbacks = [_fallback]
	return font
