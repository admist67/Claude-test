extends Node
## Autoload "Events": global signals only.

signal item_added(id: String, n: int)
signal crafted(id: String)
signal tile_built(cell: Vector2i)
signal barrel_opened
signal toast(text: String)
