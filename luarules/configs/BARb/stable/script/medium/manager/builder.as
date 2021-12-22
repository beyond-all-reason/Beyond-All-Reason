#include "../../unit.as"


namespace Builder {

IUnitTask@ AiMakeTask(CCircuitUnit@ unit)
{
	return aiBuilderMgr.DefaultMakeTask(unit);
}

void AiTaskCreated(IUnitTask@ task)
{
}

void AiTaskClosed(IUnitTask@ task, bool done)
{
}

void AiWorkerCreated(CCircuitUnit@ unit)
{
}

void AiWorkerDestroyed(CCircuitUnit@ unit)
{
}

}  // namespace Builder
