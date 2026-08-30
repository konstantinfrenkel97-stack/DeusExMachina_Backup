extends Button
## Кнопка с кликабельной областью по битовой маске (не по прямоугольнику) —
## попадание проверяется по форме, найденной в белой маске фона.
## См. Doors/mission_choice_screen.gd.

var mask: BitMap = null

func _has_point(point: Vector2) -> bool:
	if mask == null or size.x <= 0.0 or size.y <= 0.0:
		return true
	var mask_size: Vector2i = mask.get_size()
	if mask_size.x <= 0 or mask_size.y <= 0:
		return true
	var mx: int = clampi(int(point.x / size.x * mask_size.x), 0, mask_size.x - 1)
	var my: int = clampi(int(point.y / size.y * mask_size.y), 0, mask_size.y - 1)
	return mask.get_bit(mx, my)
