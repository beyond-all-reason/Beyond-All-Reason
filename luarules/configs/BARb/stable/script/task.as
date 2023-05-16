namespace Task {

enum Priority {
	LOW = 0, NORMAL = 1, HIGH = 2, NOW = 99
}

enum Type {
	NIL, PLAYER, IDLE, WAIT, RETREAT, BUILDER, FACTORY, FIGHTER
}

enum RecruitType {
	BUILDPOWER = 0, FIREPOWER
}

enum BuildType {
	FACTORY = 0,
	NANO,
	STORE,
	PYLON,
	ENERGY,
	GEO,
	GEOUP,
	DEFENCE,
	BUNKER,
	BIG_GUN,  // super weapon
	RADAR,
	SONAR,
	CONVERT,
	MEX,
	MEXUP,
	REPAIR,
	RECLAIM,
	RESURRECT,
	TERRAFORM
}

}  // namespace Task
