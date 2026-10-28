extends RefCounted
## More of the capture bot (v0.13 on): the name tip riding along a scrolled list, the new
## food and gear, the sail, the drying rack, a gull at the planter and the scarecrow.
## Called from tools/capture.gd with the running game.


func run(g: Variant) -> void:
	var raft: Raft = g.raft
	var cc := func(x: int, z: int) -> Vector3: return raft.cell_center(Vector2i(x, z))
	var new_things := ["fish", "big_fish", "fish_cooked", "big_fish_cooked", "shark_meat", "shark_steak", "dried_fish", "fish_soup", "kebab",
			"medkit", "nails", "flippers", "metal_rod"]
	for id: String in new_things:
		g.inv.add(id, 1 if id in ["flippers", "metal_rod"] else 2)
	g.inv.add("plastic", 6)
	# The bag: a name over a tapped item stays over it while the list scrolls.
	g._open_bag()
	g.bag._show(0)
	await g._wait(0.4)
	await g._shot("83_bag_food")
	g.bag._scroller.scroll_vertical = 100000
	await g._wait(0.3)
	var taps: Array = g.bag._scroller._taps
	var tapped: Control = taps[taps.size() - 1][0]
	taps[taps.size() - 1][1].call()
	await g._wait(0.5)
	var before := tapped.get_global_rect().position.y - (g.bag._tip.position as Vector2).y
	g.bag._scroller.scroll_vertical -= 120
	await g._wait(0.3)
	var after := tapped.get_global_rect().position.y - (g.bag._tip.position as Vector2).y
	print("tip follows: gap before ", snappedf(before, 1.0), " after ", snappedf(after, 1.0), " visible ", g.bag._tip.visible)
	await g._shot("84_tip_scrolled")
	g._close_bag()
	# Fish lies flat on the grill.
	for st: Station in raft.stations.values():
		if st.kind == "grill":
			st.cooking = "big_fish"
			st.ready_item = ""
			st._refresh()
			g.player.place(st.position + Vector3(0.3, 0, -1.3), 0.0)
			g._aim_local(st.position + Vector3(0, 0.95, 0))
			break
	g.hand = ""
	g._refresh_hotbar()
	await g._wait(0.5)
	await g._shot("85_grill_fish")
	# The sail and the drying rack on a new strip of raft.
	for c: Vector2i in [Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)]:
		raft.add_tile(c)
	var sail := raft.add_station("sail", Vector3i(6, 3, 0), Data.build_by_id["sail"])
	var rack := raft.add_station("rack", Vector3i(5, 3, 0), Data.build_by_id["rack"])
	print("rack: ", rack.start(g.inv, "fish"))
	g.player.place(cc.call(6, 2), 0.0)
	g._aim_local(sail.position + Vector3(0, 0.5, 0))
	await g._wait(0.4)
	print("sail prompt ", g.use_view()["label"])
	g._on_pressed("use")
	g.player.place(cc.call(5, 1) + Vector3(0.3, 0, -0.3), 0.0)
	await g._wait(1.6)
	print("sailing ", g.trips.sailing(), " island pace ", g.trips.islands.pace, " debris pace ", g.trips.debris_pace(), " sail_up ", g.stats.get("sail_up", 0))
	g._aim_local(sail.position + Vector3(0, 2.0, 0))
	g.player.yaw += 0.35
	await g._wait(0.3)
	await g._shot("86_sail_up")
	g._aim_local(rack.position + Vector3(0, 0.9, 0))
	await g._wait(0.3)
	await g._shot("88_rack")
	rack.progress = float(rack.def["time"]) - 0.1
	await g._wait(0.4)
	print("rack ready ", rack.ready_item)
	# A gull comes for the planter; a spear sends it off; a scarecrow keeps it away.
	var planter: Station = null
	for st: Station in raft.stations.values():
		if st.kind == "planter":
			planter = st
	if planter:
		planter.ready_item = ""
		planter.cooking = "seeds"
		planter.progress = 60.0
		planter._refresh()
		var gulls: Gulls = g.actions.gulls
		gulls._spawn(planter)
		gulls.gull.global_position = gulls.gull.perch() + Vector3(1.5, 1.2, 0.5)
		g.player.place(planter.position + Vector3(-1.2, 0, 1.3), 0.0)
		g._aim_local(planter.position + Vector3(0.3, 0.6, 0))
		g.inv.add("spear")
		g._select("spear")
		await g._wait(1.5)
		print("gull state ", gulls.gull.state, " spear ok ", g.action_view()["ok"])
		await g._shot("90_gull")
		g._aim_local(raft.to_local(gulls.gull.global_position) + Vector3(0, 0.15, 0))
		g._stab()
		await g._wait(0.4)
		print("gulls scared ", g.stats.get("gulls_scared", 0))
		await g._shot("91_gull_flee")
		await g._wait(5.5)
		gulls._spawn(planter)
		gulls.gull.global_position = gulls.gull.perch()
		await g._wait(0.2)
		gulls.gull.peck_t = 100.0
		await g._wait(0.3)
		print("after a gull ate: cooking '", planter.cooking, "'")
		planter.cooking = "seeds"
		planter._refresh()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var k := Vector3i(planter.cell.x + d.x, planter.cell.y + d.y, 0)
			if raft.tiles.has(Vector2i(k.x, k.y)) and raft.parts.can_bed(k):
				raft.parts.add("scarecrow", k, 0)
				g._aim_local(raft.cell_center(Vector2i(k.x, k.y)) + Vector3(0, 1.0, 0))
				break
		print("guarded ", gulls.guarded(planter), " scarecrows ", raft.parts.count("scarecrow"))
		await g._wait(0.4)
		await g._shot("89_scarecrow")
	# Flippers in the bag: faster in the water. The strong rod in hand.
	await g._wait(0.1)
	print("swim mult ", g.player.swim_mult)
	g._select("metal_rod")
	g.rod.press(Data.item("metal_rod"))
	g.rod.release()
	print("rod gear bite ", g.rod.gear.get("bite_mult", 1.0))
	g.rod.cancel()
	g._aim(0.3, -0.1)
	await g._wait(0.4)
	await g._shot("92_metal_rod")
	g._select("fish_cooked")
	await g._wait(0.3)
	await g._shot("93_hand_fish")
	g._open_build()
	g.build_panel._show(1)
	await g._wait(0.4)
	await g._shot("94_build_home")
	g._close_build()
