CountHST = class(Module)

function CountHST:Name()
	return "CountHST"
end

function CountHST:internalName()
	return "counthst"
end

function CountHST:Init()
	self.ai.game:SendToConsole("counting handler!!!")
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
	self.ai.conList = {}
	self.ai.combatCount = 0
	self.ai.battleCount = 0
	self.ai.breakthroughCount = 0
	self.ai.siegeCount = 0
	self.ai.reclaimerCount = 0
	self.ai.cleanable = {}
	self.ai.assistCount = 0
	self.ai.nanoList = {}
	self.ai.attackerCount = 0

	self.ai.mtypeLvCount = {}
	self.ai.mtypeCount = {veh = 0, bot = 0, air = 0, shp = 0, sub = 0, amp = 0, hov = 0 }

	self:InitializeNameCounts()
end

function CountHST:InitializeNameCounts()
	for name, t in pairs(self.ai.armyhst.unitTable) do
		self.ai.nameCount[name] = 0
	end
end

function CountHST:UnitDamaged(unit, attacker,damage)
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
