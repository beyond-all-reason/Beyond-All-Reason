Handler = class(Module)

function CountHandler:Name()
	return "CountHandler"
end

function CountHandler:internalName()
	return "counthandler"
end

function CountHandler:Init()
	self.DebugEnabled = false

	self.ai.factories = 0
	self.ai.maxFactoryLevel = 0
	self.ai.factoriesAtLevel = {}
	self.ai.outmodedFactoryID = {}

	self.ai.nameCount = {}
	self.ai.nameCountFinished = {}
	self.ai.lastNameCreated = {}
	self.ai.lastNameFinished = {}
	self.ai.lastNameDead = {}
	self.ai.mexCount = 0
	self.ai.conCount = 0
	self.ai.combatCount = 0
	self.ai.battleCount = 0
	self.ai.breakthroughCount = 0
	self.ai.siegeCount = 0
	self.ai.reclaimerCount = 0
	self.ai.bigEnergyCount = 0
	self.ai.cleanable = {}
	self.ai.assistCount = 0
	
	self.ai.mtypeLvCount= {}
	
	self:InitializeNameCounts()
end

function CountHandler:InitializeNameCounts()
	for name, t in pairs(unitTable) do
		self.ai.nameCount[name] = 0
	end
end

function CountHandler:UnitDamaged(unit, attacker,damage)
	if unit:Team() ~= self.game:GetTeamID() then
		self:EchoDebug("unit damaged", unit:Team(), unit:Name(), unit:ID())
	end
	local aname = "nil"
	if attacker then 
		if attacker:Team() ~= game:GetTeamID() then
			self:EchoDebug(unit:Name() .. " on team " .. unit:Team() .. " damaged by " .. attacker:Name() .. " on team " .. attacker:Team())
		end
	end
end

-- uncomment below for unitmovefailed debugging info
-- function CountHandler:UnitMoveFailed(unit)
-- 	self:EchoDebug("unit move failed", unit:Team(), unit:Name(), unit:ID())
-- 	unit:DrawHighlight({1,0,0}, "movefailed", 9)
-- 	self.hasHighlight = self.hasHighlight or {}
-- 	self.hasHighlight[unit:ID()] = 0
-- end

-- function CountHandler:Update()
-- 	if not self.hasHighlight then return end
-- 	for id, counter in pairs(self.hasHighlight) do
-- 		counter = counter + 1
-- 		if counter > 150 then
-- 			local unit = self.game:GetUnitByID(id)
-- 			unit:EraseHighlight({1,0,0}, "movefailed", 9)
-- 			self.hasHighlight[id] = nil
-- 		end
-- 	end
-- end