RequestsHandler = class(Module)

function RequestsHandler:Name()
	return "RequestsHandler"
end

function RequestsHandler:internalName()
	return "requestshandler"
end

function RequestsHandler:Init()
	self.requests = {}
end

local UDC = Spring.GetTeamUnitDefCount
local UDN = UnitDefNames

function RequestsHandler:Update()
	local ec, es, ep, ei, ee = Spring.GetTeamResources(self.ai.id, "energy")
	local mc, ms, mp, mi, me = Spring.GetTeamResources(self.ai.id, "metal")
	if ei > 2000 and (not self.t1ecoreclaimrequested) then
		for ct, unitID in pairs(Spring.GetTeamUnitsByDefs(self.ai.id, {UDN.armwin.id, UDN.armmakr.id, UDN.armsolar.id, UDN.armadvsol.id, UDN.corwin.id, UDN.cormakr.id, UDN.corsolar.id, UDN.coradvsol.id})) do
			self:AddRequest(false, {action = "command", params = { cmdID = CMD.RECLAIM, cmdParams = {unitID}, cmdOptions = {}}})
		end
		self.t1ecoreclaimrequested = true
	end
end

function RequestsHandler:AddRequest(priority, requestedTask, commrequired)
	if not self.requests[1] then
		self.requests[1] = requestedTask
		return
	end
	if priority == true then
		for i = #self.requests,1, -1 do
			if self.requests[i] then
				self.requests[i + 1] = self.requests[i]
			end
		end
		self.requests[1] = requestedTask
	else
		self.requests[#self.requests+1] = requestedTask
	end
	-- if priority == true and commrequired == true then
		-- local comms = Spring.GetTeamUnitsByDefs(self.ai.id, {UnitDefNames.armcom.id, UnitDefNames.corcom.id})
		-- for ct, unitID in pairs(comms) do
			-- Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
		-- end
	-- end
end

function RequestsHandler:RemoveRequest(n)
	for i = n, #self.requests - 1 do
		self.requests[i] = self.requests[i + 1]
	end
	self.requests[#self.requests] = nil
end

function RequestsHandler:GetRequestedTask(unit)
	if self.requests[1] then
		if self.requests[1].needCom == true and (not (unit:Name() == "armcom" or unit:Name() == "corcom")) then 
			return {action = "nexttask"} 
		end
		local task = self.requests[1]
		self:RemoveRequest(1)
		return task
	else
		return {action = "nexttask"}
	end
end
