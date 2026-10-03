extends "res://scripts/Level/DistrictMap.gd"
## The harbour's map (the old town's spec, section 3A): the harbour at full
## detail with the rest of the city behind it (DistrictMap); its own night
## (the moon over the sea, the weather's schedule, puddles on the quays, mist
## on the water), wind, bats round the golden tower and stone acoustics; the
## world's wall round it; its navmesh's settings (the far ground out past the
## wall no guard's).
## Run res://maps/city.tscn; scene options and diagnostics are in
## docs/systems/development.md and DistrictMap.gd.

const WindScript := preload("res://scripts/Visual/Wind.gd")
const WildlifeScript := preload("res://scripts/Visual/Wildlife.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## The loading screen's words, yours to write: its title, and a line for
## each step of the load ("" shows none).
const LOADING := {
	"title": "",
	"city_harbour": "",
	"city_massing": "",
	"night": "",
	"navmesh": "",
	"guards": "",
	"player": "",
}
## The moon: from the south-south-west, over the sea; its shadows this far.
const MOON_TOWARD := Vector3(0.3, -0.57, -0.77)
const MOON_ENERGY := 0.36
const SHADOW_DISTANCE := 120.0
const AMBIENT := 0.40
## The navmesh over the land and 25 m of water round it (the guards'), its
## agent the garrison's.
const BAKE_BOUNDS := AABB(Vector3(-240.0, -12.0, -130.0), Vector3(520.0, 60.0, 360.0))
const AGENT_RADIUS := 0.4
## Its cells (the garrison's 0.1 over a harbour trips the engine's check on
## a bake's size; the radius still whole cells); its home, where the floor
## kept is reached from (the Terreiro).
const CELL := 0.2
const HOME := Vector3(-55.0, 2.5, -30.0)
const MAX_CLIMB := 0.3
const MIN_ISLAND := 1.2
## The night's weather: [minute, state, over s].
const WEATHER := [[4.0, &"cloudy", 60.0], [9.0, &"drizzle", 45.0], [13.0, &"shower", 30.0], [16.0, &"cloudy", 60.0]]
## Where rain pools (on the Terreiro and the quays); where mist lies (the
## harbour's water).
const PUDDLES := [Vector3(-70, 2.52, -30), Vector3(-40, 2.52, -50), Vector3(-55, 2.52, -14), Vector3(-82, 2.52, -8), Vector3(-130, 2.52, -3),
	Vector3(-95, 2.52, -3), Vector3(8, 2.52, -3), Vector3(128, 2.52, -24)]
const MIST := [AABB(Vector3(-190.0, -0.5, 0.0), Vector3(355.0, 3.0, 200.0))]
## Where low mist lies over the harbour's water between the quays and the
## mole (world x, z; Distance.gd).
const SEA_MIST := Rect2(-170.0, 30.0, 330.0, 230.0)
## The world's edge (x, z): a wall round it no one sees, from under the sea
## to over the castle (the land and the sea go on past it, out of reach).
const WORLD := Rect2(-590.0, -700.0, 1180.0, 1560.0)
const WORLD_WALL := Vector2(-60.0, 320.0)
## The ground out past it (tools/level/layouts/harbour/ground.py): no guard's.
const FAR_GROUND := ["far_sea_bed", "west_land", "far_headland"]
## Bats round the golden tower's lantern.
const TOWER_BATS := Vector3(92.0, 37.0, 203.0)
const SKYLINE := "res://assets/sky/skyline_city.png"


func _init() -> void:
	district = &"harbour"


func _loading_words() -> Dictionary:
	return LOADING


func _dress() -> void:
	_night_over(_moonlit(MOON_TOWARD, MOON_ENERGY, SHADOW_DISTANCE, AMBIENT), SKYLINE, WEATHER, PUDDLES, MIST)
	var wind := Node.new()
	wind.name = "Wind"
	wind.set_script(WindScript)
	add_child(wind)
	var life := WildlifeScript.new()
	add_child(life)
	life.bats(TOWER_BATS, 5, 6.0)
	_bounds()
	set_meta(&"acoustics", "stone")
	set_meta(&"cold", true)
	Sfx.warm(self)


func _sea_mist() -> Rect2:
	return SEA_MIST


func _nav(nav: NavBaker) -> void:
	nav.cell_size = CELL
	nav.agent_radius = AGENT_RADIUS
	nav.agent_max_climb = MAX_CLIMB
	nav.min_island = MIN_ISLAND
	nav.drop_unreached = true
	nav.home = HOME
	nav.bake_bounds = BAKE_BOUNDS

	# (Nor is the far ground round the harbour, out past the world's wall.)
	for ground in FAR_GROUND:
		for body in (levels["city_harbour"] as LevelLoader.Level).root.find_children("terrain_" + ground, "CollisionObject3D", true, false):
			body.add_to_group(&"nav_ignore")


## The world's wall: four boxes no one sees round WORLD, solid, left out of
## the navmesh.
func _bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldWall"
	body.collision_layer = 1
	body.set_meta(&"surface", "stone")
	body.add_to_group(&"nav_ignore")
	add_child(body)
	var height := WORLD_WALL.y - WORLD_WALL.x
	var thick := 4.0

	for side in [[WORLD.get_center().x, WORLD.position.y - thick * 0.5, WORLD.size.x + thick * 2.0, thick],
			[WORLD.get_center().x, WORLD.end.y + thick * 0.5, WORLD.size.x + thick * 2.0, thick],
			[WORLD.position.x - thick * 0.5, WORLD.get_center().y, thick, WORLD.size.y],
			[WORLD.end.x + thick * 0.5, WORLD.get_center().y, thick, WORLD.size.y]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(side[2], height, side[3])
		shape.shape = box
		shape.position = Vector3(side[0], (WORLD_WALL.x + WORLD_WALL.y) * 0.5, side[1])
		body.add_child(shape)
