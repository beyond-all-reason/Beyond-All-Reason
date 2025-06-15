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
			//raider
			SQueue(0.4f, {SO(RT::BUILDER), SO(RT::SCOUT, 2), SO(RT::RAIDER, 2), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 5), SO(RT::BUILDER), SO(RT::RAIDER)}),
			//builder
			SQueue(0.3f, {SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER, 3), SO(RT::RAIDER, 3), SO(RT::SUPPORT), SO(RT::RAIDER)}),
			//standard
			SQueue(0.3f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER, 2), SO(RT::BUILDER)})
		}},
		{Factory::armvp, array<SQueue> = {
			//standard
			SQueue(0.4f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER)}),
			//early scout push
			SQueue(0.3f, {SO(RT::SCOUT, 2), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)}),
			SQueue(0.3f, {SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER)})
		}},
		{Factory::armalab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::RIOT), SO(RT::ASSAULT, 2), SO(RT::BUILDER2), SO(RT::ASSAULT), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::AHA, 2), SO(RT::BUILDER2), SO(RT::HEAVY), SO(RT::BUILDER2)})
		}},
		{Factory::armavp, array<SQueue> = {
			SQueue(0.4f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::AHA), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::AHA), SO(RT::BUILDER2)}),
			SQueue(0.6f, {SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::SKIRM, 2)})
		}},
		{Factory::armshltx, array<SQueue> = {
			SQueue(1.0f, {SO(RT::RAIDER), SO(RT::RIOT, 2), SO(RT::ARTY, 2), SO(RT::SUPER)})
		}},
		{Factory::armsy, array<SQueue> = {
			SQueue(0.3f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::SUB), SO(RT::SKIRM)})
		}},
		{Factory::armasy, array<SQueue> = {
			SQueue(0.5f, {SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2, 2)})
		}},
		{Factory::corlab, array<SQueue> = {
			SQueue(0.3f, {SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 4), SO(RT::BUILDER), SO(RT::RAIDER, 2)}),
			SQueue(0.3f, {SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 2), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 2), SO(RT::RIOT), SO(RT::BUILDER), SO(RT::RAIDER, 2)}),
			SQueue(0.3f, {SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)})
		}},
		{Factory::corvp, array<SQueue> = {
			//standard
			SQueue(0.4f, {SO(RT::SCOUT), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 2), SO(RT::BUILDER), SO(RT::RAIDER, 2), SO(RT::BUILDER), SO(RT::RAIDER, 2)}),
			// raider serial production
			SQueue(0.3f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 5), SO(RT::BUILDER)}),
			// scout start
			//SQueue(0.2f, {SO(RT::SCOUT, 4), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)}),
			//defensive eco start
			SQueue(0.2f, {SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)})
		}},
		{Factory::coralab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::RAIDER, 3), SO(RT::BUILDER2), SO(RT::RAIDER, 3), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::HEAVY), SO(RT::BUILDER2), SO(RT::ASSAULT, 2), SO(RT::BUILDER2)})
		}},
		{Factory::coravp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::ASSAULT), SO(RT::BUILDER2),SO(RT::HEAVY), SO(RT::BUILDER2, 2)})
		}},
		{Factory::corgant, array<SQueue> = {
			SQueue(1.0f, {SO(RT::RAIDER), SO(RT::ASSAULT), SO(RT::ARTY, 2)})
		}},
		{Factory::corsy, array<SQueue> = {
			SQueue(0.3f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::SUB), SO(RT::SKIRM)})
		}},
		{Factory::corasy, array<SQueue> = {
			SQueue(0.5f, {SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2, 2)})
		}},
		{Factory::leglab, array<SQueue> = {
			SQueue(0.9f, {SO(RT::BUILDER), SO(RT::SCOUT), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER, 2)}),
			SQueue(0.1f, {SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RIOT), SO(RT::BUILDER), SO(RT::RAIDER, 4), SO(RT::BUILDER), SO(RT::RAIDER, 2)})
		}},
		{Factory::legalab, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::RAIDER, 3), SO(RT::BUILDER2), SO(RT::ARTY, 2), SO(RT::ASSAULT), SO(RT::BUILDER2), SO(RT::AA)})
		}},
		{Factory::legvp, array<SQueue> = {
			//standard
			SQueue(0.4f, {SO(RT::SCOUT), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER)}),
			//early scout push
			SQueue(0.3f, {SO(RT::SCOUT, 2), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER)}),
			SQueue(0.3f, {SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER), SO(RT::RAIDER), SO(RT::BUILDER)})
		}},
		{Factory::legavp, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER2), SO(RT::SKIRM, 2), SO(RT::BUILDER2), SO(RT::SKIRM), SO(RT::BUILDER2), SO(RT::ARTY), SO(RT::AA), SO(RT::BUILDER2)})
		}},
		{Factory::legap, array<SQueue> = {
			SQueue(1.0f, {SO(RT::BUILDER, 5)})
		}}
		}, {SO(RT::BUILDER), SO(RT::RAIDER, 3), SO(RT::BUILDER), SO(RT::RAIDER)}
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
