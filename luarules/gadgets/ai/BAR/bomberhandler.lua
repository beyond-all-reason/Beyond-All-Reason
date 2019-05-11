BomberHandler = class(Module)
local UDN = UnitDefNames
local BuildingsNeedingPatrol = {
	UDN.armap.id,
	UDN.armaap.id,
	UDN.corap.id,
	UDN.coraap.id,
	}

function BomberHandler:Name()
	return "BomberHandler"
end

function BomberHandler:internalName()
	return "bomberhandler"
end

function BomberHandler:Init()
	self.standbypatrol = {}
end

function BomberHandler:Update()
	if Spring.GetGameFrame()% 1800 == (self.ai.id*200)%1800 then
		self:UpdatePatrolPositions()
	end
	
	if Spring.GetGameFrame()% 300 == (self.ai.id*15)%300 and #self.standbypatrol >= Spring.GetGameSeconds()/120 then
		if self.PatrolPositions then
			self:DoPatrol()
		end
		self:DoBombingRun()
	end
end

function BomberHandler:DoBombingRun()
	local targetID = GG.AiHelpers.TargetsOfInterest.BombingRun(self.ai.id)
	if targetID and Spring.ValidUnitID(targetID) then
		local x,y,z = Spring.GetUnitPosition(targetID)
		for k, v in pairs(self.standbypatrol) do
			v:AttackTarget(targetID)
		end
		self.ai.fighterhandler:RequestFighterSupport({x = x, y = y, z = z})
	end
end
	

function BomberHandler:UpdatePatrolPositions()
	local teamUnitsList = Spring.GetTeamUnitsByDefs(self.ai.id, BuildingsNeedingPatrol)
	local count = 0
	for ct, id in pairs(teamUnitsList) do
		local x, y, z = Spring.GetUnitPosition(id)
		self.PatrolPositions = self.PatrolPositions or {}
		self.PatrolPositions[count + 1] = {x = math.max(0, x-1000), y = y, z = math.max(0, z-1000)}
		self.PatrolPositions[count + 2] = {x = math.max(0, x-1000), y = y, z = math.min(Game.mapSizeZ, z+1000)}
		self.PatrolPositions[count + 3] = {x = math.min(Game.mapSizeX, x+1000), y = y, z = math.min(Game.mapSizeZ, z+1000)}
		self.PatrolPositions[count + 4] = {x = math.min(Game.mapSizeX, x+1000), y = y, z = math.max(0, z-1000)}
		count = count + 4
	end	
end

function BomberHandler:DoPatrol()
	for ct, unit in pairs (self.standbypatrol) do
		unit:DoPatrol(self.PatrolPositions)
	end
end

function BomberHandler:UnitDead(engineunit)
	if engineunit:Team() == self.game:GetTeamID() then
		-- try and clean up dead standbypatrol where possible
		for i,v in ipairs(self.standbypatrol) do
			if v.engineID == engineunit:ID() then
				table.remove(self.standbypatrol,i)
				break
			end
		end
	end
end

function BomberHandler:DoTargetting()

end

function BomberHandler:IsRecruit(attkbehaviour)
	for i,v in ipairs(self.standbypatrol) do
		if v.engineID == attkbehaviour.engineID then
			return true
		end
	end
	return false
end

function BomberHandler:AddRecruit(attkbehaviour)
	if attkbehaviour.unit == nil then
		self.game:SendToConsole( "null unit in bomber beh found ")
		return
	end
	if not self:IsRecruit(attkbehaviour) then
		table.insert(self.standbypatrol,attkbehaviour)
	end
end

function BomberHandler:RemoveRecruit(attkbehaviour)
	for i,v in ipairs(self.standbypatrol) do
		if v.engineID == attkbehaviour.engineID then
			table.remove(self.standbypatrol,i)
			return true
		end
	end
	return false
end