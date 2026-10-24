extends Node3D
## The revolver: on the belt, its two barrels, the kick and the settle, the
## reload through the gate, held in view, the pistol-whip, and gibbing.

const PLAYER := preload("res://Player.tscn")
const GUARD_SCRIPT := preload("res://scripts/AISystem/Guard.gd")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const Gore := preload("res://scripts/Visual/Gore.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Casings := preload("res://scripts/Visual/Casings.gd")


class Ear:
	var events: Array = []

	func hear_sound(event: Dictionary) -> void:
		events.append(event)


var player: CharacterBody3D
var baker: NavigationRegion3D
var results: Array[String] = []


func _ready() -> void:
	# Every guard at his class's own temperament: these checks are exact.
	TemperamentScript.rolling = false
	# Exact damage is checked here: wounds do not go on bleeding.
	GUARD_SCRIPT.bleeding_on = false
	# The Prosecutor's own arms (F12, FP_ARMS=new), before the player is made.
	ViewArmsScript.new_arms = true
	Props.block(self, Vector3(0, -0.5, 0), Vector3(140, 1, 90))              # floor
	Props.block(self, Vector3(30, 1.5, -5.0), Vector3(4, 3, 1))              # R9 wall, top at 3, face at z = -4.5
	Props.block(self, Vector3(-20, 1.5, -8.0), Vector3(6, 3, 0.4))           # H4 a stone wall, its face at z = -7.8

	baker = NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false
	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()
	player.debug_light_level = 1.0
	player.global_position = Vector3(60, 1.05, 40)

	await baker.baked
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)
	get_tree().quit()


func _run() -> void:
	var combat: Node = player.combat

	# R1 the revolver on the belt: drawn, the sword's blows stand down
	Props.give_revolver(player)
	_wield(&"revolver")
	var g1 := _fighter(Vector3(0, 0, -1.5))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	await _tap("throw")
	await _frames(40)
	_check("R1 the revolver is drawn, and the left mouse is no sword blow",
		combat.gun_drawn() and player.inventory.ammo[&"rounds"] == 24 and player.inventory.ammo[&"shells"] == 4
			and g1.health == g1.max_health and combat.phase == combat.Phase.IDLE,
		"drawn %s ammo %s health %.0f phase %d" % [combat.gun_drawn(), player.inventory.ammo, g1.health, combat.phase])
	g1.queue_free()

	# R2 the kick still works with the gun drawn
	var g2 := _fighter(Vector3(0, 0, -1.6))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	var kicks := []
	combat.kicked.connect(func(t): kicks.append(t))
	await _tap("kick")
	await _frames(40)
	_check("R2 the kick still works with the gun drawn", kicks.size() == 1, "kicked %d" % kicks.size())
	g2.queue_free()

	# R3 rounds picked up go to the stock, not the belt
	var belt_before: int = player.inventory.belt.size()
	var box := Props.ammo(self, Vector3(3, 0.3, 3), &"rounds", 6)
	await _frames(2)
	box.frob(player)
	await _frames(2)
	_check("R3 rounds picked up go to the stock, not the belt",
		player.inventory.ammo[&"rounds"] == 30 and player.inventory.belt.size() == belt_before,
		"rounds %d belt %d -> %d" % [player.inventory.ammo[&"rounds"], belt_before, player.inventory.belt.size()])

	var revolver: Node = player.revolver

	# R4 a shot to the body: a bullet's damage, one round gone
	revolver.reset_for_practice()
	var g4 := _fighter(Vector3(0, 0, -6))
	_put_player(Vector3(0, 1.05, 0))
	await _frames(20)
	_aim(g4.global_position + Vector3(0, 1.25, 0))
	var shots := []
	revolver.fired.connect(func(b, h): shots.append(b))
	await _tap("throw")
	await _frames(5)
	_check("R4 a shot to the body does a bullet's damage and spends a round",
		_near(g4.health, 45.0, 0.1) and revolver.loaded[&"cylinder"] == 5 and shots == [&"cylinder"],
		"health %.1f loaded %s fired %s" % [g4.health, revolver.loaded, shots])
	g4.queue_free()

	# R5 to the head: one shot kills
	var g5 := _fighter(Vector3(2, 0, -6))
	_put_player(Vector3(2, 1.05, 0))
	await _frames(40)
	_aim(g5.eye_position())
	await _tap("throw")
	await _frames(5)
	_check("R5 a headshot kills", not is_instance_valid(g5) or g5.health <= 0.0,
		"health %.1f" % (g5.health if is_instance_valid(g5) else -1.0))

	# R6 the next shot is ready only once the gun has settled: slower in one hand
	revolver.reset_for_practice()
	var g6 := _fighter(Vector3(4, 0, -8))
	g6.max_health = 9999.0
	g6.health = 9999.0
	_put_player(Vector3(4, 1.05, 0))
	await _frames(20)
	_aim(g6.global_position + Vector3(0, 1.25, 0))
	shots.clear()
	await _tap("throw")
	await _frames(28)
	await _tap("throw")
	var early := shots.size()
	await _frames(10)
	await _tap("throw")
	var one_hand := shots.size()
	Input.action_press("aim")
	await _frames(40)
	shots.clear()
	await _tap("throw")
	# 0.4 s on: ready aimed (0.35 s), not from the hip (0.6 s).
	await _frames(22)
	await _tap("throw")
	await _frames(2)
	var braced := shots.size()
	Input.action_release("aim")
	await _frames(40)
	_check("R6 from the hip the next shot is ready after 0.6 s, aimed after 0.35 s",
		early == 1 and one_hand == 2 and braced == 2, "early %d hip %d aimed %d" % [early, one_hand, braced])
	g6.queue_free()

	# R7 a gunshot is heard: loud, and known for what it is
	revolver.reset_for_practice()
	var ear := Ear.new()
	SoundBus.add_listener(ear)
	_put_player(Vector3(6, 1.05, 0))
	await _frames(20)
	await _tap("throw")
	await _frames(3)
	SoundBus.remove_listener(ear)
	var heard: Array = ear.events.filter(func(e): return e["kind"] == &"gunshot")
	_check("R7 a gunshot goes out at 70 dB", heard.size() == 1 and _near(heard[0]["db"], 70.0, 0.01),
		"heard %s" % [heard.map(func(e): return e["db"])])

	# R8 the muzzle flash lights the place for a moment
	revolver.reset_for_practice()
	await _frames(40)
	var lit_before := Fx.lights_lit()
	Input.action_press("throw")
	await _frames(2)
	var lit_during := Fx.lights_lit()
	Input.action_release("throw")
	await _frames(12)
	_check("R8 the muzzle flash lights up, then goes", lit_during > lit_before and Fx.lights_lit() == lit_before,
		"lit %d -> %d -> %d" % [lit_before, lit_during, Fx.lights_lit()])

	# R10 the shot barrel at 5 m: its own shell, pellets fallen off with range
	revolver.reset_for_practice()
	var g10 := _fighter(Vector3(10, 0, -5))
	g10.max_health = 9999.0
	g10.health = 9999.0
	# He stands where he is put: the range is the check.
	g10.set_physics_process(false)
	_put_player(Vector3(10, 1.05, 0))
	await _frames(20)
	_aim(g10.global_position + Vector3(0, 1.2, 0))
	revolver.flip_barrel()
	await _frames(12)
	var spread := []
	revolver.fired.connect(func(b, h): spread.append([b, h]), CONNECT_ONE_SHOT)
	await _tap("throw")
	await _frames(4)
	var lost: float = 9999.0 - g10.health
	var struck := 0
	var expected := 0.0
	var eye10: Vector3 = player.combat.aim().origin

	if not spread.is_empty():
		for h in spread[0][1]:
			if h["target"] == g10:
				struck += 1
				# Full to 3 m, nothing by 12 m: from where each pellet went in.
				expected += 18.0 * (1.0 - clampf((eye10.distance_to(h["point"]) - 3.0) / 9.0, 0.0, 1.0))

	_check("R10 a shell: its own barrel, pellets fallen off with range",
		revolver.loaded[&"shot"] == 0 and revolver.loaded[&"cylinder"] == 6 and lost >= 50.0 and lost <= 162.0
			and struck >= 5 and _near(lost, expected, 1.0) and lost < struck * 18.0 - 10.0,
		"loaded %s lost %.1f expected %.1f pellets in him %d" % [revolver.loaded, lost, expected, struck])
	g10.queue_free()

	# R11 at 14 m a shell does nothing
	revolver.reset_for_practice()
	var g11 := _fighter(Vector3(14, 0, -14))
	g11.set_physics_process(false)
	_put_player(Vector3(14, 1.05, 0))
	await _frames(20)
	_aim(g11.global_position + Vector3(0, 1.2, 0))
	revolver.flip_barrel()
	await _frames(12)
	await _tap("throw")
	await _frames(4)
	_check("R11 a shell at 14 m does no harm", g11.health == g11.max_health, "health %.1f" % g11.health)
	g11.queue_free()

	# R12 point-blank: a blast, and it tears him apart
	revolver.reset_for_practice()
	var parts_before := _severed_parts()
	var g12 := _fighter(Vector3(18, 0, -1.5))
	_put_player(Vector3(18, 1.05, 0))
	await _frames(20)
	_aim(g12.global_position + Vector3(0, 1.2, 0))
	revolver.flip_barrel()
	await _frames(12)
	await _tap("throw")
	await _frames(30)
	_check("R12 a shell point-blank is one blast, and tears a limb off",
		not is_instance_valid(g12) and _severed_parts() > parts_before,
		"alive %s parts %d -> %d" % [is_instance_valid(g12), parts_before, _severed_parts()])

	# R12b the spent shot barrel only clicks
	var clicks := []
	revolver.clicked_empty.connect(func(): clicks.append(1), CONNECT_ONE_SHOT)
	var g12b := _fighter(Vector3(22, 0, -3))
	_put_player(Vector3(22, 1.05, 0))
	await _frames(40)
	_aim(g12b.global_position + Vector3(0, 1.2, 0))
	await _tap("throw")
	await _frames(4)
	_check("R12b the spent shot barrel only clicks", clicks.size() == 1 and g12b.health == g12b.max_health and revolver.barrel == &"shot",
		"clicks %d health %.1f barrel %s" % [clicks.size(), g12b.health, revolver.barrel])
	g12b.queue_free()

	# R13 the reload takes what there is, no more; with nothing, nothing
	revolver.reset_for_practice()
	_put_player(Vector3(26, 1.05, 0))
	player.get_node("Neck").rotation.x = -0.6
	player.inventory.ammo[&"rounds"] = 2
	for i in 4:
		await _tap("throw")
		await _frames(40)
	await _tap("reload")
	await _frames(200)
	var after_two: int = revolver.loaded[&"cylinder"]
	var stock: int = player.inventory.ammo[&"rounds"]
	await _tap("reload")
	await _frames(3)
	_check("R13 a reload takes what rounds there are; with none it does nothing",
		after_two == 4 and stock == 0 and revolver.loading == revolver.Load.NONE,
		"loaded %d stock %d loading %d" % [after_two, stock, revolver.loading])

	# R13b firing mid-reload: the gate snaps shut and the shot goes
	revolver.reset_for_practice()
	player.inventory.ammo[&"rounds"] = 24
	for i in 3:
		await _tap("throw")
		await _frames(40)
	shots.clear()
	await _tap("reload")
	await _frames(int(ceil((0.25 + 0.45) * 60.0)) + 2)
	var one_in: int = revolver.loaded[&"cylinder"]
	await _tap("throw")
	await _frames(8)
	_check("R13b a shot mid-reload: the round in stays, the gate shuts, it fires",
		one_in == 4 and shots.size() == 1 and revolver.loaded[&"cylinder"] == 3 and revolver.loading == revolver.Load.NONE,
		"one in %d shots %d loaded %d loading %d" % [one_in, shots.size(), revolver.loaded[&"cylinder"], revolver.loading])

	# R13c the shell loads on its own, slowly
	revolver.reset_for_practice()
	revolver.flip_barrel()
	await _frames(12)
	await _tap("throw")
	await _frames(40)
	await _tap("reload")
	await _frames(58)
	var at_sixty: int = revolver.loaded[&"shot"]
	await _frames(8)
	_check("R13c a shell takes 1.1 s to load", at_sixty == 0 and revolver.loaded[&"shot"] == 1,
		"at 60 %d at 68 %d" % [at_sixty, revolver.loaded[&"shot"]])

	# R14 put away mid-reload: nothing half done, nothing lost
	revolver.reset_for_practice()
	for i in 3:
		await _tap("throw")
		await _frames(40)
	var stock_before: int = player.inventory.ammo[&"rounds"]
	await _tap("reload")
	await _frames(50)
	player.inventory.select_next()
	await _frames(3)
	var cancelled: bool = revolver.loading == revolver.Load.NONE
	var stock_after: int = player.inventory.ammo[&"rounds"]
	_wield(&"revolver")
	await _frames(60)
	_check("R14 put away mid-reload: the reload is over, only the rounds put in are spent",
		cancelled and stock_after == stock_before - 1 and revolver.loaded[&"cylinder"] == 4 and revolver.ready_to_fire(),
		"cancelled %s stock %d -> %d loaded %d ready %s" % [cancelled, stock_before, stock_after, revolver.loaded[&"cylinder"], revolver.ready_to_fire()])
	player.get_node("Neck").rotation.x = 0.0

	# R9 hanging from a ledge, the gun is away: no shot
	revolver.reset_for_practice()
	_put_player(Vector3(30, 1.05, 0))
	await _frames(10)
	var anchor: Vector3 = player.planner.hang_anchor(Vector3(30, 3.0, -4.5), Vector3.BACK, 3.0)
	player.teleport(Transform3D(Basis.IDENTITY, anchor))
	player._enter_hang(Vector3.BACK, 3.0, false)
	await _frames(20)
	shots.clear()
	await _tap("throw")
	await _frames(6)
	var hung_shots := shots.size()
	var hung_visible: bool = player.hand.is_item_visible()
	player._drop_from_hang()
	await _frames(60)
	_check("R9 hanging, the gun is away and fires nothing; standing, it comes back",
		hung_shots == 0 and not hung_visible and player.hand.is_item_visible(),
		"shots %d visible hanging %s standing %s" % [hung_shots, hung_visible, player.hand.is_item_visible()])

	# R15 held in view: the muzzle low right; braced, the left hand under the grip
	revolver.reset_for_practice()
	_put_player(Vector3(34, 1.05, 0))
	await _frames(60)
	var gun_mesh: MeshInstance3D = player.hand._main_mesh
	var tip: Vector3 = gun_mesh.mesh.get_meta(&"muzzle")
	var size: Vector2 = get_viewport().get_visible_rect().size
	var muzzle: Vector2 = _on_screen_point(gun_mesh.global_transform * tip) / size
	Input.action_press("aim")
	await _frames(40)
	var support: float = player.hand._arms.hand_position(0).distance_to(gun_mesh.global_transform.origin)
	var bore: Vector3 = player.camera.global_basis.inverse() * -gun_mesh.global_basis.z.normalized()
	var off_axis: float = rad_to_deg(bore.angle_to(Vector3.FORWARD))
	Input.action_release("aim")
	await _frames(30)
	_check("R15 the muzzle shows low right at the hip; aimed, the left hand is on the grip",
		muzzle.x > 0.5 and muzzle.x < 1.0 and muzzle.y > 0.5 and muzzle.y < 1.0 and support <= 0.08 * ViewArmsScript.SCALE,
		"muzzle at %s support %.3f" % [muzzle, support])
	_check("A5 aimed, the barrel runs down the line of sight", off_axis <= 1.0, "off the view's axis %.2f deg" % off_axis)

	# R15b the cylinder turns a chamber for each shot
	revolver.reset_for_practice()
	await _frames(10)
	var cylinder: Node3D = gun_mesh.get_node_or_null("Cylinder")
	var turned := -1.0

	if cylinder != null:
		var before_shot: Basis = cylinder.transform.basis
		await _tap("throw")
		await _frames(30)
		turned = rad_to_deg((before_shot.inverse() * cylinder.transform.basis).get_euler().y)

	_check("R15b the cylinder turns 60 degrees for a shot", _near(absf(turned), 60.0, 1.0), "turned %.1f" % turned)

	# A1 right mouse raises the sights: 0.18 s up, the view narrowed to 62
	revolver.reset_for_practice()
	_put_player(Vector3(36, 1.05, 0))
	await _frames(30)
	Input.action_press("aim")
	await _frames(5)
	var rising: float = revolver.aim_amount()
	await _frames(7)
	var up: bool = revolver.aimed
	await _frames(28)
	var narrowed: float = player.camera.fov
	_check("A1 right mouse raises the sights in 0.18 s, the view narrowed to 62",
		rising >= 0.3 and rising <= 0.8 and up and _near(narrowed, 62.0, 0.5),
		"at 5 frames %.2f, up %s, fov %.1f" % [rising, up, narrowed])

	# A4 aimed, the left hand is on the gun: only cantrips
	var aimed_shard: bool = player.caster.can_cast(&"shard")
	var aimed_blink: bool = player.caster.can_cast(&"blink")
	_check("A4 aimed, no hand spell, but Blink", not aimed_shard and aimed_blink, "shard %s blink %s" % [aimed_shard, aimed_blink])

	# A3 aimed you walk slower, and let go it all comes back
	var slowed: float = player.combat.speed_scale()
	Input.action_release("aim")
	await _frames(15)
	var freed: float = player.combat.speed_scale()
	await _frames(30)
	_check("A3 aimed you walk at 0.7, and let go the speed and the view come back",
		_near(slowed, 0.7, 0.001) and _near(freed, 1.0, 0.001) and _near(player.camera.fov, 75.0, 0.5),
		"aimed %.2f after %.2f fov %.1f" % [slowed, freed, player.camera.fov])

	# A6 aimed, then up on a ledge, or the sword taken: the aim drops clean
	Input.action_press("aim")
	await _frames(20)
	var anchor6: Vector3 = player.planner.hang_anchor(Vector3(30, 3.0, -4.5), Vector3.BACK, 3.0)
	player.teleport(Transform3D(Basis.IDENTITY, anchor6))
	player._enter_hang(Vector3.BACK, 3.0, false)
	await _frames(45)
	var hung_fov: float = player.camera.fov
	var hung_aim: float = revolver.aim_amount()
	player._drop_from_hang()
	await _frames(60)
	_put_player(Vector3(36, 1.05, 0))
	Input.action_press("aim")
	await _frames(20)
	player.inventory.holster()
	await _frames(45)
	var sword_fov: float = player.camera.fov
	var sword_aim: float = revolver.aim_amount()
	Input.action_release("aim")
	_wield(&"revolver")
	await _frames(40)
	_check("A6 the aim drops clean onto a ledge or with the gun put away",
		_near(hung_fov, 75.0, 0.5) and hung_aim == 0.0 and _near(sword_fov, 75.0, 0.5) and sword_aim == 0.0,
		"hanging fov %.1f aim %.2f, put away fov %.1f aim %.2f" % [hung_fov, hung_aim, sword_fov, sword_aim])

	# K1 a shot from the hip throws the aim up 3.5 degrees
	revolver.reset_for_practice()
	_put_player(Vector3(36, 1.05, 0))
	await _frames(30)
	var neck: Node3D = player.get_node("Neck")
	var level: float = neck.rotation.x
	await _tap("throw")
	var thrown_up: float = rad_to_deg(neck.rotation.x - level)
	_check("K1 a hip shot throws the aim up 3.5 degrees", _near(thrown_up, 3.5, 0.2), "up %.2f" % thrown_up)

	# K2 as the gun settles, 60 % of it comes back by itself
	await _frames(40)
	var left_up: float = rad_to_deg(neck.rotation.x - level)
	_check("K2 as the gun settles, 60 % of the climb comes back", _near(left_up, 1.4, 0.2), "still up %.2f" % left_up)

	# K3 aimed, half the climb; the shell, more
	neck.rotation.x = 0.0
	Input.action_press("aim")
	await _frames(30)
	level = neck.rotation.x
	await _tap("throw")
	var aimed_up: float = rad_to_deg(neck.rotation.x - level)
	Input.action_release("aim")
	await _frames(40)
	neck.rotation.x = 0.0
	revolver.flip_barrel()
	await _frames(12)
	level = neck.rotation.x
	await _tap("throw")
	var shell_up: float = rad_to_deg(neck.rotation.x - level)
	revolver.flip_barrel()
	await _frames(40)
	_check("K3 aimed, the climb is half; a shell's is 1.4 times a ball's",
		_near(aimed_up, 1.75, 0.2) and _near(shell_up, 4.9, 0.25), "aimed %.2f shell %.2f" % [aimed_up, shell_up])

	# K4 looking straight up, a shot can't throw the aim over the top
	revolver.reset_for_practice()
	var limit: float = deg_to_rad(player.max_pitch_degrees)
	neck.rotation.x = limit
	await _frames(40)
	await _tap("throw")
	await _frames(2)
	_check("K4 at the top of the look, the kick stops at the limit", neck.rotation.x <= limit + 0.0001,
		"pitch %.2f limit %.2f" % [rad_to_deg(neck.rotation.x), player.max_pitch_degrees])
	neck.rotation.x = 0.0
	await _frames(40)

	# H1 a ball knocks a man back
	revolver.reset_for_practice()
	var g_h1 := _fighter(Vector3(-30, 0, -5))
	_put_player(Vector3(-30, 1.05, 0))
	await _frames(20)
	_aim(g_h1.global_position + Vector3(0, 1.25, 0))
	await _tap("throw")
	var away: float = g_h1.velocity.dot(Vector3(0, 0, -1))
	_check("H1 a ball knocks a man back", away >= 2.0, "back %.2f m/s" % away)
	g_h1.queue_free()
	await _frames(10)

	# H2 the crosshair says what it was: a hit, a head, a kill
	var marks := []
	revolver.hit_confirmed.connect(func(kind): marks.append(kind))
	var crosshair: Control = player.hud._crosshair
	var seen := []
	revolver.reset_for_practice()
	var g_h2 := _fighter(Vector3(-34, 0, -6))
	g_h2.set_physics_process(false)
	g_h2.max_health = 9999.0
	g_h2.health = 9999.0
	_put_player(Vector3(-34, 1.05, 0))
	await _frames(20)
	_aim(g_h2.global_position + Vector3(0, 1.2, 0))
	await _tap("throw")
	await _frames(1)
	seen.append(crosshair.contact_kind)
	await _frames(40)
	_aim(g_h2.eye_position())
	await _tap("throw")
	await _frames(1)
	seen.append(crosshair.contact_kind)
	await _frames(40)
	g_h2.health = 10.0
	_aim(g_h2.global_position + Vector3(0, 1.2, 0))
	await _tap("throw")
	await _frames(1)
	seen.append(crosshair.contact_kind)
	_check("H2 a body hit, a headshot and a kill each mark the crosshair as such",
		marks == [&"shot", &"headshot", &"kill"] and seen == [&"shot", &"headshot", &"kill"], "marks %s crosshair %s" % [marks, seen])
	await _frames(40)

	# H3 a kill holds a beat longer than a hit
	var hold_hit := 0
	var hold_kill := 0
	var g_h3 := _fighter(Vector3(-38, 0, -6))
	g_h3.set_physics_process(false)
	_put_player(Vector3(-38, 1.05, 0))
	await _frames(20)
	_aim(g_h3.global_position + Vector3(0, 1.2, 0))
	revolver.reset_for_practice()
	await _tap("throw")
	while TimeFx.is_active(&"hitstop") and hold_hit < 30:
		hold_hit += 1
		await get_tree().process_frame
	await _frames(40)
	g_h3.health = 10.0
	await _tap("throw")
	while TimeFx.is_active(&"hitstop") and hold_kill < 30:
		hold_kill += 1
		await get_tree().process_frame
	_check("H3 a kill's hit-stop holds longer than a hit's", hold_kill > hold_hit and hold_hit >= 1,
		"hit %d frames kill %d frames" % [hold_hit, hold_kill])
	await _frames(40)

	# H4 a ball leaves a hole in stone, gone in half a minute
	Fx.clear()
	revolver.reset_for_practice()
	_put_player(Vector3(-20, 1.05, -2))
	await _frames(20)
	_aim(Vector3(-20, 1.4, -7.8))
	var holes_before: int = Fx.holes_in_use()
	await _tap("throw")
	await _frames(3)
	var holed: int = Fx.holes_in_use() - holes_before
	await _frames(1860)
	_check("H4 a ball leaves a hole in stone, and it is gone in half a minute", holed == 1 and Fx.holes_in_use() == holes_before,
		"holes +%d, after 31 s %d" % [holed, Fx.holes_in_use()])

	# H5 no hole on a crate or a man
	Fx.clear()
	var crate := Props.crate(self, Vector3(-24, 0.3, -6), 0.5, 5.0)
	var g_h5 := _fighter(Vector3(-27, 0, -6))
	g_h5.set_physics_process(false)
	g_h5.max_health = 9999.0
	g_h5.health = 9999.0
	_put_player(Vector3(-24, 1.05, 0))
	await _frames(20)
	revolver.reset_for_practice()
	_aim(crate.global_position)
	await _tap("throw")
	await _frames(40)
	_put_player(Vector3(-27, 1.05, 0))
	await _frames(5)
	_aim(g_h5.global_position + Vector3(0, 1.2, 0))
	await _tap("throw")
	await _frames(3)
	_check("H5 no hole is left in a crate or a man", Fx.holes_in_use() == 0, "holes %d" % Fx.holes_in_use())
	g_h5.queue_free()

	# W1 the revolver is slow to draw: no shot until it is up
	revolver.reset_for_practice()
	_put_player(Vector3(36, 1.05, 0))
	player.inventory.holster()
	await _frames(40)
	shots.clear()
	_wield(&"revolver")
	await _frames(18)
	await _tap("throw")
	var too_soon := shots.size()
	await _frames(10)
	await _tap("throw")
	_check("W1 the revolver takes 0.45 s to draw: no shot before it is up", too_soon == 0 and shots.size() == 1,
		"at 20 frames %d, at 32 frames %d" % [too_soon, shots.size()])
	await _frames(40)

	# W2 it lags behind a quick turn, a little, and comes back
	var gun_w2: MeshInstance3D = player.hand._main_mesh
	var steady: float = _yaw_in_view(gun_w2)
	player.rotation.y += deg_to_rad(30.0)
	await _frames(2)
	var lagging: float = absf(_yaw_in_view(gun_w2) - steady)
	await _frames(30)
	var settled: float = absf(_yaw_in_view(gun_w2) - steady)
	_check("W2 the revolver lags 2 to 4 degrees behind a quick turn, and comes back",
		lagging >= 2.0 and lagging <= 4.0 and settled <= 1.0, "lag %.2f, after %.2f" % [lagging, settled])

	# W3 out of a sprint it takes a moment to come back up
	shots.clear()
	revolver.reset_for_practice()
	_put_player(Vector3(40, 1.05, 20))
	await _frames(10)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(3)
	await _tap("throw")
	var out_of_run := shots.size()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(10)
	await _tap("throw")
	_check("W3 out of a sprint, no shot for 0.15 s", out_of_run == 0 and shots.size() == 1,
		"at 5 frames %d, at 12 frames %d" % [out_of_run, shots.size()])
	await _frames(40)

	# C1 the reload drops a casing for each spent chamber
	revolver.reset_for_practice()
	_put_player(Vector3(44, 1.05, 20))
	player.get_node("Neck").rotation.x = -0.5
	await _frames(40)
	for i in 3:
		await _tap("throw")
		await _frames(40)
	var before_c1: int = Casings.live_count()
	await _tap("reload")
	await _frames(20)
	var dropped: int = Casings.live_count() - before_c1
	_check("C1 three spent, three casings drop at the reload", dropped == 3, "dropped %d" % dropped)
	await _frames(200)

	# C2 a full cylinder: no reload, no casings
	revolver.reset_for_practice()
	var before_c2: int = Casings.live_count()
	await _tap("reload")
	await _frames(20)
	_check("C2 nothing spent, nothing drops", Casings.live_count() == before_c2 and revolver.loading == revolver.Load.NONE,
		"casings %d -> %d" % [before_c2, Casings.live_count()])
	player.get_node("Neck").rotation.x = 0.0

	# C3 casings never pile past 24, and are gone in time
	var most_c := 0
	for i in 10:
		Casings.drop(self, Vector3(46, 1.2, 20), Vector3(1, 0.5, 0), 6)
		await _frames(30)
		most_c = maxi(most_c, Casings.live_count())
	await _frames(660)
	_check("C3 casings never pass 24, and are gone after 10 s", most_c <= Casings.MAX_LIVE and Casings.live_count() == 0,
		"most %d after %d" % [most_c, Casings.live_count()])

	# R16 in arm's reach, F is a pistol-whip, not a kick
	revolver.reset_for_practice()
	var g16 := _fighter(Vector3(38, 0, -1.0))
	g16.set_physics_process(false)
	_put_player(Vector3(38, 1.05, 0))
	await _frames(20)
	kicks.clear()
	await _tap("kick")
	await _frames(30)
	_check("R16 in arm's reach, F whips him with the gun", _near(g16.health, 80.0, 0.1) and kicks.is_empty(),
		"health %.1f kicked %d" % [g16.health, kicks.size()])
	g16.queue_free()

	# R16b further off, F is the kick
	var g16b := _fighter(Vector3(42, 0, -1.8))
	_put_player(Vector3(42, 1.05, 0))
	await _frames(20)
	kicks.clear()
	await _tap("kick")
	await _frames(40)
	_check("R16b out of arm's reach, F kicks", kicks.size() == 1, "kicked %d" % kicks.size())
	g16b.queue_free()

	# R17 a shell point-blank bursts him: arms, legs, head, and gore about
	revolver.reset_for_practice()
	var parts17 := _severed_parts()
	# (The stains are a ring of decals the checks before have filled.)
	Fx.clear()
	var stains17: int = Fx.stains_in_use()
	var g17 := _fighter(Vector3(50, 0, -1.2))
	g17.set_physics_process(false)
	_put_player(Vector3(50, 1.05, 0))
	await _frames(20)
	_aim(g17.global_position + Vector3(0, 1.2, 0))
	revolver.flip_barrel()
	await _frames(12)
	await _tap("throw")
	await _frames(20)
	var chunks17: int = Gore.live_count()
	_check("R17 a shell point-blank bursts a man: limbs and head off, gore and blood about",
		not is_instance_valid(g17) and _severed_parts() - parts17 == 5 and chunks17 >= 8 and Fx.stains_in_use() - stains17 >= 3,
		"parts +%d chunks %d stains +%d" % [_severed_parts() - parts17, chunks17, Fx.stains_in_use() - stains17])

	# R18 a killing shell at 5 m only kills
	await _frames(1300)
	revolver.reset_for_practice()
	var parts18 := _severed_parts()
	var g18 := _fighter(Vector3(54, 0, -5))
	g18.set_physics_process(false)
	g18.health = 20.0
	_put_player(Vector3(54, 1.05, 0))
	await _frames(20)
	_aim(g18.global_position + Vector3(0, 1.2, 0))
	revolver.flip_barrel()
	await _frames(12)
	await _tap("throw")
	await _frames(20)
	_check("R18 a killing shell at 5 m is no gib", not is_instance_valid(g18) and _severed_parts() - parts18 <= 3 and Gore.live_count() == 0,
		"parts +%d chunks %d" % [_severed_parts() - parts18, Gore.live_count()])

	# R19 gore has a ceiling, and clears
	var most := 0
	for i in 10:
		Gore.burst(self, Vector3(58 + i * 0.5, 1.2, -3), Vector3(0, 2, -4), 10)
		most = maxi(most, Gore.live_count())
		await _frames(2)
	await _frames(1300)
	_check("R19 gore never passes 60 pieces, and is gone in time", most <= Gore.MAX_LIVE and Gore.live_count() == 0,
		"most %d after %d" % [most, Gore.live_count()])

	# R20 a man burst before his friends shakes them more than a man shot down
	var plain_drop: float = await _morale_drop(false)
	var gib_drop: float = await _morale_drop(true)
	_check("R20 a gib in front of his friends shakes them more than a plain kill", gib_drop > plain_drop + 0.05,
		"plain %.2f gib %.2f" % [plain_drop, gib_drop])


# Helpers

## Which way a gun's barrel points across the view (degrees, + to the left).
func _yaw_in_view(gun: Node3D) -> float:
	var bore: Vector3 = player.camera.global_basis.inverse() * -gun.global_basis.z
	return rad_to_deg(atan2(-bore.x, -bore.z))


## How far a squad's heart sinks when one of two men is shot down in front
## of the other: by a ball to the head, or burst by a shell point-blank.
func _morale_drop(gib: bool) -> float:
	SquadScript.clear_all()
	GarrisonScript.clear_all()
	revolver_reset()
	var victim := _fighter(Vector3(-40, 0, -1.4))
	var witness := _fighter(Vector3(-37, 0, -3))
	victim._fighter.stays_put = true
	witness.block_chance = 0.0
	_put_player(Vector3(-40, 1.05, 0))
	await _frames(60)
	var squad: RefCounted = SquadScript.of(player)
	var before: float = squad.morale
	_aim(victim.global_position + (Vector3(0, 1.2, 0) if gib else Vector3(0, 1.62, 0)))

	if gib:
		player.revolver.flip_barrel()
		await _frames(12)

	await _tap("throw")
	await _frames(40)
	var drop: float = before - float(squad.morale)
	witness.queue_free()
	await _frames(10)
	return drop


func revolver_reset() -> void:
	player.revolver.reset_for_practice()


## A world point as the viewmodel draws it (pixels): the arms and what they
## hold are drawn with their own field of view (ViewArms.view_fov).
func _on_screen_point(p: Vector3) -> Vector2:
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var grow: float = tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(player.hand._arms.view_fov(cam.fov)) * 0.5)
	return size * 0.5 + (cam.unproject_position(p) - size * 0.5) * grow


## Limbs and heads cut off anyone, lying about (SeveredPart.gd).
func _severed_parts() -> int:
	var count := 0

	for b in get_tree().get_nodes_in_group(&"bodies"):
		if b.get("part") != null:
			count += 1

	return count


func _wield(weapon_id: StringName) -> void:
	player.inventory.select_by_id(weapon_id)


## A guard already fighting you, facing you, who will not strike first.
## Lit, so he can see who he is fighting.
func _fighter(at: Vector3) -> CharacterBody3D:
	# A new fight: no dread carried over from the last one's dead.
	GarrisonScript.clear_all()
	var g := _new_guard(at, 0.0)
	g.block_chance = 0.0
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g.rotation.y = PI
	g._engage(player)
	return g


func _new_guard(at: Vector3, yaw: float) -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.debug_ai = false
	g.position = at
	g.rotation.y = yaw
	add_child(g)
	return g


func _put_player(at: Vector3) -> void:
	_release_all()
	player.movement_state = 0
	player.current_move = null
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	player.get_node("Neck").rotation.x = 0.0
	player.combat._reset()
	player.combat.adrenaline = 0.0


func _aim(target: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck").global_position
	var d := target - eye
	player.rotation.y = atan2(-d.x, -d.z)
	player.get_node("Neck").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "block", "kick", "reload", "barrel", "aim", "blink", "spell_1", "spell_2", "spell_3"]:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
