extends Resource
class_name VoiceLineResource

## Одна озвученная фраза бога: аудио-файл + текст, показываемый в облачке
## диалога у головы бога, когда фраза звучит (см. AbilityResource.voice_lines,
## Combatant.voice_line_used, CombatantVisual.show_voice_line).

@export var audio: AudioStream
@export_multiline var text: String = ""
