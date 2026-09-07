extends RefCounted
class_name SurvivorData
## Survivor / family team constants for horror neighborhood mode.

const MAX_FAMILIES: int = 4
const TEAM_LABEL_PREFIX: String = "Family"


static func family_label(index: int) -> String:
	return "%s %d" % [TEAM_LABEL_PREFIX, index + 1]
