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

int switchInterval = MakeSwitchInterval();
int switchFrame = 0;

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
	return (lastSwitchFrame + switchInterval <= ai.frame);
}

bool AiIsSwitchAllowed(CCircuitDef@ facDef)
{
	if (ai.frame - switchFrame >= switchInterval) {
		switchFrame = ai.frame;
		switchInterval = MakeSwitchInterval();
		return true;
	}
	return false;
}

/* --- Utils --- */

int MakeSwitchInterval()
{
	return AiRandom(900, 1200) * SECOND;
}

}  // namespace Factory
