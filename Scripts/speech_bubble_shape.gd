extends Control
class_name SpeechBubbleShape

## Рисует само облачко реплики — скруглённый прямоугольник с хвостиком снизу,
## как в комиксах/визуальных новеллах (вместо простого прямоугольника). Хвостик
## рисуется КАК ЧАСТЬ одного контура вместе с телом — так нет шва между ними.
## Используется CombatantVisual.show_voice_line().

@export var fill_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var border_width: float = 2.0
@export var corner_radius: float = 10.0
@export var tail_width: float = 18.0
@export var tail_height: float = 12.0
## 0.0 = хвостик у левого края, 1.0 — у правого. По умолчанию по центру низа —
## облачко и так рисуется по центру над головой юнита.
@export var tail_x_ratio: float = 0.5

const ARC_SEGMENTS := 8

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var points := _build_points()
	draw_colored_polygon(points, fill_color)
	if border_width > 0.0:
		var border_points := points.duplicate()
		border_points.append(points[0])
		draw_polyline(border_points, border_color, border_width, true)

func _build_points() -> PackedVector2Array:
	var w := size.x
	var h := size.y
	var r: float = minf(corner_radius, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	_add_arc(pts, Vector2(r, r), r, PI, PI * 1.5)
	_add_arc(pts, Vector2(w - r, r), r, PI * 1.5, PI * 2.0)
	_add_arc(pts, Vector2(w - r, h - r), r, 0.0, PI * 0.5)
	var tail_center_x: float = clampf(w * tail_x_ratio, r + tail_width * 0.5, w - r - tail_width * 0.5) if w > (r * 2.0 + tail_width) else w * 0.5
	var tail_left: float = tail_center_x - tail_width * 0.5
	var tail_right: float = tail_center_x + tail_width * 0.5
	pts.append(Vector2(tail_right, h))
	pts.append(Vector2(tail_center_x, h + tail_height))
	pts.append(Vector2(tail_left, h))
	_add_arc(pts, Vector2(r, h - r), r, PI * 0.5, PI)
	return pts

func _add_arc(pts: PackedVector2Array, center: Vector2, radius: float, angle_from: float, angle_to: float) -> void:
	for i in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var angle: float = lerp(angle_from, angle_to, t)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
