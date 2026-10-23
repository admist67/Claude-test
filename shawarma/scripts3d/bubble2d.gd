extends Node2D
## The order bubble drawn in 2D (into a SubViewport shown above a 3D customer):
## ingredient icons, patience bar and the customer-type badge.

const W := 300
const H := 240

var order: Order
var patience := 1.0
var type_id := ""


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if order == null:
		return
	var icons: Array = ["meat"]
	icons.append_array(order.items)
	var cols := mini(icons.size(), 3)
	var rows := int(ceil(icons.size() / 3.0))
	var cell := 64.0
	var bw := cols * cell + 30.0
	var bh := rows * cell + 44.0
	var r := Rect2(W / 2.0 - bw / 2.0, H - 30.0 - bh, bw, bh)
	DU.rect(self, r, 24.0, Color.WHITE, 5.0, 7.0)
	var tip := Vector2(W / 2.0, H - 12.0)
	DU.poly(self, PackedVector2Array([tip + Vector2(-14, -22), tip + Vector2(14, -22), tip]), Color.WHITE, 0.0)
	draw_polyline(PackedVector2Array([tip + Vector2(-14, -19), tip, tip + Vector2(14, -19)]), DU.INK, 5.0, true)
	for i in icons.size():
		var in_row := mini(icons.size() - (i / 3) * 3, 3)
		var cx := W / 2.0 - in_row * cell / 2.0 + cell / 2.0 + (i % 3) * cell
		var cy := r.position.y + 14.0 + cell / 2.0 + (i / 3) * cell
		DU.ing(self, icons[i], Vector2(cx, cy), 25.0, 3.0)
		if i == 0 and order.meat == 2:
			DU.circle(self, Vector2(cx + 22, cy - 20), 15.0, DU.RED, 3.0)
			DU.text(self, Vector2(cx + 22, cy - 21), "x2", 17, Color.WHITE)
	var bar := Rect2(r.position.x + 16, r.end.y - 24, bw - 32, 12)
	draw_colored_polygon(DU.rrect_pts(bar, 6.0), Color("#e6e1ee"))
	if patience > 0.02:
		var col := DU.GREEN if patience > 0.5 else (DU.GOLD if patience > 0.25 else DU.RED)
		draw_colored_polygon(DU.rrect_pts(Rect2(bar.position, Vector2(bar.size.x * patience, bar.size.y)), 6.0), col)
	draw_polyline(DU.closed(DU.rrect_pts(bar, 6.0)), DU.INK, 3.0, true)
	if type_id in ["hurry", "gourmet", "taxi"]:
		var badge := r.position + Vector2(8, 8)
		var bc: Color = {"hurry": DU.RED, "gourmet": Color("#8e7dff"), "taxi": Color("#ffcc33")}[type_id]
		DU.circle(self, badge, 18.0, bc, 3.5)
		match type_id:
			"hurry":
				draw_line(badge, badge + Vector2(0, -10), DU.INK, 3.5)
				draw_line(badge, badge + Vector2(7, 3), DU.INK, 3.5)
			"gourmet":
				DU.star(self, badge, 11.0, DU.GOLD, 2.5)
			"taxi":
				DU.text(self, badge, "T", 19, DU.INK)
