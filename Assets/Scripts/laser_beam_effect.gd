extends Node2D
class_name LaserBeamEffect

@export var channel_time: float = 0.12
@export var beam_time: float = 0.28
@export var beam_width: float = 10.0
@export var channel_radius: float = 18.0
@export var beam_color: Color = Color(0.25, 0.9, 1.0, 0.9)

var end_point: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var line: Line2D

func _ready() -> void:
	line = Line2D.new()
	line.default_color = beam_color
	line.width = beam_width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.visible = false
	add_child(line)

func setup(start_position: Vector2, target_position: Vector2, color: Color = beam_color) -> void:
	global_position = start_position
	end_point = target_position - start_position
	beam_color = color
	if line != null:
		line.default_color = beam_color

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < channel_time:
		queue_redraw()
		return
	var beam_progress: float = clampf((elapsed - channel_time) / beam_time, 0.0, 1.0)
	if beam_progress >= 1.0:
		queue_free()
		return
	_update_line(beam_progress)
	queue_redraw()

func _update_line(beam_progress: float) -> void:
	if line == null:
		return
	var start_point: Vector2 = end_point * beam_progress
	line.visible = true
	line.width = lerpf(beam_width, 1.0, beam_progress)
	line.default_color = Color(beam_color.r, beam_color.g, beam_color.b, 1.0 - beam_progress)
	line.points = PackedVector2Array([start_point, end_point])

func _draw() -> void:
	if elapsed >= channel_time:
		return
	var channel_progress: float = clampf(elapsed / channel_time, 0.0, 1.0)
	var radius: float = lerpf(4.0, channel_radius, channel_progress)
	var alpha: float = 1.0 - channel_progress * 0.35
	draw_circle(Vector2.ZERO, radius, Color(beam_color.r, beam_color.g, beam_color.b, alpha))
