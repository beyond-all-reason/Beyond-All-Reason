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
		}},
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
		}},
		{Factory::leglab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::SKIRM), SO(RT::BUILDER), SO(RT::SKIRM), SO(RT::BUILDER)})
		}},
		{Factory::legalab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 3), SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::legavp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::legap, array<SQueue> = {
			SQueue(1.0f, {SO(RT::AA), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::BOMBER), SO(RT::SCOUT)})
		}}
		}, {SO(RT::BUILDER), SO(RT::SKIRM)}
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
