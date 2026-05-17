extends Node2D
## Main scene controller — minimal runtime setup.
## All nodes are placed in the scene tree (main.tscn).
## Scripts only handle behavior, not creation.

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.06, 0.1))
