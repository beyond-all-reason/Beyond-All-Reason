 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("CountHandler: " .. inStr)
	end
end

CountHandler = class(Module)

function CountHandler:Name()
	return "CountHandler"
end

function CountHandler:internalName()
	return "counthandler"
end

function CountHandler:Init()
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
	local aname = "nil"
	if attacker then 
		if attacker:Team() ~= game:GetTeamID() then
			EchoDebug(unit:Name() .. " on team " .. unit:Team() .. " damaged by " .. attacker:Name() .. " on team " .. attacker:Team())
		end
	end
end

function CountHandler:UnitDead(unit)
	EchoDebug(unit:Name() .. " on team " .. unit:Team() .. " dead")
	if unit:Team() ~= game:GetTeamID() then
		EchoDebug("enemy unit died")
	end
end
