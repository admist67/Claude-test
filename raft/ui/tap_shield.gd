class_name TapShield
extends Control
## Covers a freshly opened screen for a moment and swallows touches, so the tap that
## opened it cannot press a button that has not been laid out yet. Frees itself.

const TIME := 0.3


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIME, true).timeout.connect(queue_free)
