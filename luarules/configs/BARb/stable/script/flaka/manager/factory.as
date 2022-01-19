#include "../../define.as"


namespace Factory {

string armlab ("armlab");
string armalab("armalab");
string armvp  ("armvp");
string armavp ("armavp");

Id LAB  = ai.GetCircuitDef(armlab).id;
Id ALAB = ai.GetCircuitDef(armalab).id;
Id VP   = ai.GetCircuitDef(armvp).id;
Id AVP  = ai.GetCircuitDef(armavp).id;

float switchLimit = MakeSwitchLimit();

IUnitTask@ AiMakeTask(CCircuitUnit@ unit)
{
	return aiFactoryMgr.DefaultMakeTask(unit);
}

void AiTaskCreated(IUnitTask@ task)
{
}

void AiTaskClosed(IUnitTask@ task, bool done)
{
}

/*
 * New factory switch condition; switch event is also based on eco + caretakers.
 */
bool AiIsSwitchTime(int lastSwitchFrame)
{
	const float value = pow((ai.frame - lastSwitchFrame), 0.9) * aiEconomyMgr.metal.income + (aiEconomyMgr.metal.current * 5);
	if (value > switchLimit) {
		switchLimit = MakeSwitchLimit();
		return true;
	}
	return false;
}

bool AiIsSwitchAllowed(CCircuitDef@ facDef)
{
	return true;
}

/* --- Utils --- */

float MakeSwitchLimit()
{
	return AiRandom(11000, 17000) * SECOND;
}

}  // namespace Factory
