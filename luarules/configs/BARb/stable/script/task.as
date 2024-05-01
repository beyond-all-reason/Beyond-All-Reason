#include "define.as"


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
	RECRUIT,
	TERRAFORM,
	_SIZE_,  // selectable tasks count
	PATROL, GUARD, COMBAT, WAIT  // builder actions that can't be reassigned
}

enum FightType {
	RALLY = 0,
	GUARD,
	DEFEND,
	SCOUT,
	RAID,
	ATTACK,
	BOMB,
	MELEE,
	ARTY,
	AA,
	AH,
	SUPPORT,
	SUPER,
	_SIZE_
}

}  // namespace Task


namespace TaskB {

SBuildTask Common(Task::BuildType type, Task::Priority priority,
		CCircuitDef@ buildDef, const AIFloat3& in position,
		float shake = SQUARE_SIZE * 32,  // Alter/randomize position by offset
		bool isActive = true,  // Should task go to general queue or remain detached?
		int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = type;
	ti.priority = priority;
	@ti.buildDef = buildDef;
	ti.position = position;
	ti.shake = shake;
	ti.isActive = isActive;
	ti.timeout = timeout;

	ti.cost = SResource(0.f, 0.f);
	@ti.reprDef = null;
	ti.pointId = -1;
	ti.isPlop = false;
	return ti;
}
SBuildTask Spot(Task::BuildType type, Task::Priority priority,
		CCircuitDef@ buildDef, const AIFloat3& in position, int spotId,
		bool isActive = true, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = type;
	ti.priority = priority;
	@ti.buildDef = buildDef;
	ti.position = position;
	ti.spotId = spotId;
	ti.isActive = isActive;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Factory(Task::Priority priority, CCircuitDef@ buildDef,
		const AIFloat3& in position, CCircuitDef@ reprDef,
		float shake = SQUARE_SIZE * 32, bool isPlop = false,
		bool isActive = true, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = Task::BuildType::FACTORY;
	ti.priority = priority;
	@ti.buildDef = buildDef;
	ti.position = position;
	@ti.reprDef = reprDef;
	ti.shake = shake;
	ti.isPlop = isPlop;
	ti.isActive = isActive;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Pylon(Task::Priority priority, CCircuitDef@ buildDef,
		const AIFloat3& in position/*, IGridLink@ link*/, float cost,
		bool isActive = true, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = Task::BuildType::PYLON;
	ti.priority = priority;
	@ti.buildDef = buildDef;
	ti.position = position;
	ti.cost.metal = cost;
	ti.cost.energy = 0.f;
// 	@ti.link = link;
	ti.isActive = isActive;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Repair(Task::Priority priority,
		CCircuitUnit@ target, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = Task::BuildType::REPAIR;
	ti.priority = priority;
	@ti.target = target;
	ti.isActive = true;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Reclaim(Task::Priority priority,
		const AIFloat3& in position, float cost,
		int timeout, float radius = .0f, bool isMetal = true)
{
	SBuildTask ti;
	ti.type = Task::BuildType::RECLAIM;
	ti.priority = priority;
	ti.position = position;
	ti.cost = SResource(cost, 0.f);
	@ti.target = null;
	ti.radius = radius;
	ti.isMetal = isMetal;
	ti.isActive = true;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Reclaim(Task::Priority priority,
		CCircuitUnit@ target, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = Task::BuildType::RECLAIM;
	ti.priority = priority;
	@ti.target = target;
	ti.isActive = true;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Resurrect(Task::Priority priority,
		const AIFloat3& in position, float cost,
		int timeout, float radius = .0f)
{
	SBuildTask ti;
	ti.type = Task::BuildType::RESURRECT;
	ti.priority = priority;
	ti.position = position;
	ti.cost = SResource(cost, 0.f);
	ti.radius = radius;
	ti.isActive = true;
	ti.timeout = timeout;
	return ti;
}
SBuildTask Terraform(Task::Priority priority,
		CCircuitUnit@ target, const AIFloat3& in position = -RgtVector,
		float cost = 1.0f, bool isActive = true, int timeout = ASSIGN_TIMEOUT)
{
	SBuildTask ti;
	ti.type = Task::BuildType::TERRAFORM;
	ti.priority = priority;
	ti.position = position;
	ti.cost = SResource(cost, 0.f);
	@ti.target = target;
	ti.isActive = isActive;
	ti.timeout = timeout;
	return ti;
}

SServBTask Patrol(Task::Priority priority,
		const AIFloat3& in position, int timeout)
{
	SServBTask ti;
	ti.type = Task::BuildType::PATROL;
	ti.priority = priority;
	ti.position = position;
	ti.timeout = timeout;
	return ti;
}
SServBTask Guard(Task::Priority priority,
		CCircuitUnit@ target, bool isInterrupt, int timeout = ASSIGN_TIMEOUT)
{
	SServBTask ti;
	ti.type = Task::BuildType::GUARD;
	ti.priority = priority;
	@ti.target = target;
	ti.isInterrupt = isInterrupt;
	ti.timeout = timeout;
	return ti;
}
SServBTask Combat(float powerMod)
{
	SServBTask ti;
	ti.type = Task::BuildType::COMBAT;
	ti.powerMod = powerMod;
	return ti;
}
SServBTask Wait(int timeout)
{
	SServBTask ti;
	ti.type = Task::BuildType::WAIT;
	ti.timeout = timeout;
	return ti;
}

}  // namespace TaskB


namespace TaskS {

SRecruitTask Recruit(Task::RecruitType type,
		Task::Priority priority, CCircuitDef@ buildDef,
		const AIFloat3& in position, float radius)
{
	SRecruitTask ti;
	ti.type = type;
	ti.priority = priority;
	@ti.buildDef = buildDef;
	ti.position = position;
	ti.radius = radius;
	return ti;
}

SServSTask Repair(Task::Priority priority, CCircuitUnit@ target)  // FIXME: CAllyUnit@
{
	SServSTask ti;
	ti.type = Task::BuildType::REPAIR;
	ti.priority = priority;
	@ti.target = target;
	return ti;
}
SServSTask Reclaim(Task::Priority priority,
		const AIFloat3& in position, float radius, int timeout = 0)
{
	SServSTask ti;
	ti.type = Task::BuildType::RECLAIM;
	ti.priority = priority;
	ti.position = position;
	ti.radius = radius;
	ti.timeout = timeout;
	return ti;
}
SServSTask Wait(bool stop, int timeout)
{
	SServSTask ti;
	ti.type = Task::BuildType::WAIT;
	ti.stop = stop;
	ti.timeout = timeout;
	return ti;
}

}  // namespace TaskS


namespace TaskF {

SFightTask Common(Task::FightType type)
{
	SFightTask ti;
	ti.type = type;

	ti.check = type;
	ti.promote = type;
	ti.power = 0.f;
	@ti.vip = null;
	return ti;
}
SFightTask Guard(CCircuitUnit@ vip)
{
	SFightTask ti;
	ti.type = Task::FightType::GUARD;
	@ti.vip = vip;
	return ti;
}
SFightTask Defend(Task::FightType promote, float power)
{
	SFightTask ti;
	ti.type = Task::FightType::DEFEND;
	ti.check = Task::FightType::_SIZE_;  // NONE
	ti.promote = promote;
	ti.power = power;
	return ti;
}
SFightTask Defend(Task::FightType check, Task::FightType promote, float power)
{
	SFightTask ti;
	ti.type = Task::FightType::DEFEND;
	ti.check = check;
	ti.promote = promote;
	ti.power = power;
	return ti;
}

}  // namespace TaskF
