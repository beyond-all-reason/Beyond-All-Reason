AiModeHandler = class(Module)

function AiModeHandler:Name()
	return "AiModeHandler"
end

function AiModeHandler:internalName()
	return "aimodehandler"
end

local UDC = function(teamID, DefID)
	return #Spring.GetTeamUnitsByDefs(ai.id, DefID)
end
local UDN = UnitDefNames
local advBuilders = {UDN.armacv.id, UDN.armack.id, UDN.armaca.id, UDN.coracv.id, UDN.corack.id, UDN.coraca.id}
local modenames = {"balanced", "t1", "tech"}
function AiModeHandler:Init()
	self.resources = {metal = {}, energy = {}}
	for res, tab in pairs(self.resources) do
		local c, s, p, i, e = Spring.GetTeamResources(self.ai.id, res)
		self.resources[res] = {c = c, s = s, p = p, i = i, e = e}
	end
	math.randomseed( os.time() + self.ai.id )
	math.random(); math.random(); math.random()
	self:PickASide(math.random(1,2))
	self:CreateWantedTechTree(math.random(1,12),math.random(1,12))
	--local count = #Spring.GetTeamList(self.ai.allyId)
	--if count and count > 1 then
		--self:Mode(math.random(1,count)%3 + 1)
	--else
		self:Mode(1)
	--end
end

function AiModeHandler:Update()
	local frame = Spring.GetGameFrame()
	if frame%15 == self.ai.id%15 then
		for res, tab in pairs(self.resources) do
			local c, s, p, i, e = Spring.GetTeamResources(self.ai.id, res)
			if res == "energy" and Spring.GetTeamRulesParam(self.ai.id,'mmUse') and tonumber(Spring.GetTeamRulesParam(self.ai.id,'mmUse')) then
				e = e - tonumber(Spring.GetTeamRulesParam(self.ai.id,'mmUse'))
			end
			self.resources[res] = {c = c, s = s, p = p, i = i, e = e}
		end
	end
end


function AiModeHandler:Mode(i)
		self.perraider = 50
		self.perskirmer = 40
		self.t1ratepret2 = math.random(3,20)*0.1							
		self.t1ratepostt2 = math.random(5,100)*0.01
		self.eincomelimiterpretech2 = math.random(950,2550)
		self.eincomelimiterposttech2 = math.random(950,2550)
		if self.eincomelimiterposttech2 < self.eincomelimiterpretech2 then
			local r = math.random(1,100)
			self.eincomelimiterposttech2 = self.eincomelimiterpretech2 + r
		end
		self.mintecheincome = self.eincomelimiterpretech2 - 200
		self.mintechmincome = math.random(25,50)
		self.mint2countpauset1 = math.random(3,10)
		local r = math.random(0,1)
		if r == 0 then
			self.t2rusht1reclaim = true
		else
			self.t2rusht1reclaim = false
		end
		-- Make sure it can always tech
		self.eincomelimiterpretech2 = math.max(self.mintecheincome, self.eincomelimiterpretech2)
		self.mintechmincome = math.min(self.mintechmincome, self.eincomelimiterpretech2/70)
		self.nodefenderscounter = math.random(1200,2400)
		self.noregroupcounter = self.nodefenderscounter + math.random(600,1200)
	-- if i == 1 then -- Balanced mode
		-- -- Spring.Echo(self.ai.id, "Balanced mode")
		-- self.t1ratepret2 = 1
		-- self.t1ratepostt2 = 0.4
		-- self.eincomelimiterpretech2 = 750
		-- self.eincomelimiterposttech2 = 1550
		-- self.mintecheincome = 450
		-- self.mintechmincome = 22
		-- self.mint2countpauset1 = 5
		-- self.t2rusht1reclaim = true
	-- elseif i == 3 then -- TechRush mode
		-- -- Spring.Echo(self.ai.id, "TechRush mode")
		-- self.t1ratepret2 = 0.3
		-- self.t1ratepostt2 = 0.05
		-- self.eincomelimiterpretech2 = 300
		-- self.eincomelimiterposttech2 = 500
		-- self.mintecheincome = 300
		-- self.mintechmincome = 12
		-- self.mint2countpauset1 = 3
		-- self.t2rusht1reclaim = true
	-- elseif i == 2 then -- T1 Mode
		-- -- Spring.Echo(self.ai.id, "T1 Mode")
		-- self.t1ratepret2 = 2
		-- self.t1ratepostt2 = 1
		-- self.eincomelimiterpretech2 = 1550
		-- self.eincomelimiterposttech2 = 2550
		-- self.mintecheincome = 950
		-- self.mintechmincome = 35
		-- self.mint2countpauset1 = 10
		-- self.t2rusht1reclaim = false
	-- end
end

function AiModeHandler:PickASide(i)
	if i == 1 then
		Spring.SetTeamRulesParam(self.ai.id, "startUnit", UnitDefNames.armcom.id)
		self.faction = "ARM"
	else
		Spring.SetTeamRulesParam(self.ai.id, "startUnit", UnitDefNames.corcom.id)
		self.faction = "CORE"
	end
end

function corkbot(tqb,ai,unit)
	if UDC(ai.id, UDN.corlab.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "corlab"
	elseif UDC(ai.id, UDN.coralab.id) < 1 then
		return "coralab"
	end
	return nil
end

function corvehicle(tqb, ai, unit)
	if UDC(ai.id, UDN.corvp.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "corvp"
	elseif UDC(ai.id, UDN.coravp.id) < 1 then
		return "coravp"
	end
	return nil
end

function corair(tqb,ai,unit)
	if UDC(ai.id, UDN.corap.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "corap"
	elseif UDC(ai.id, UDN.coraap.id) < 1 then
		return "coraap"
	end
	return nil
end

function cort3(tqb,ai,unit)
	if UDC(ai.id, UDN.corlab.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "corlab"
	elseif UDC(ai.id, UDN.coralab.id) < 1 then
		return "coralab"
	elseif UDC(ai.id, UDN.corgant.id) < 1 then
		return "corgant"
	end
	return nil
end

function armkbot(tqb,ai,unit)
	if UDC(ai.id, UDN.armlab.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "armlab"
	elseif UDC(ai.id, UDN.armalab.id) < 1 then
		return "armalab"
	end
	return nil
end

function armvehicle(tqb, ai, unit)
	if UDC(ai.id, UDN.armvp.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "armvp"
	elseif UDC(ai.id, UDN.armavp.id) < 1 then
		return "armavp"
	end
	return nil
end

function armair(tqb,ai,unit)
	if UDC(ai.id, UDN.armap.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "armap"
	elseif UDC(ai.id, UDN.armaap.id) < 1 then
		return "armaap"
	end
	return nil
end

function armt3(tqb,ai,unit)
	if UDC(ai.id, UDN.armlab.id) < 1 then
		if UDC(ai.id, advBuilders) < ai.aimodehandler.mint2countpauset1 then
			return {action = "nexttask"}
		end
		return "armlab"
	elseif UDC(ai.id, UDN.armalab.id) < 1 then
		return "armalab"
	elseif UDC(ai.id, UDN.armshltx.id) < 1 then
		return "armshltx"
	end
	return nil
end

function AiModeHandler:CreateWantedTechTree(i,j)
	self.corexpfunctions = {
		corkbot,
		corvehicle,
		corair,
		cort3,
		}
	self.armexpfunctions = {
		armkbot,
		armvehicle,
		armair,
		armt3,
		}
	self.randomTable = {{1,2,3,4},{1,2,4,3},{1,3,2,4},{1,3,4,2},{1,4,2,3},{1,4,3,2},{2,1,3,4},{2,1,4,3},{2,3,1,4},{2,3,4,1},{2,4,1,3},{2,4,3,1},{3,1,2,4},{3,1,4,2},{3,2,1,4},{3,2,4,1},{3,4,1,2},{3,4,2,1},{4,1,2,3},{4,1,3,2},{4,2,1,3},{4,2,3,1},{4,3,1,2},{4,3,2,1}}
	self.useArmRandomTable = self.randomTable[i]
	self.useCorRandomTable = self.randomTable[j]
	self.ArmExpand = function(tqb,ai,unit)
		for n = 1,4 do
			if self.armexpfunctions[self.useArmRandomTable[n]](tqb,ai,unit) then
				return self.armexpfunctions[self.useArmRandomTable[n]](tqb,ai,unit)
			end
		end
		return FindBest({"armlab", "armalab", "armvp", "armavp", "armap", "armaap", "armshltx"}, ai)
	end
	self.CorExpand = function(tqb,ai,unit)
		for n = 1,4 do
			if self.corexpfunctions[self.useCorRandomTable[n]](tqb,ai,unit) then
				return self.corexpfunctions[self.useCorRandomTable[n]](tqb,ai,unit)
			end
		end
		return FindBest({"corlab", "coralab", "corvp", "coravp", "corap", "coraap", "corgant"}, ai)
	end		
end

function AiModeHandler:ArmExpandRandomLab(tqb,ai,unit)
return self.ArmExpand(tqb,ai,unit)
end

function AiModeHandler:CorExpandRandomLab(tqb,ai,unit)
return self.CorExpand(tqb,ai,unit)
end

