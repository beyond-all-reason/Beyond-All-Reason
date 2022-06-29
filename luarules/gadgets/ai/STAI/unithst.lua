UnitHST = class(Module)
--[[
local inactive = {
	armsolar = true,
	-- armamb = true,
	-- armanni = true,
	armbeamer = true,
	-- armbrtha = true,
	armcir = true,
	armclaw = true,
	-- armemp = true,
	armflak = true,
	armguard = true,
	armhlt = true,
	armllt = true,
	armferret = true,
	armpb = true,
	armrl = true,
	-- armvulc = true,
	armadvsol = true,
	armafus = true,
	armgeo = true,
	armageo = true,
	armamex = true,
	armckfus = true,
	armestor = true,
	armfus = true,
	armgmm = true,
	armmakr = true,
	armmex = true,
	armmmkr = true,
	armmoho = true,
	armmstor = true,
	armwin = true,
	armarad = true,
	armasp = true,
	armdf = true,
	armdrag = true,
	armeyes = true,
	armfort = true,
	armgate = true,
	armjamt = true,
	armmine1 = true,
	armmine2 = true,
	armmine3 = true,
	armrad = true,
	armtarg = true,
	armveil = true,
	armatl = true,
	armdl = true,
	armfflak = true,
	armfhlt = true,
	armfrock = true,
	armfrt = true,
	armgplat = true,
	armptl = true,
	armtl = true,
	armfmkr = true,
	armtide = true,
	armuwadves = true,
	armuwadvms = true,
	armuwes = true,
	armuwms = true,
	armuwfus = true,
	armuwmex = true,
	armuwmme = true,
	armuwmmm = true,
	armason = true,
	armfatf = true,
	armfdrag = true,
	armfgate = true,
	armfmine3 = true,
	armfrad = true,
	armsonar = true,

	-- corbhmth = true,
	-- corbuzz = true,
	-- cordoom = true,
	corerad = true,
	corexp = true,
	corflak = true,
	corhllt = true,
	corhlt = true,
	-- corint = true,
	corllt = true,
	cormadsam = true,
	cormaw = true,
	cormexp = true,
	corpun = true,
	corrl = true,
	-- cortoast = true,
	corvipe = true,
	coradvsol = true,
	corafus = true,
	corageo = true,
	corestor = true,
	corfus = true,
	corgeo = true,
	cormakr = true,
	cormex = true,
	cormmkr = true,
	cormoho = true,
	cormstor = true,
	corsolar = true,
	corwin = true,
	corarad = true,
	corasp = true,
	cordrag = true,
	coreyes = true,
	corfort = true,
	corgate = true,
	corjamt = true,
	cormine1 = true,
	cormine2 = true,
	cormine3 = true,
	cormine4 = true,
	corrad = true,
	corsd = true,
	corshroud = true,
	cortarg = true,
	coratl = true,
	cordl = true,
	corenaa = true,
	corfhlt = true,
	corfrock = true,
	corfrt = true,
	corgplat = true,
	corptl = true,
	cortl = true,
	corfmkr = true,
	cortide = true,
	coruwadves = true,
	coruwadvms = true,
	coruwes = true,
	coruwms = true,
	coruwfus = true,
	coruwmex = true,
	coruwmme = true,
	coruwmmm = true,
	corason = true,
	corfatf = true,
	corfdrag = true,
	corfgate = true,
	corfmine3 = true,
	corfrad = true,
	corsonar = true
}
]]
local inactive = {}
function UnitHST:Name()
	return "UnitHandler"
end

function UnitHST:internalName()
	return "unithst"
end

function UnitHST:Init()
	self.units = {}
	self.myActiveUnits = {}
	self.myInactiveUnits = {}
	self.reallyActuallyDead = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
	self.ai.behUp = {
		taskqueuebst 	=	40 + self.ai.index,
		tasklabbst		=	100 + self.ai.index,
		attackerbst		=	50 + self.ai.index,
		raidbst			=	60 + self.ai.index,
		bomberbst		= 	210 + self.ai.index,
		wardbst			=	200 + self.ai.index,
		mexupbst		=	90 + self.ai.index,
		reclaimbst		=	180 + self.ai.index,
		cleanerbst		=	160 + self.ai.index,
		defendbst		=	70 + self.ai.index,
		labregisterbst	=	190 + self.ai.index,
		scoutbst		=	80 + self.ai.index,
		antinukebst		=	300 + self.ai.index,
		nukebst			=	250 + self.ai.index,
		bombardbst		=	220 + self.ai.index,
		commanderbst	=	20 + self.ai.index,
		bootbst			=	30 + self.ai.index,
		}
end

function UnitHST:Update()
	for k,unit in pairs(self.myActiveUnits) do
		if ShardSpringLua then
			local ux, uy, uz = Spring.GetUnitPosition(unit:Internal():ID())
			if not ux then
				-- game:SendToConsole(self.ai.id, "nil unit position", unit:Internal():ID(), unit:Internal():Name(), k)
				self.myActiveUnits[k] = nil
				unit = nil
			end
		end
		if unit then
			if unit:HasBehaviours() then
 				self.game:StartTimer(unit:Internal():Name() .. ' hst')
				unit:Update()
 				self.game:StartTimer(unit:Internal():Name() .. ' hst')
			end
		end
	end
	for uID, frame in pairs(self.reallyActuallyDead) do
		if self.game:Frame() > frame + 1800 then
			self.reallyActuallyDead[uID] = nil
		end
	end

end

function UnitHST:GameEnd()
	for k,unit in pairs(self.myActiveUnits) do
		if unit:HasBehaviours() then
			unit:GameEnd()
		end
	end
end

function UnitHST:UnitCreated(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
	if u:HasBehaviours() then
		u:UnitCreated(u)
	end
	--TODO fix this expensive load
-- 	self.game:StartTimer(u:Internal():Name()..' UC')
-- 	for k,unit in pairs(self.myActiveUnits) do
-- 		if unit:HasBehaviours() then
-- 			self.game:StartTimer(unit:Internal():Name()..' crea')
-- 			unit:UnitCreated(u)
-- 			print(u:Internal():Name() .. ' UC ' .. unit:Internal():Name())
-- 			self.game:StopTimer(unit:Internal():Name()..' crea')
-- 		end
-- 	end
-- 	self.game:StopTimer(u:Internal():Name()..' UC')
end

function UnitHST:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitBuilt(u)
-- 	for k,unit in pairs(self.myActiveUnits) do
 		if u:HasBehaviours() then
 			u:UnitBuilt(u)
 		end
-- 	end
end

function UnitHST:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		--u:UnitDead(u)
 		for k,unit in pairs(self.myActiveUnits) do
 			if u:HasBehaviours() then
 				u:UnitDead(u)
 			end
 		end
	end
	-- game:SendToConsole(self.ai.id, "removing unit from unithst tables", engineUnit:ID(), engineUnit:Name())
	self.units[engineUnit:ID()] = nil
	self.myActiveUnits[engineUnit:ID()] = nil
	self.myInactiveUnits[engineUnit:ID()] = nil
	self.reallyActuallyDead[engineUnit:ID()] = self.game:Frame()
end

function UnitHST:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitDamaged(u,engineAttacker,damage)
	-- local a = self:AIRepresentation(engineAttacker)
-- 	for k,unit in pairs(self.myActiveUnits) do
 		if u:HasBehaviours() then
 			u:UnitDamaged(u,engineAttacker,damage)
 		end
-- 	end
end


function UnitHST:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u == nil then return end
-- 	u:UnitIdle(u)
-- 	for k,unit in pairs(self.units) do
 		if u:HasBehaviours() then
 			u:UnitIdle(u)
 		end
-- 	end
end

function UnitHST:AIRepresentation(engineUnit)
	if engineUnit == nil then
		return nil
	end
	if self.reallyActuallyDead[engineUnit:ID()] then
		return nil
	end
	local ux, uy, uz = engineUnit:GetPosition()
	if not ux then
		return nil
	end

	local u = self.units[engineUnit:ID()]
	if u == nil then
		u = Unit()
		u:SetAI( self.ai )
		self.units[engineUnit:ID()] = u
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			if inactive[engineUnit:Name()] then
				self.myInactiveUnits[engineUnit:ID()] = u
			else
				-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
				self.behaviourFactory:AddBehaviours(u)
				self.myActiveUnits[engineUnit:ID()] = u
			end
		end
	end
	return u
end

