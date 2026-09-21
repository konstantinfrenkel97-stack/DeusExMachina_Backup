extends RefCounted
class_name RealTimeWait

## Ждёт seconds РЕАЛЬНОГО (wall-clock) времени, независимо от Engine.time_scale —
## даже когда он ровно 0.0 (пока держится пауза боя, см. battle_scene.gd::
## _adjust_attack_effect_count). Обходит баг движка: SceneTree.create_timer(...,
## ignore_time_scale=true) при time_scale ровно 0.0 срабатывает почти мгновенно
## вместо честного отсчёта реального времени (проверено эмпирически: запрошенные
## 300ms при time_scale=0.0 завершались за ~8ms). Tween.set_ignore_time_scale()
## этим багом не страдает и отрабатывает корректно — там его использовать можно
## и нужно (см. CombatantVisual.show_attack_effect_flash, scene_transition.gd).
static func wait(node: Node, seconds: float) -> void:
	var start := Time.get_ticks_msec()
	var target_ms := int(seconds * 1000.0)
	while Time.get_ticks_msec() - start < target_ms:
		await node.get_tree().process_frame
