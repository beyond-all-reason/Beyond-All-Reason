shard_include( "scouts" )


-- speedups
local SpGetGameFrame = Spring.GetGameFrame
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetUnitSeparation = Spring.GetUnitSeparation
local SpGetUnitVelocity = Spring.GetUnitVelocity
local SpGetUnitMaxRange = Spring.GetUnitMaxRange
local SpValidUnitID = Spring.ValidUnitID
local SpGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
local SpGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
------


function IsScouts(unit)
	for i,name in ipairs(scoutslist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

ScoutsBehaviour = class(Behaviour)

function ScoutsBehaviour:Init()
end

function ScoutsBehaviour:Update()
	if Spring.GetGameFrame() % 360 == 0 then
		self:ExecuteScouting()
	end
end

function ScoutsBehaviour:OwnerBuilt()
	self.unit:Internal():ExecuteCustomCommand(37382, {1}, {})
	self.scouting = true
end

function ScoutsBehaviour:OwnerDead()
end


function ScoutsBehaviour:ExecuteScouting()
	local pos = self.ai.scoutshandler:GetPosToScout()
	if pos then
		self.unit:Internal():Move(pos)
	end
end

function ScoutsBehaviour:Priority()
	if not self.scouting then
		return 0
	else
		return 100
	end
end

function ScoutsBehaviour:Activate()
	self.active = true
end


function ScoutsBehaviour:OwnerDied()
	self.scouting = nil
	self.active = nil
	self.unit = nil
end
