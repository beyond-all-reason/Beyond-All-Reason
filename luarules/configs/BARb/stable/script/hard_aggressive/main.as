#include "manager/military.as"
#include "manager/builder.as"
#include "manager/factory.as"
#include "manager/economy.as"


namespace Main {

void AiMain()
{
	// NOTE: Initialize config params
// 	aiTerrainMgr.SetAllyZoneRange(600);  // returns 576: (multiples of 128) div 2
// 	aiEconomyMgr.reclConvertEff = 2.f;
// 	aiEconomyMgr.reclEnergyEff = 20.f;
// 	for (Id defId = 1, count = ai.GetDefCount(); defId <= count; ++defId) {
// 		CCircuitDef@ cdef = ai.GetCircuitDef(defId);
// 		AiLog(cdef.GetName() + " | threat = " + cdef.threat + " | power = " + cdef.power +
// 			" | air = " + cdef.GetAirThreat() + " | surf = " + cdef.GetSurfThreat() + " | water = " + cdef.GetWaterThreat());
// 		cdef.SetThreatKernel((cdef.costM + cdef.costE * 0.02f) * 0.001f);
// 	}

	for (Id defId = 1, count = ai.GetDefCount(); defId <= count; ++defId) {
		CCircuitDef@ cdef = ai.GetCircuitDef(defId);
		if (cdef.costM >= 200.f && !cdef.IsMobile() && aiEconomyMgr.GetEnergyMake(cdef) > 1.f)
			cdef.AddAttribute(Unit::Attr::BASE.type);  // Build heavy energy at base
	}

	// Example of user-assigned custom attributes
	array<string> names = {Factory::armalab, Factory::coralab, Factory::legalab, Factory::armavp, Factory::coravp, Factory::legavp,
		Factory::armaap, Factory::coraap, Factory::legaap, Factory::armasy, Factory::corasy};
	for (uint i = 0; i < names.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(names[i]);
		if (cdef !is null)
			Factory::userData[cdef.id].attr |= Factory::Attr::T2;
	}
	names = {Factory::armshltx, Factory::corgant, Factory::leggant};
	for (uint i = 0; i < names.length(); ++i) {
		CCircuitDef@ cdef = ai.GetCircuitDef(names[i]);
		if (cdef !is null)
			Factory::userData[cdef.id].attr |= Factory::Attr::T3;
	}
}

void AiUpdate()  // SlowUpdate, every 30 frames with initial offset of skirmishAIId
{
}

}  // namespace Main
