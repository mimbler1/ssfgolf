class_name GolferStage
extends Control
## A live, animated ink golfer standing at the bottom of a control (results winner, menus).
## The golfer is scaled from the control's height, leaving headroom for raised arms and hats.

var golfer := Golfer.new()
var headroom := 0.3


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(golfer)
	resized.connect(_layout)


func set_look(appearance: Dictionary, anim: String = "idle") -> void:
	golfer.set_appearance(appearance)
	golfer.play(anim)
	_layout()


func _layout() -> void:
	var k := size.y / (Golfer.STANDARD_HEIGHT * (1.0 + headroom))
	golfer.scale = Vector2(k, k)
	golfer.position = Vector2(size.x * 0.5 - Golfer.BALL_OFFSET * k * 0.3, size.y - 6.0)
