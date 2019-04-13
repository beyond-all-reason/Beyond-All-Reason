-- In this module we:
--1) split builders in "domains": eco, mil, util, comm, expand
--2) split domains into squads = a leader (if possible the highest tech unit available) + one or multiple helpers that are requested through AddRequest()
--3) Manage a pool of requests, these requests are solely builders related (ie: labs, cons, helpers, nanos). Other requests like "reclaim something", "send repairers here" are managed by the request handler.
--4) Attempt to create a certain dergee of retro control bp <=> request builders: If builders are using too much resources, they slow down their buildspeed, if a squad doesn't have enough bp to use up all it has available, it will request supplementary bp (or creating of a new squad) via AddRequest.
--5) Requests are forwarded to taskqueues via TryRequest() function. If one of the builders that have a tryrequest function can produce the requested item, the request is queued. If it hasn't been finished 2 minutes after it has been queued, it can be requeued.
-- The priority to be assigned to a squad goes for the existing builders first so request are only forwarded after the module cycled through all available idle builders and haven't found one that could fulfill the request.
-- Some specificities:
-- Military squads consist of a lab + nanos only (no mobile builder can be assigned to a military squad
-- Economy/expand squads leaders can only be the highest available tech builders (t1 < t2bots/air < t2 veh) Squads leaders are replaced once a higher tier exists
-- Util squads perform both buildersquads requests and requesthandler requests
-- Commander squad can't have any helper. There can only be one commander squad at a time, this isn't really useful for now (beside retrocontrol on comm's bp) but might be useful if we want to give certain particular tasks to the "last com" to ensure its survival, while others could be sent to front (ie revived comms)

BuilderSquadsHandler = class(Module)
shard_include('buildersquadsdefs')

local function squadtable(domain)
	local maxallowedbp
	local maxpendingrequests
	if domain == "military" then
		maxallowedbp = 2000
		maxpendingrequests = 3
	elseif domain == "economy" then
		maxallowedbp = 1500
		maxpendingrequests = 2
	elseif domain == "expand" then
		maxallowedbp = 400
		maxpendingrequests = 1
	elseif domain == "util" then
		maxallowedbp = 150
		maxpendingrequests = 1
	else
		maxallowedbp = 300
		maxpendingrequests = 1
	end
	local stable = {
		leader = {},
		helper = {},
		wtdbprate = 1,
		curbp = 0,
		maxbp = 0,
		maxallowedbp = maxallowedbp,
		maxpendingrequests = maxpendingrequests,
		hasPendingRequest = 0,
		}
	return stable
end

function BuilderSquadsHandler:Name()
	return "BuilderSquadsHandler"
end

function BuilderSquadsHandler:internalName()
	return "buildersquadshandler"
end

function BuilderSquadsHandler:WatchTechLevel()
	local maxtechlevel = 1
	for defName, techlevel in pairs (TechLevel) do
		if Spring.GetTeamUnitDefCount(self.ai.id, UnitDefNames[defName].id) > 0 then
			maxtechlevel = math.max(maxtechlevel, techlevel)
		end
	end
	self.currentTechLevel = maxtechlevel
end

function BuilderSquadsHandler:Init()
	self.squads = {
		military = {}, -- [i] = {leader = {[i] = {tqb = tqb, unit = unit}}, helper = {[i] = {tqb = tqb, unit = unit}}, hasPendingRequest, wtdbprate, curbp, maxbp, maxallowedbp}
		economy = {},
		expand = {},
		util = {},
		commander = {},
	}
	self.requests = {} -- [i] = {domain  = domain, role = role, [squadn = squadn]}
	self.idle = {} -- [i] = tqb
	self.states = {} -- [unitID] = {state = state, [params = params]}
	-- Initial setup, later this should become mapdependant and difficulty level dependant
	self.coeff = self.coeff or {economy = 0.2, military = 0.2, expand = 0.2, util = 0.2, commander = 0.2}
	self:AddRequest(nil, "commander", "leader")
	self:AddRequest(nil, "military", "leader")
	self:AddRequest(nil, "expand", "leader")
	self:AddRequest(nil, "expand", "leader")
	self:AddRequest(nil, "economy", "leader")
	self:AddRequest(nil, "expand", "leader")
	self:AddRequest(nil, "economy", "leader")
	self:AddRequest(nil, "expand", "leader")
	self:AddRequest(nil, "expand", "leader")
	-- Initial requests for all builderstypes, to ensure that DAI will always have an available con for all the different labs (provided that they don't die and get replaced by the wrong con...
	self:AddRequest('armck', "util", "leader")
	self:AddRequest('armack', "util", "leader")
	self:AddRequest('armcv', "util", "leader")
	self:AddRequest('armacv', "util", "leader")
	self:AddRequest('armaca', "util", "leader")
	self:AddRequest('armca', "util", "leader")
	self:AddRequest('corck', "util", "leader")
	self:AddRequest('corack', "util", "leader")
	self:AddRequest('coracv', "util", "leader")
	self:AddRequest('corcv', "util", "leader")
	self:AddRequest('coraca', "util", "leader")
	self:AddRequest('corca', "util", "leader")
	--
	self.currentTechLevel = 1
end

function BuilderSquadsHandler:SetCoeffs(economy, military, expand, util, commander)
	self.coeff = {economy = economy, military = military, expand = expand, util = util, commander = commander}
end

function BuilderSquadsHandler:SetState(tqb, unit, state, params, unitID)
	if state and state == "squad" and params and params.role and (params.role == "leader" or params.role == "helper") then
		tqb:Activate()
	else
		tqb:Deactivate()
	end
	if state == "dead" then
		self.states[unitID] = nil
		return
	end
	self.states[unit.id] = {state = state, params = params}
end

function BuilderSquadsHandler:GetState(tqb, unit)
	return self.states[tqb.unit:Internal().id]
end

function BuilderSquadsHandler:CheckIfExistingNewSquadRequest(techlevel, domain, role)
	for k = 1, #self.requests do
		if self.requests[k] and self.requests[k].domain == domain and self.requests[k].role == role and (not self.requests[k].name) then
			return true
		end
	end
	return false
end

function BuilderSquadsHandler:AddRequest(unitName, domain, role, squadn)
	self.requests[#self.requests + 1] = { domain = domain, role = role, squadn = squadn, name = unitName}
	return true
end

function BuilderSquadsHandler:RemoveRequest(i)
	if self.requests[i] and self.requests[i].domain and self.requests[i].squadn then
		if self.squads[self.requests[i].domain] and self.squads[self.requests[i].domain][self.requests[i].squadn] then
			if not self.squads[self.requests[i].domain][self.requests[i].squadn].hasPendingRequest then
				self.squads[self.requests[i].domain][self.requests[i].squadn].hasPendingRequest = 0
			end
			if self.squads[self.requests[i].domain][self.requests[i].squadn].hasPendingRequest >= 1 then
				self.squads[self.requests[i].domain][self.requests[i].squadn].hasPendingRequest = self.squads[self.requests[i].domain][self.requests[i].squadn].hasPendingRequest - 1
			end
		end
	end
	for k = i, #self.requests - 1 do
		self.requests[k] = self.requests[k+1]
	end
	self.requests[#self.requests] = nil
	return true
end

function BuilderSquadsHandler:CreateSquad(domain)
	local i = 1
	while self.squads[domain][i] ~= nil do
		i = i + 1
	end
	self.squads[domain][i] = squadtable(domain)
	return i
end

function BuilderSquadsHandler:RemoveSquad(domain, i)
	local curSquad = self.squads[domain][i]
	if curSquad then
		for k,v in pairs (curSquad.helper) do
			self:RegisterIdleRecruit(v.tqb, v.unit)
		end
		for k,v in pairs (curSquad.leader) do
			self:RegisterIdleRecruit(v.tqb, v.unit)
		end
		for k,v in pairs(self.requests) do
			if v.squadn == i then
				self:RemoveRequest(k)
			end
		end
		self.squads[domain][i] = {helper = {}, leader = {}}
	end
	self:AddRequest(_,domain, "leader") -- request for replacement squad
end

function BuilderSquadsHandler:ProcessUnit(unit)
	local defs = UnitDefs[UnitDefNames[unit:Name()].id]
	local canBuild = defs.buildSpeed > 0
	local canAssist = defs.canAssist and defs.canMove and (defs.speed > 0)
	local canBuildEco = EcoBuilders[self.currentTechLevel][defs.name] == true
	local canBuildMil = MilLeaders[defs.name] == true
	local canBuildUtil = UtilBuilders[defs.name] == true
	local canBuildExp = ExpBuilders[self.currentTechLevel][defs.name] == true
	local militaryhelper = defs.name == "armnanotc" or defs.name == "cornanotc"
	local militaryleader = canBuildMil
	local utilhelper = canBuildUtil
	local utilleader = canBuildUtil
	local economyhelper = canAssist
	local economyleader = canBuildEco
	local expandhelper = canAssist
	local expandleader = canBuildExp
	local commanderhelper = false
	local commanderleader = defs.name == "armcom" or defs.name == "corcom"	
	local canBe = {
		military = {helper = militaryhelper, leader = militaryleader},
		commander = {helper = commanderhelper, leader = commanderleader},
		util = {helper = utilhelper, leader = utilleader},
		economy = {helper = economyhelper, leader = economyleader},
		expand = {helper = expandhelper, leader = expandleader},
	}
	return defs.name, canBe
end

function BuilderSquadsHandler:AddRecruit(tqb)
	local unit = tqb.unit:Internal()
	local state = self:GetState(tqb,unit)
	self:RemoveIdleRecruit(tqb, unit)
	local unitName, canBe = self:ProcessUnit(unit)
	for i = 1, #self.requests do
		local req = self.requests[i]
		if req then
			if req.role == "leader" then
				if req.name and unitName == req.name then
					req.squadn = self:CreateSquad(req.domain)
					local success = self:AssignToSquad(tqb, unit, req.domain, req.role, req.squadn)
					if success then
						self:RemoveRequest(i)
						return true
					end
					self:RemoveSquad(req.domain, req.squadn)					
				elseif (not req.name) and canBe[req.domain][req.role] == true then
					req.squadn = self:CreateSquad(req.domain)
					local success = self:AssignToSquad(tqb, unit, req.domain, req.role, req.squadn)
					if success then
						self:RemoveRequest(i)
						return true
					end
					self:RemoveSquad(req.domain, req.squadn)
				end
			elseif canBe[req.domain][req.role] == true then
				if req.role == "helper" and req.domain == "military" then
					local success = self:AssignToMilSquad(tqb, unit, req.domain, req.role, req.squadn)
					if success == true then -- = dist ok
						self:RemoveRequest(i)
						return true
					elseif success == false then -- = squad err
						self:RemoveSquad(req.domain, req.squadn)
					end
					-- no squad err but dist not ok, don't get stucked
				else
					local success = self:AssignToSquad(tqb, unit, req.domain, req.role, req.squadn)
					if success then
						self:RemoveRequest(i)
						return true
					end
					self:RemoveSquad(req.domain, req.squadn)
				end
			end
		end
	end
	self:RegisterIdleRecruit(tqb, unit)
end

function BuilderSquadsHandler:RemoveRecruit(tqb)
	local unit = tqb.unit:Internal()
	local state = self:GetState(tqb, unit)
	if state and state.state then
		if state.state == "squad" then
			self:RemoveFromSquad(tqb, unit, state.params.domain, state.params.role, state.params.squadn)
		elseif state.state == "idle" then
			self:RemoveIdleRecruit(tqb, unit)
		end
	end
	self:SetState(tqb, unit, "dead",_, tqb.unit:Internal().id)
	tqb:Deactivate()
	tqb.unit = nil
end

function BuilderSquadsHandler:RegisterIdleRecruit(tqb, unit)
	local i = 1
	while self.idle[i] ~= nil do
		i = i + 1
	end
	self.idle[i] = tqb
	self:SetState(tqb, unit, "idle")
end

function BuilderSquadsHandler:RemoveIdleRecruit(tqb, unit)
	local offset = 0
	for i = 1, #self.idle do
		if (not self.idle[i]) or (not self.idle[i].unit) or self.idle[i].unit:Internal().id == tqb.unit:Internal().id then
			offset = offset + 1
		end
		self.idle[i] = self.idle[i+offset]
	end
end

function BuilderSquadsHandler:AssignToSquad(tqb, unit, domain, role, squadn)
	if self.squads[domain] and self.squads[domain][squadn] and self.squads[domain][squadn][role] then
		self.squads[domain][squadn][role][#self.squads[domain][squadn][role] + 1] = {tqb = tqb, unit = unit}
		self:SetState(tqb, unit, "squad", {domain = domain, role = role, squadn = squadn})
		return true
	else
		return false
	end
end

function BuilderSquadsHandler:AssignToMilSquad(tqb, unit, domain, role, squadn)
	if self.squads[domain] and self.squads[domain][squadn] and self.squads[domain][squadn][role] then
		if self.squads[domain][squadn]["leader"] and self.squads[domain][squadn]["leader"][1] and self.squads[domain][squadn]["leader"][1].unit then
			local leader = self.squads[domain][squadn]["leader"][1].unit
			local unitID, leaderID = unit.id, leader.id
			local dist = Spring.GetUnitSeparation(unitID, leaderID, true)
			if dist < 380 then
				self.squads[domain][squadn][role][#self.squads[domain][squadn][role] + 1] = {tqb = tqb, unit = unit}
				self:SetState(tqb, unit, "squad", {domain = domain, role = role, squadn = squadn})
				return true
			else
				return
			end
		end
	else
		return false
	end
end

function BuilderSquadsHandler:RemoveFromSquad(tqb, unit, domain, role, squadn)
	local squadrole = self.squads[domain][squadn][role]
	local offset = 0
	if role == "leader" then
		self:RemoveSquad(domain,i)
	else
		for i = 1, #squadrole do
			if squadrole[i].unit == unit then
				offset = offset + 1
			end
			if i + offset <= #squadrole then
				self.squads[domain][squadn][role][i] = self.squads[domain][squadn][role][i+offset]
			end
		end
	end
end

function BuilderSquadsHandler:AllowedExpense(res)
	local storedPart = (math.max(0,(res.c - res.s*0.1)))
	local producedPart = res.i
	return storedPart + producedPart
end

function BuilderSquadsHandler:Update()
	if not (Spring.GetGameFrame()%60 == 0) then
		return
	end
	self:WatchTechLevel()
	local curResources = {energy = self.ai.aimodehandler.resources["energy"], metal = self.ai.aimodehandler.resources["metal"]}
	local m = curResources.metal
	local e = curResources.energy
	local ame = self:AllowedExpense(m)
	local aee = self:AllowedExpense(e)
	self.resourcesManagement = {
	military = {e = self.coeff.military * aee, m = self.coeff.military * ame},
	economy = {e = self.coeff.economy * aee, m = self.coeff.economy * ame},
	expand = {e = self.coeff.expand * aee, m = self.coeff.expand * ame},
	util = {e = self.coeff.util * aee, m = self.coeff.util * ame},
	commander = {e = self.coeff.commander * aee, m = self.coeff.commander * ame},
	}
	for i, v in pairs(self.idle) do
		if self.idle[i] and self.idle[i].unit then
			self:AddRecruit(self.idle[i])
		end
	end
	for k,v in pairs(self.requests) do
		if v.sentToTaskQueues ~= true then
			v.sentToTaskQueues = true
		end
	end
	for domain, squads in pairs(self.squads) do
		local nSquads = 0
			for k, v in pairs(squads) do
				nSquads = nSquads + 1
			end
		for k, v in pairs(squads) do
			self:SquadUpdate(domain, k, 1/nSquads)
		end
	end
	for domain, squads in pairs(self.squads) do
		for k, v in pairs(squads) do
			if (not v.leader[1]) and (not v.helper[1]) then
				self.squads[domain][k] = nil
			end
		end
	end
end

function BuilderSquadsHandler:SquadUpdate(domain, i, coeff)
	local allocatedToThisSquad = { m = self.resourcesManagement[domain].m * coeff, e = self.resourcesManagement[domain].e * coeff}
	local curUsedBPTot = 0
	local curUsedMetalTot = 0
	local curUsedEnergyTot = 0
	local theoricMaxBPTot = 0
	local wantedBPrate = self.squads[domain][i].wtdbprate or 1
	for k,v in pairs(self.squads[domain][i].helper) do
		local unit = v.unit
		local unitID = unit.id
		local defs = UnitDefs[UnitDefNames[unit:Name()].id]
		local theoricMaxBP = defs.buildSpeed
		local _,curUsedMetal,_,curUsedEnergy = Spring.GetUnitResources(unitID)
		local curUsedBP = (Spring.GetUnitCurrentBuildPower(unitID) or 0) * defs.buildSpeed * wantedBPrate
		curUsedBPTot = curUsedBPTot + curUsedBP
		curUsedEnergyTot = curUsedEnergyTot + (curUsedEnergy or 0 )
		curUsedMetalTot = curUsedMetalTot + (curUsedMetal or 0)
		theoricMaxBPTot = theoricMaxBPTot + theoricMaxBP
	end
	for k,v in pairs(self.squads[domain][i].leader) do
		local unit = v.unit
		local unitID = unit.id
		local defs = UnitDefs[UnitDefNames[unit:Name()].id]
		if domain ~= "util" and TechLevel[unit:Name()] and TechLevel[unit:Name()] < self.currentTechLevel then
			self:RemoveSquad(domain, i)
			return
		end
		local theoricMaxBP = defs.buildSpeed
		local _,curUsedMetal,_,curUsedEnergy = Spring.GetUnitResources(unitID)
		local curUsedBP = (Spring.GetUnitCurrentBuildPower(unitID) or 0) * defs.buildSpeed * wantedBPrate -- curentBuildPower is displayed as a 0;1 relative value based on current maxbp (not necessarily the defs.buildSpeed so we gotta take the current rate into account.
		curUsedBPTot = curUsedBPTot + curUsedBP
		curUsedEnergyTot = curUsedEnergyTot + (curUsedEnergy or 0)
		curUsedMetalTot = curUsedMetalTot + (curUsedMetal or 0)
		theoricMaxBPTot = theoricMaxBPTot + theoricMaxBP
	end
	local curBPrate = curUsedBPTot / theoricMaxBPTot
	if curUsedMetalTot < allocatedToThisSquad.m and curUsedEnergyTot < allocatedToThisSquad.e then
		if curBPrate == 1.0  and domain ~= "commander" then
			if theoricMaxBPTot < self.squads[domain][i].maxallowedbp then
				if not self.squads[domain][i].hasPendingRequest then
					self.squads[domain][i].hasPendingRequest = 0
				end
				if self.squads[domain][i].hasPendingRequest < self.squads[domain][i].maxpendingrequests then
					self:AddRequest(_, domain, "helper", i)
					self.squads[domain][i].hasPendingRequest = self.squads[domain][i].hasPendingRequest + 1
				end
			elseif self:CheckIfExistingNewSquadRequest(_,domain, "leader") ~= true then
				self:AddRequest(_, domain, "leader")
			end
		else
			wantedBPrate = math.min(1.0, wantedBPrate + 0.1)
		end
	else
		wantedBPrate = math.max(0.01, wantedBPrate - 0.1)
	end
	for k,v in pairs(self.squads[domain][i].helper) do
		local unit = v.unit
		local unitID = unit.id
		local defs = UnitDefs[UnitDefNames[unit:Name()].id]
		Spring.SetUnitBuildSpeed(unitID, defs.buildSpeed * wantedBPrate)
	end
	for k,v in pairs(self.squads[domain][i].leader) do
		local unit = v.unit
		local unitID = unit.id
		local defs = UnitDefs[UnitDefNames[unit:Name()].id]
		Spring.SetUnitBuildSpeed(unitID, defs.buildSpeed * wantedBPrate)
	end
	self.squads[domain][i].wtdbprate = wantedBPrate
	self.squads[domain][i].curbp = curUsedBPTot
	self.squads[domain][i].maxbp = theoricMaxBPTot
end

function BuilderSquadsHandler:ScoreUnit(unit)
end
