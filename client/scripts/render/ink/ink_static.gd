class_name InkStatic
extends Node2D
## Draws prebuilt InkCanvas geometry once. Godot keeps the commands, so static art costs nothing
## per frame. Set `mesh` instead of `canvas` to share one GPU mesh between several nodes.

var canvas: InkCanvas
var mesh: ArrayMesh


func _draw() -> void:
	if mesh:
		draw_mesh(mesh, null)
	elif canvas:
		canvas.submit(get_canvas_item())
