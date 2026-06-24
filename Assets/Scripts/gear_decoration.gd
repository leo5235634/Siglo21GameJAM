extends Control
class_name GearDecoration

@export var corner: int = 0
@export var ink_color: Color = Color(0.28, 0.07, 0.03, 0.82)
@export var brass_color: Color = Color(0.78, 0.42, 0.08, 0.72)
@export var pale_color: Color = Color(0.92, 0.72, 0.32, 0.35)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var origin: Vector2 = _get_origin()
	var direction: Vector2 = _get_direction()
	_draw_gear(origin, 58.0, 0.0)
	_draw_gear(origin + Vector2(72.0 * direction.x, 22.0 * direction.y), 34.0, 0.6)
	_draw_gear(origin + Vector2(24.0 * direction.x, 78.0 * direction.y), 26.0, 1.1)
	draw_arc(origin + Vector2(116.0 * direction.x, 94.0 * direction.y), 88.0, 0.0, TAU, 56, pale_color, 2.0)

func _get_origin() -> Vector2:
	match corner:
		1:
			return Vector2(size.x - 18.0, 18.0)
		2:
			return Vector2(18.0, size.y - 18.0)
		3:
			return Vector2(size.x - 18.0, size.y - 18.0)
	return Vector2(18.0, 18.0)

func _get_direction() -> Vector2:
	return Vector2(-1.0 if corner == 1 or corner == 3 else 1.0, -1.0 if corner == 2 or corner == 3 else 1.0)

func _draw_gear(center: Vector2, radius: float, angle_offset: float) -> void:
	draw_circle(center, radius, Color(brass_color.r, brass_color.g, brass_color.b, brass_color.a * 0.45))
	draw_arc(center, radius, 0.0, TAU, 64, ink_color, 4.0)
	draw_arc(center, radius * 0.58, 0.0, TAU, 48, ink_color, 3.0)
	draw_circle(center, radius * 0.18, ink_color)
	for tooth in range(12):
		var angle: float = angle_offset + TAU * float(tooth) / 12.0
		var outward: Vector2 = Vector2(cos(angle), sin(angle))
		var tangent: Vector2 = Vector2(-outward.y, outward.x)
		var tooth_center: Vector2 = center + outward * radius
		var half_width: float = radius * 0.12
		var points: PackedVector2Array = PackedVector2Array([
			tooth_center - tangent * half_width,
			tooth_center + outward * radius * 0.22 - tangent * half_width,
			tooth_center + outward * radius * 0.22 + tangent * half_width,
			tooth_center + tangent * half_width,
		])
		draw_colored_polygon(points, ink_color)
	for spoke in range(8):
		var angle: float = angle_offset + TAU * float(spoke) / 8.0
		var end_point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.82
		draw_line(center, end_point, ink_color, 2.0)
