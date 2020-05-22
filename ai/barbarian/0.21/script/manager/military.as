#include "../role.as"


namespace Military {

IUnitTask@ MakeTask(CCircuitUnit@ unit)
{
	return aiMilitaryMgr.DefaultMakeTask(unit);
}

/*
 * anti-air threat threshold;
 * air factories will stop production when AA threat exceeds
 */
bool IsAirValid()
{
	return aiEnemyMgr.GetEnemyThreat(RT::AA) <= 80.f;
}

}  // namespace Military
