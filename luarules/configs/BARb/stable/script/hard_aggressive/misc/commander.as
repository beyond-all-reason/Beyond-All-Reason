#include "../manager/factory.as"


namespace Commander {

string armcom("armcom");
string corcom("corcom");
string legcom("legcom");

}


namespace Opener {

class SO {  // SOrder
	SO(Type r, uint c = 1) {
		role = r;
		count = c;
	}
	SO() {}
	Type role;
	uint count;
}

class SQueue {
	SQueue(float w, array<SO>& in o) {
		weight = w;
		orders = o;
	}
	SQueue() {}
	float weight;
	array<SO> orders;
}

class SOpener {
	SOpener(dictionary f, array<SO>& in d) {
		factory = f;
		def = d;
	}
	dictionary factory;
	array<SO> def;
}

SOpener@ GetOpenInfo()
{
	return SOpener({
		{Factory::armlab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER), SO(RT::SCOUT, 10), SO(RT::RAIDER, 12), SO(RT::BUILDER)})
		}},
		{Factory::armalab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::HEAVY, 5), SO(RT::ASSAULT, 8), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::AHA, 2), SO(RT::HEAVY), SO(RT::BUILDER2)})
		}},
		{Factory::armavp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::armasy, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::armap, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER), SO(RT::AA), SO(RT::RAIDER), SO(RT::BOMBER), SO(RT::SCOUT)})
		}},
		{Factory::corlab, array<SQueue> = {
			SQueue(0.9f, {SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER, 2)}),
			SQueue(0.1f, {SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RIOT), SO(RT::BUILDER), SO(RT::RAIDER, 4), SO(RT::BUILDER), SO(RT::RAIDER, 2)})
		}},
		{Factory::coralab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::RAIDER, 3), SO(RT::BUILDER2), SO(RT::ARTY, 2), SO(RT::ASSAULT), SO(RT::BUILDER2), SO(RT::AA)})
		}},
		{Factory::coravp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 3), SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::ASSAULT), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::corasy, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::corap, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER), SO(RT::AA), SO(RT::RAIDER), SO(RT::BOMBER), SO(RT::SCOUT)})
		}},
		{Factory::leglab, array<SQueue> = {
			SQueue(0.3f, {SO(RT::BUILDER), SO(RT::SCOUT, 10), SO(RT::RAIDER, 12), SO(RT::BUILDER)})
		}},
		{Factory::legalab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::HEAVY, 5), SO(RT::ASSAULT, 8), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::AHA, 2), SO(RT::HEAVY), SO(RT::BUILDER2)})
		}},
		{Factory::legvp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER), SO(RT::SCOUT, 5), SO(RT::BUILDER, 2), SO(RT::SCOUT, 10), SO(RT::RAIDER, 10)})
		}},
		{Factory::legavp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 3), SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::ASSAULT), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::legap, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER), SO(RT::AA), SO(RT::RAIDER), SO(RT::BOMBER), SO(RT::SCOUT)})
		}}
		}, {SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)}
	);
}

const array<SO>@ GetOpener(const CCircuitDef@ facDef)
{
	SOpener@ open = GetOpenInfo();

	const string facName = facDef.GetName();
	array<SQueue>@ queues;
	if (!open.factory.get(facName, @queues))
		return open.def;

	array<float> weights;
	for (uint i = 0, l = queues.length(); i < l; ++i)
		weights.insertLast(queues[i].weight);

	int choice = AiDice(weights);
	if (choice < 0)
		return open.def;

	return queues[choice].orders;
}

}  // namespace Opener


/*
namespace Hide {

// Commander hides if ("frame" elapsed) and ("threat" exceeds value or enemy has "air")
shared class SHide {
	SHide(int f, float t, bool a) {
		frame = f;
		threat = t;
		isAir = a;
	}
	int frame;
	float threat;
	bool isAir;
}

dictionary hideInfo = {
	{Commander::armcom, SHide(480 * 30, 30.f, true)},
	{Commander::corcom, SHide(470 * 30, 20.f, true)}
};

map<Id, SHide@> hideUnitDef;  // cache map<UnitDef_Id, SHide>

const SHide@ CacheHide(const CCircuitDef@ cdef)
{
	Id cid = cdef.GetId();
	const string name = cdef.GetName();
	array<string>@ keys = hideInfo.getKeys();
	for (uint i = 0, l = keys.length(); i < l; ++i) {
		if (name.findFirst(keys[i]) >= 0) {
			SHide@ hide = cast<SHide>(hideInfo[keys[i]]);
			hideUnitDef.insert(cid, hide);
			return hide;
		}
	}
	hideUnitDef.insert(cid, null);
	return null;
}


const SHide@ GetForUnitDef(const CCircuitDef@ cdef)
{
	bool success;
	SHide@ hide = hideUnitDef.find(cdef.GetId(), success);
	return success ? hide : CacheHide(cdef);
}

}  // namespace Hide
*/
