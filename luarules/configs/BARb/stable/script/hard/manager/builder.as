#include "../../unit.as"


namespace Builder {

CCircuitUnit@ energizer1 = null;
CCircuitUnit@ energizer2 = null;

IUnitTask@ AiMakeTask(CCircuitUnit@ unit)
{
	return aiBuilderMgr.DefaultMakeTask(unit);
}

void AiTaskAdded(IUnitTask@ task)
{
}

void AiTaskRemoved(IUnitTask@ task, bool done)
{
}

void AiUnitAdded(CCircuitUnit@ unit, Unit::UseAs usage)
{
	const CCircuitDef@ cdef = unit.circuitDef;
	if (usage != Unit::UseAs::BUILDER || cdef.IsRoleAny(Unit::Role::COMM.mask))
		return;

	// constructor with BASE attribute is assigned to tasks near base
	if (cdef.costM < 200.f) {
		if (energizer1 is null
			&& (uint(cdef.count) > aiMilitaryMgr.GetGuardTaskNum() || cdef.IsAbleToFly()))
		{
			@energizer1 = unit;
			unit.AddAttribute(Unit::Attr::BASE.type);
		}
	} else {
		if (energizer2 is null) {
			@energizer2 = unit;
			unit.AddAttribute(Unit::Attr::BASE.type);
		}
	}
}

void AiUnitRemoved(CCircuitUnit@ unit, Unit::UseAs usage)
{
	if (energizer1 is unit)
		@energizer1 = null;
	else if (energizer2 is unit)
		@energizer2 = null;
}

void AiLoad(IStream& istream)
{
	Id e1id = -1, e2id = -1;
	istream >> e1id >> e2id;
	@energizer1 = ai.GetTeamUnit(e1id);
	@energizer2 = ai.GetTeamUnit(e2id);
	if (energizer1 !is null)
		energizer1.AddAttribute(Unit::Attr::BASE.type);
	if (energizer2 !is null)
		energizer2.AddAttribute(Unit::Attr::BASE.type);
}

void AiSave(OStream& ostream)
{
	ostream << Id(energizer1 !is null ? energizer1.id : -1)
			<< Id(energizer2 !is null ? energizer2.id : -1);
}

}  // namespace Builder
