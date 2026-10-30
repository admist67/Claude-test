extends RefCounted
## The capture bot, v0.17: a wild parrot on an island, tamed with fruit and named; on the
## raft: fed by hand, eating from its perch's bowl, bringing a find, screaming over the
## shark, chasing a gull, asleep at night, hungry. Called from tools/capture.gd.


func run(g: Variant) -> void:
	var raft: Raft = g.raft
	var cc := func(x: int, z: int) -> Vector3: return raft.cell_center(Vector2i(x, z))
	var islands: Islands = g.trips.islands
	islands.clear()
	islands.want_parrot = true
	islands.allow_parrot = true
	islands._spawn(4242)
	var isl: Island = islands.island
	var spot: IslandSpot = null
	for sp in isl.spots:
		if sp.kind == "parrot":
			spot = sp
	print("wild parrot on the island: ", spot != null, " already tamed ", g.pets.tamed)
	if spot == null:
		return
	for c in isl.crabs:
		c.queue_free()
	isl.crabs.clear()
	# Turn the island so its branch faces the raft, then bring it close to the raft's edge.
	var off := spot.global_position - isl.global_position
	isl.rotation.y += atan2(off.z, off.x) - PI
	off = spot.global_position - isl.global_position
	var edge: Vector3 = raft.to_global(cc.call(8, 1) + Vector3(3.2, 0, 0))
	isl.position = Vector3(edge.x - off.x, isl.position.y, edge.z - off.z)
	g.hand = ""
	g._refresh_hotbar()
	g.player.place(cc.call(8, 1) + Vector3(0.3, 0, 0), 0.0)
	g._aim_local(raft.to_local(spot.global_position) + Vector3(0, 1.45, 0))
	await g._wait(0.8)
	print("wild parrot prompt: ", g.use_view()["label"])
	await g._shot("104_wild_parrot")
	g.inv.add("banana", 3)
	g.inv.add("pineapple", 2)
	g.inv.add("seeds", 4)
	for i in 3:
		g.pets.tame(spot)
		await g._wait(0.6)
	print("tamed ", g.pets.tamed, " goal stats ", g.stats.get("parrot_fed", 0), " ", g.stats.get("parrot_tamed", 0))
	await g._wait(0.4)
	await g._shot("105_name")
	for b: Button in g.menus.find_children("*", "Button", true, false):
		if b.text == "Готово":
			b.pressed.emit()
	await g._wait(2.5)
	var pet: Parrot = g.pets.pet
	print("pet on the raft ", pet != null and pet.get_parent() == raft, " name ", g.pets.pet_name)
	# On the raft: aim at it, feed it.
	while pet.mode == Parrot.Mode.FLY:
		await g._wait(0.2)
	# Sit it on the deck in front of the player for a good look.
	g.pets._move_t = 99.0
	var stand: Vector3 = cc.call(8, 1) + Vector3(0.45, 0, 0.3)
	g.player.place(stand, 0.0)
	pet.position = cc.call(8, 1) + Vector3(-0.8, 0, 0.3)
	pet.face_to(stand)
	g._aim_local(pet.position + Vector3(0, 0.3, 0))
	await g._wait(0.6)
	print("pet prompt: ", g.use_view()["label"], " mode ", g.mode)
	await g._shot("107_parrot_raft")
	g.pets.satiety = 40.0
	g._on_pressed("use")
	await g._wait(0.4)
	print("fed: satiety ", snappedf(g.pets.satiety, 1.0))
	await g._shot("108_feed")
	# A perch with food in its bowl: it goes and eats when peckish.
	var perch: Part = null
	for at: Vector3 in [cc.call(7, 2), cc.call(6, 2), cc.call(5, 2), cc.call(7, 1)]:
		perch = raft.parts.put_free("perch", Vector2(at.x + 0.3, at.z), 0.0, 0)
		if perch:
			break
	print("perch built ", perch != null)
	if perch:
		g.pets.fill_bowl(perch)
		g.pets.fill_bowl(perch)
		print("bowl ", perch.fish, " prompt ", perch.prompt(g.inv)["text"])
		g.pets.satiety = 45.0
		g.pets._move_t = 99.0
		var tb := 0.0
		while perch.fish == 2 and tb < 8.0:
			await g._wait(0.2)
			tb += 0.2
		print("ate from the bowl: left ", perch.fish, " satiety ", snappedf(g.pets.satiety, 1.0))
		g.player.place(perch.position + Vector3(0.6, 0, 1.6), 0.0)
		g._aim_local(perch.position + Vector3(0, 1.0, 0))
		await g._wait(0.6)
		await g._shot("109_perch_bowl")
	# A trip over the sea for a find.
	g.pets.satiety = 90.0
	g.pets._task = ""
	g.pets._fetch_t = 0.0
	var gifts: int = g.stats.get("parrot_gifts", 0)
	var tf := 0.0
	while int(g.stats.get("parrot_gifts", 0)) == gifts and tf < 30.0:
		await g._wait(0.25)
		tf += 0.25
		if g.pets._task == "back" and pet.mode == Parrot.Mode.FLY and tf > 1.0 and not g.has_meta("shot_back"):
			g.set_meta("shot_back", true)
			g._aim_local(pet.position)
			await g._shot("110_fetch_back")
	print("gift brought ", int(g.stats.get("parrot_gifts", 0)) > gifts, " after ", tf, " s")
	# The shark: it screams and hovers over the bitten tile.
	var sh: Shark = g.shark
	sh.enabled = true
	sh.visible = true
	sh.state = Shark.State.CIRCLE
	sh._timer = 0.01
	await g._wait(1.6)
	print("guarding ", g.pets._task, " hover ", pet.mode == Parrot.Mode.HOVER or pet.mode == Parrot.Mode.FLY)
	g._aim_local(pet.position)
	await g._wait(0.6)
	await g._shot("111_guard")
	sh.reset(600.0)
	# A gull for the planter: chased off.
	var planter: Station = null
	for st: Station in raft.stations.values():
		if st.kind == "planter":
			planter = st
	if planter:
		for p: Part in raft.parts.free_of("scarecrow"):
			raft.parts.remove_part(p)
		planter.cooking = "seeds"
		planter.ready_item = ""
		planter._refresh()
		g.pets._task = ""
		g.pets.satiety = 90.0
		var gulls: Gulls = g.actions.gulls
		gulls._spawn(planter)
		gulls.gull.global_position = planter.global_position + Vector3(4.0, 3.0, 3.0)
		var tg := 0.0
		while int(g.stats.get("parrot_gulls", 0)) == 0 and tg < 12.0:
			await g._wait(0.2)
			tg += 0.2
			if tg > 0.8 and tg < 1.0:
				g._aim_local(pet.position)
				await g._shot("112_gull_chase")
		print("parrot chased the gull ", int(g.stats.get("parrot_gulls", 0)) > 0, " after ", snappedf(tg, 0.1), " s")
	# Night: asleep on its perch. Hungry: sulks and asks.
	g.daynight.phase = 0.74
	await g._wait(3.5)
	print("asleep ", pet.mode == Parrot.Mode.SLEEP, " task ", g.pets._task)
	g._aim_local(pet.position + Vector3(0, 0.3, 0))
	await g._wait(0.4)
	await g._shot("113_parrot_sleep")
	g.daynight.phase = 0.3
	await g._wait(1.0)
	g.pets.satiety = 10.0
	g.pets._talk_t = 0.0
	await g._wait(0.4)
	g._aim_local(pet.position + Vector3(0, 0.3, 0))
	await g._wait(0.3)
	print("hungry ", pet.hungry)
	await g._shot("114_hungry")
	g.pets.satiety = 80.0
