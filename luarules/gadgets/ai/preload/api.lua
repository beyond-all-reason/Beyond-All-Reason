-- Humongous proxy class
-- Created by Tom J Nowell 2010
-- Shard AI

-- currently included from inside the main AI object during initialisation
local api = {}
if ShardSpringLua then
	-- it's a LuaAI inside a game archive!
	api.game = shard_include "spring_lua/game"
	api.map = shard_include "spring_lua/map"
elseif game_engine then
	 -- it's a native AI!
	api.game = shard_include "spring_cpp/game"
	api.map = shard_include "spring_cpp/map"
else
	-- who knows! Load a Null non-op API
	api.game = shard_include "preload/shard_null/game"
	api.map = shard_include "preload/shard_null/map"
end

return api

--}
--[[
{,

IUnit/ engine unit objects
	int ID()
	int Team()
	std::string Name()

	bool IsAlive()

	bool IsCloaked()

	void Forget() // makes the interface forget about this unit and cleanup
	bool Forgotten() // for interface/debugging use

	IUnitType* Type() -- not implemented, use game:GetTypeByName

	bool CanMove()
	bool CanDeploy()
	bool CanBuild()
	bool IsBeingBuilt()

	bool CanAssistBuilding(IUnit* unit)

	bool CanMoveWhenDeployed()
	bool CanFireWhenDeployed()
	bool CanBuildWhenDeployed()
	bool CanBuildWhenNotDeployed()

	void Stop()
	void Move(Position p)
	void MoveAndFire(Position p)

	bool Build(IUnitType* t)
	bool Build(std::string typeName)
	bool Build(std::string typeName, Position p)
	bool Build(IUnitType* t, Position p)

	bool AreaReclaim(Position p, double radius)
	bool Reclaim(IMapFeature* mapFeature)
	bool Reclaim(IUnit* unit)
	bool Attack(IUnit* unit)
	bool Repair(IUnit* unit)
	bool MorphInto(IUnitType* t)

	Position GetPosition()
	float GetHealth()
	float GetMaxHealth()

	int WeaponCount()
	float MaxWeaponsRange()

	bool CanBuild(IUnitType* t)

	SResourceTransfer GetResourceUsage(int idx)

	void ExecuteCustomCommand(int cmdId, std::vector<float> params_list, short options = 0, int timeOut = INT_MAX)

	UnitType{
		function Name() -- returns a string e.g. 'corcom'

		function CanDeploy() -- returns boolean
		function CanMoveWhenDeployed() -- returns boolean
		function CanFireWhenDeployed() -- returns boolean
		function CanBuildWhenDeployed() -- returns boolean
		function CanBuildWhenNotDeployed() -- returns boolean

		function Extractor() -- returns boolean

		function GetMaxHealth() -- returns a float

		function WeaponCount() -- returns integer
	},
	MapFeature {
		function ID()
		function Name()
		function GetPosition()
	},
	Position {
		x,y,z
	},

}

return infos]]--
