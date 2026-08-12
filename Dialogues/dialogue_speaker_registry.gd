extends Resource
class_name DialogueSpeakerRegistry

@export var profiles: Array[DialogueSpeakerProfile] = []

func find_profile(speaker_name: String) -> DialogueSpeakerProfile:
	var clean_name := speaker_name.strip_edges()
	if clean_name == "":
		return null
	for profile in profiles:
		if profile != null and profile.matches(clean_name):
			return profile
	return null