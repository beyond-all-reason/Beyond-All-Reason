#include "../manager/factory.as"


namespace Commander {

string armcom("armcom");
string corcom("corcom");

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

dictionary@ GetOpenInfo()
{
	return dictionary = {
		{Commander::armcom, SOpener({
			{Factory::armlab, array<SQueue> = {
				SQueue(1.0f, {SO(RT::SKIRM), SO(RT::BUILDER), SO(RT::SKIRM), SO(RT::BUILDER)})
			}},
			{Factory::armalab, array<SQueue> = {
				SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 3), SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::AA), SO(RT::BUILDER2)})
			}},
			{Factory::armavp, array<SQueue> = {
				SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
			}},
			{Factory::armasy, array<SQueue> = {
				SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
			}},
			{Factory::armap, array<SQueue> = {
				SQueue(1.0f, {SO(RT::AA), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::BOMBER), SO(RT::SCOUT)})
			}}
			}, {SO(RT::RAIDER), SO(RT::BUILDER)})
		},
		{Commander::corcom, SOpener({
			{Factory::corlab, array<SQueue> = {
				SQueue(1.0f, {SO(RT::SKIRM), SO(RT::BUILDER)})
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
			}}
			}, {SO(RT::BUILDER), SO(RT::SKIRM)})
		}
	};
}

const array<SO>@ GetOpener(const CCircuitDef@ facDef)
{
	dictionary@ openInfo = GetOpenInfo();
	const CCircuitDef@ commChoice = aiSetupMgr.commChoice;
	const string commName = commChoice.GetName();

	SOpener@ open;  // null
	const array<string>@ keys = openInfo.getKeys();
	for (uint i = 0, l = keys.length(); i < l; ++i)
		if (commName.findFirst(keys[i]) >= 0) {
			@open = cast<SOpener>(openInfo[keys[i]]);
			break;
		}

	if (open is null)
		return null;

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
