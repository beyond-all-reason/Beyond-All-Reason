#include "manager/military.as"
#include "manager/builder.as"
#include "manager/factory.as"
#include "manager/economy.as"
#include "../common.as"


namespace Main {

void AiMain()  // Initialize config params
{
	Init::EnableWallTargets();
}

void AiUpdate()  // SlowUpdate, every 30 frames with initial offset of skirmishAIId
{
}

}  // namespace Main
