extends "res://scripts/Level/DistrictMap.gd"
## The old town's map (the old town's spec): for now a stand-in, its ground
## at the massing's terraces with the wall and the Sea Gate it shares with
## the harbour and its four gates back (plan B1 builds the district). The
## harbour is drawn below by its proxy; the night is the harbour's moon,
## clear, with no schedule yet; its navmesh's settings are the harbour's,
## its home the Sea Gate's square.

const WindScript := preload("res://scripts/Visual/Wind.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## The loading screen's words, yours to write ("" shows none).
const LOADING := {
	"title": "",
	"old_town": "",
	"city_massing": "",
	"night": "",
	"navmesh": "",
	"guards": "",
	"player": "",
}
## The moon as over the harbour.
const MOON_TOWARD := Vector3(0.3, -0.57, -0.77)
const MOON_ENERGY := 0.36
const SHADOW_DISTANCE := 120.0
const AMBIENT := 0.40
const SKYLINE := "res://assets/sky/skyline_city.png"
## The navmesh over the old town's ground; its agent and cells the
## harbour's; its home the Sea Gate's square.
const BAKE_BOUNDS := AABB(Vector3(-200.0, -12.0, -400.0), Vector3(370.0, 120.0, 340.0))
const AGENT_RADIUS := 0.4
const CELL := 0.2
const HOME := Vector3(-55.0, 2.5, -100.0)
const MAX_CLIMB := 0.3
const MIN_ISLAND := 1.2


func _init() -> void:
	district = &"old_town"


func _loading_words() -> Dictionary:
	return LOADING


func _dress() -> void:
	_night_over(_moonlit(MOON_TOWARD, MOON_ENERGY, SHADOW_DISTANCE, AMBIENT), SKYLINE, [], [], [])
	var wind := Node.new()
	wind.name = "Wind"
	wind.set_script(WindScript)
	add_child(wind)
	set_meta(&"acoustics", "stone")
	set_meta(&"cold", true)
	Sfx.warm(self)


func _nav(nav: NavBaker) -> void:
	nav.cell_size = CELL
	nav.agent_radius = AGENT_RADIUS
	nav.agent_max_climb = MAX_CLIMB
	nav.min_island = MIN_ISLAND
	nav.drop_unreached = true
	nav.home = HOME
	nav.bake_bounds = BAKE_BOUNDS
