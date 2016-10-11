local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("ScoutHandler: " .. inStr)
	end
end

ScoutHandler = class(Module)

function ScoutHandler:Name()
	return "ScoutHandler"
end

function ScoutHandler:internalName()
	return "scouthandler"
end

function ScoutHandler:Init()
	self.spotsToScout = {}
	self.lastCount = {}
	self.sameCount = {}
	self.usingStarts = {}
end

function ScoutHandler:ScoutLos(scoutbehaviour, position)
	local los
	if ai.maphandler:IsUnderWater(position) and unitTable[scoutbehaviour.name].sonarRadius == 0 then
		-- treat underwater spots as surface spots if the scout has no sonar, so that it moves on
		local lt = ai.loshandler:AllLos(position)
		if lt[2] then
			los = 2
		else
			los = 0
		end
	else
		los = ai.loshandler:GroundLos(position)
	end
	return los
end

function ScoutHandler:ClosestSpot(scoutbehaviour)
	local unit = scoutbehaviour.unit:Internal()
	local position = unit:GetPosition()
	local mtype = scoutbehaviour.mtype
	if mtype == nil then mtype = "air" end
	if network == nil then network = 1 end
	-- initializing the necessary tables if they're not yet
	if self.spotsToScout[mtype] == nil then self.spotsToScout[mtype] = {} end
	if self.spotsToScout[mtype][network] == nil then self.spotsToScout[mtype][network] = {} end
	if self.usingStarts[mtype] == nil then self.usingStarts[mtype] = {} end
	if self.usingStarts[mtype][network] == nil then self.usingStarts[mtype][network] = false end
	if self.lastCount[mtype] == nil then self.lastCount[mtype] = {} end
	if self.lastCount[mtype][network] == nil then self.lastCount[mtype][network] = 0 end
	if self.sameCount[mtype] == nil then self.sameCount[mtype] = {} end
	if self.sameCount[mtype][network] == nil then self.sameCount[mtype][network] = 0 end
	-- filling table of spots to scout if empty
	if #self.spotsToScout[mtype][network] == 0 then
		if not self.usingStarts[mtype][network] then 
			if ai.startLocations[mtype] ~= nil then
				if ai.startLocations[mtype][network] ~= nil then
					-- scout all probable start locations first
					EchoDebug(unit:Name() .. " got starts")
					for i, p in pairs(ai.startLocations[mtype][network]) do
						table.insert(self.spotsToScout[mtype][network], p)
					end
				end
			end
			-- true even if no start locations were in network, so that it moves onto using metals/geos next
			self.usingStarts[mtype][network] = true
		elseif self.usingStarts[mtype][network] then
			-- then use metal and geo spots
			EchoDebug(unit:Name() .. " got metals and geos")
			for i, p in pairs(ai.scoutSpots[mtype][network]) do
				table.insert(self.spotsToScout[mtype][network], p)
			end
			self.usingStarts[mtype][network] = false
		end
	end
	EchoDebug(mtype .. " " .. network .. " has " .. #self.spotsToScout[mtype][network] .. " spots")
	-- find the closest spot
	local pos = nil
	local index = nil
	local bestDistance = 10000
	for i = #self.spotsToScout[mtype][network], 1, -1 do
		local p = self.spotsToScout[mtype][network][i]
		local los
		if ai.maphandler:IsUnderWater(p) and unitTable[scoutbehaviour.name].sonarRadius == 0 then
			-- treat underwater spots as surface spots if the scout has no sonar, so that it moves on
			local lt = ai.loshandler:AllLos(p)
			if lt[2] then
				los = 2
			else
				los = 0
			end
		else
			los = ai.loshandler:GroundLos(p)
		end
		if los == 2 or los == 3 or not ai.targethandler:IsSafePosition(p, unit, 1) then
			table.remove(self.spotsToScout[mtype][network], i)
		else
			local dist = Distance(position, p)
			if dist < bestDistance then
				bestDistance = dist
				pos = p
				index = i
			end
		end
	end
	-- make sure we're not getting quixotic
	if #self.spotsToScout[mtype][network] == self.lastCount[mtype][network] then
		self.sameCount[mtype][network] = self.sameCount[mtype][network] + 1
		if self.sameCount[mtype][network] > 15 then
			-- if the last spots can't be scouted for some reason, just clear the list to repopulate it
			self.spotsToScout[mtype][network] = {}
		end
	else
		self.sameCount[mtype][network] = 0
	end
	self.lastCount[mtype][network] = #self.spotsToScout[mtype][network]
	if pos ~= nil then
		EchoDebug("and spot found")
		pos.y = 0
	else
		EchoDebug("but NO spot found")
	end
	return pos
end