AiModeHandler = class(Module)

function AiModeHandler:Name()
	return "AiModeHandler"
end

function AiModeHandler:internalName()
	return "aimodehandler"
end

local UDC = Spring.GetTeamUnitDefCount
local UDN = UnitDefNames

function AiModeHandler:Init()
	math.randomseed( os.time() + self.ai.id )
	math.random(); math.random(); math.random()
	self:PickASide(math.random(1,2))
	self:CreateWantedTechTree(math.random(1,12),math.random(1,12))
	-- self:Difficulties()
	self:Mode(math.random(1,3))
end

function AiModeHandler:Mode(i)
	if i == 1 then -- Balanced mode
		-- Spring.Echo(self.ai.id, "Balanced mode")
		self.t1ratepret2 = 1
		self.t1ratepostt2 = 0.4
		self.eincomelimiterpretech2 = 750
		self.eincomelimiterposttech2 = 1550
		self.mintecheincome = 450
		self.mintechmincome = 25
		self.mint2countpauset1 = 5
	elseif i == 2 then -- TechRush mode
		-- Spring.Echo(self.ai.id, "TechRush mode")
		self.t1ratepret2 = 0.3
		self.t1ratepostt2 = 0.05
		self.eincomelimiterpretech2 = 450
		self.eincomelimiterposttech2 = 650
		self.mintecheincome = 300
		self.mintechmincome = 12
		self.mint2countpauset1 = 3
	elseif i == 3 then -- T1 Mode
		-- Spring.Echo(self.ai.id, "T1 Mode")
		self.t1ratepret2 = 2
		self.t1ratepostt2 = 1
		self.eincomelimiterpretech2 = 1550
		self.eincomelimiterposttech2 = 2550
		self.mintecheincome = 950
		self.mintechmincome = 35
		self.mint2countpauset1 = 10
	end
end

function AiModeHandler:PickASide(i)
	if i == 1 then
		Spring.SetTeamRulesParam(self.ai.id, "startUnit", UnitDefNames.armcom.id)
	else
		Spring.SetTeamRulesParam(self.ai.id, "startUnit", UnitDefNames.corcom.id)
	end
end

function corkbot(tqb,ai,unit)
	if UDC(ai.id, UDN.corlab.id) < 1 then
		return "corlab"
	elseif UDC(ai.id, UDN.coralab.id) < 1 then
		return "coralab"
	end
	return nil
end

function corvehicle(tqb, ai, unit)
	if UDC(ai.id, UDN.corvp.id) < 1 then
		return "corvp"
	elseif UDC(ai.id, UDN.coravp.id) < 1 then
		return "coravp"
	end
	return nil
end

function corair(tqb,ai,unit)
	if UDC(ai.id, UDN.corap.id) < 1 then
		return "corap"
	elseif UDC(ai.id, UDN.coraap.id) < 1 then
		return "coraap"
	end
	return nil
end

function cort3(tqb,ai,unit)
	if UDC(ai.id, UDN.corlab.id) < 1 then
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
		return "armlab"
	elseif UDC(ai.id, UDN.armalab.id) < 1 then
		return "armalab"
	end
	return nil
end

function armvehicle(tqb, ai, unit)
	if UDC(ai.id, UDN.armvp.id) < 1 then
		return "armvp"
	elseif UDC(ai.id, UDN.armavp.id) < 1 then
		return "armavp"
	end
	return nil
end

function armair(tqb,ai,unit)
	if UDC(ai.id, UDN.armap.id) < 1 then
		return "armap"
	elseif UDC(ai.id, UDN.armaap.id) < 1 then
		return "armaap"
	end
	return nil
end

function armt3(tqb,ai,unit)
	if UDC(ai.id, UDN.armlab.id) < 1 then
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
				return self.armexpfunctions[self.useCorRandomTable[n]](tqb,ai,unit)
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

