#include "../role.as"


namespace Factory {

string armlab ("armlab");
string armalab("armalab");
string armvp  ("armvp");
string armavp ("armavp");

Id LAB  = ai.GetCircuitDef(armlab).GetId();
Id ALAB = ai.GetCircuitDef(armalab).GetId();
Id VP   = ai.GetCircuitDef(armvp).GetId();
Id AVP  = ai.GetCircuitDef(armavp).GetId();

IUnitTask@ MakeTask(CCircuitUnit@ unit)
{
	return aiFactoryMgr.DefaultMakeTask(unit);
}

}  // namespace Factory
