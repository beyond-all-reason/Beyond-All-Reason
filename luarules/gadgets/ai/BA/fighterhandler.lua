FighterHandler = class(Module)
local UDN = UnitDefNames
local BuildingsNeedingPatrol = {
	UDN.armap.id,
	UDN.armaap.id,
	UDN.corap.id,
	UDN.coraap.id,
	}

function FighterHandler:Name()
	return "FighterHandler"
end

function FighterHandler:internalName()
	return "fighterhandler"
end

function FighterHandler:Init()
	self.standbypatrol = {}
end

function FighterHandler:Update()
	if Spring.GetGameFrame()% 1800 == (self.ai.id*200)%1800 then
		self:UpdatePatrolPositions()
		self:DoPatrol()
	end
end

function FighterHandler:UpdatePatrolPositions()
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

function FighterHandler:DoPatrol()
	for ct, unit in pairs (self.standbypatrol) do
		unit:DoPatrol(self.PatrolPositions)
	end
end

function FighterHandler:RequestFighterSupport(pos)
	for ct, unit in pairs (self.standbypatrol) do
		if math.random(1,2) == 1 then
			unit:FightCell(pos)
		end
	end
end

function FighterHandler:UnitDead(engineunit)
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

function FighterHandler:DoTargetting()

end

function FighterHandler:IsRecruit(attkbehaviour)
	for i,v in ipairs(self.standbypatrol) do
		if v.engineID == attkbehaviour.engineID then
			return true
		end
	end
	return false
end

function FighterHandler:AddRecruit(attkbehaviour)
	if attkbehaviour.unit == nil then
		self.game:SendToConsole( "null unit in fighter beh found ")
		return
	end
	if not self:IsRecruit(attkbehaviour) then
		table.insert(self.standbypatrol,attkbehaviour)
	end
end

function FighterHandler:RemoveRecruit(attkbehaviour)
	for i,v in ipairs(self.standbypatrol) do
		if v.engineID == attkbehaviour.engineID then
			table.remove(self.standbypatrol,i)
			return true
		end
	end
	return false
end