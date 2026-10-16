class_name GolferView
extends Control
## A golfer framed inside a control from its measured artwork bounds
## (CHARACTER_ART_SPEC §6). Used by character cards, item thumbnails and saved looks.
##
## - `frame` (optional): a shared rig-space frame for a whole grid. Every view in the grid then
##   uses one scale and one ground baseline, so real size differences between characters stay
##   visible and nothing jumps around between cards.
## - `focus = "head"` frames just the head and headwear (face and hat pickers).
##
## Views are static by default: the golfer is drawn once (frozen clock, no per-frame redraw), so a
## grid of hundreds of cards costs nothing per frame. `set_animated(true)` brings one view to life
## (hover, selection); the big studio preview is a separate live Golfer.

var golfer: Golfer
var look: Dictionary = {}
var focus := "full"
var frame := Rect2()               ## shared rig-space frame; empty = use this golfer's own bounds
var pad := Vector2(12, 10)
var background := Color(0, 0, 0, 0)
var radius := 14
var _look_key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	golfer = Golfer.new()
	golfer.frozen_time = true
	golfer.set_process(false)
	add_child(golfer)
	resized.connect(_layout)


## Starts or stops this view's animation. A stopped view returns to its first idle frame.
func set_animated(on: bool) -> void:
	golfer.frozen_time = not on
	golfer.set_process(on)
	if not on:
		golfer.play("idle")
		golfer.set_time(0.0, 0.0)


func set_look(a: Dictionary, anim: String = "idle") -> void:
	# Skip identical looks: re-applying one costs a character rebuild and a redraw for nothing.
	var key := JSON.stringify(a)
	if key == _look_key and (anim == "" or golfer.anim == anim):
		return
	_look_key = key
	look = a
	golfer.set_appearance(a)
	if anim != "":
		golfer.play(anim)
	clip_contents = focus == "head"
	_layout()


## Rig-space bounds this view frames.
func framed_bounds() -> Rect2:
	if focus == "head":
		return Golfer.head_bounds(look).grow(3.0)
	return frame if frame.has_area() else Golfer.idle_bounds(look)


func _layout() -> void:
	if look.is_empty() or size.x <= 0.0:
		return
	var b := framed_bounds()
	var avail := size - pad * 2.0
	var s := minf(avail.x / maxf(1.0, b.size.x), avail.y / maxf(1.0, b.size.y))
	golfer.scale = Vector2(s, s)
	# Centre on this golfer's own bounds horizontally; share the frame's baseline vertically.
	var own := Golfer.idle_bounds(look) if focus != "head" else b
	var x := size.x * 0.5 - (own.position.x + own.size.x * 0.5) * s
	var y := pad.y + (avail.y - b.size.y * s) * 0.5 - b.position.y * s
	golfer.position = Vector2(x, y)
	queue_redraw()


func _draw() -> void:
	if background.a > 0.0:
		draw_style_box(UITheme.box(background, radius), Rect2(Vector2.ZERO, size))


## Shared frame covering every look in `looks` (union of their idle bounds).
static func shared_frame(looks: Array) -> Rect2:
	var r := Rect2()
	for i in looks.size():
		var b := Golfer.idle_bounds(looks[i])
		r = b if i == 0 else r.merge(b)
	return r
