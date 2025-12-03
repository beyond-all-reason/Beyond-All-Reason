--- This is the definition of a unit AI!
--
-- it isn't the unit itself, but rather the mini-AI
-- that controls it
Unit = class(AIBase)

local function tracyZoneBeginMem() return end
local function tracyZoneEndMem() return end

if tracy and not tracy then
	Spring.Echo("Enabled Tracy support for UNIT STAI")
	tracyZoneBeginMem = function(fname)
		if logRAM then lastGCinfo = gcinfo() end
		tracy.ZoneBeginN(fname)
	end

	tracyZoneEndMem = function(fname)
		fname = fname or "STAI"
		if logRAM then
			local nowGCinfo = gcinfo()
			local delta = nowGCinfo - lastGCinfo
			if delta > 0 then
				tracy.Message(tostring(fname .. nowGCinfo - lastGCinfo))
			end
			lastGCinfo = nowGCinfo
		end
		tracy.ZoneEnd()
	end
end

function Unit:Init()
	-- check if we were set up correctly
	if self.engineUnit == nil then
		-- oh noes, someone was meant to call SetEngineRepresentation
		-- on this before calling Init
		--
		-- @see Unit:SetEngineRepresentation
		self:Warn("Shard Unit:Init revieved a nil engineUnit :(")
	end
	self.behaviours = {}
	self.nextBehaviour = nil
	self.activeBehaviour = nil
end

--- Tell the unit AI which unit it's coontrolling
--
-- This is how it knows which unit it is
--
-- @param engineUnit the unit object ( Shard unit )
function Unit:SetEngineRepresentation(engineUnit)
	self.engineUnit = engineUnit
	self.engineID = engineUnit:ID()
end

--- Which unit is this controlling?
--
-- This object is great at being a mini-AI
-- for controlling a unit, but which unit?!
--
-- @return a shard unit object
function Unit:Internal()
	return self.engineUnit
end

function Unit:Update()
	-- Handle activating a new behaviour if we switched
	if self.nextBehaviour ~= nil then
		self.activeBehaviour = self.nextBehaviour
		self.nextBehaviour = nil
		self.activeBehaviour:PreActivate()
		self.activeBehaviour:Activate()
	end

	-- Pass the update event to the behaviours
	for k,behaviour in pairs(self.behaviours) do
		--self.game:StartTimer(behaviour:Name() .. ' Unit')
		--tracyZoneBeginMem('STAI:'..behaviour:Name())
		behaviour:Update()
		--tracyZoneEndMem('STAI:'..behaviour:Name())
		--self.game:StopTimer(behaviour:Name() .. ' Unit')
	end
--  		RAM = gcinfo() - RAM
--  		if RAM > 0 then
--  			Spring.Echo(--[[behaviour:Name(),]]self:Internal():Name(), RAM , 'RAM')
-- 		end
end

function Unit:GameEnd()
	for k,v in pairs(self.behaviours) do
		v:GameEnd()
	end
end

function Unit:UnitCreated(unit, unitDefId, teamId, builderId)
	if unit then -- TEMPORARY FIX
		if unit.engineID == self.engineID then
			for k,v in pairs(self.behaviours) do
				--self.game:StartTimer(v:Name() .. 'OCreated')
				v:OwnerCreated(unit, unitDefId, teamId, builderId)
-- 				self.game:StopTimer(v:Name() .. 'OCreated')
			end
		end
		for k,v in pairs(self.behaviours) do
			--self.game:StartTimer(v:Name() .. 'Created')
			v:UnitCreated(unit, unitDefId, teamId, builderId)
			--self.game:StopTimer(v:Name() .. 'Created')

		end
	end
end

function Unit:UnitBuilt(unit)
	if unit.engineID == self.engineID then
		self:ElectBehaviour()
		for k,v in pairs(self.behaviours) do
			--self.game:StartTimer(v:Name() .. 'Ubuilt')
			v:OwnerBuilt()
-- 			self.game:StopTimer(v:Name() .. 'Ubuilt')
		end
	else
		for k,v in pairs(self.behaviours) do
			--self.game:StartTimer(v:Name() .. 'Obuilt')
			v:UnitBuilt(unit)
-- 			self.game:StopTimer(v:Name() .. 'Obuilt')
		end
 	end
end

function Unit:UnitDead(unit)

	if unit.engineID == self.engineID then
		if self.behaviours then
			-- game:SendToConsole("unit died, removing behaviours", self.engineID, self:Internal():Name())
			for k,v in pairs(self.behaviours) do
				self.behaviours[k]:OwnerDead()
				self.behaviours[k] = nil
			end
			self.behaviours = nil
		end
		self.engineUnit = nil
	else
		for k,v in pairs(self.behaviours) do
			v:UnitDead(unit)
		end
	end
end


function Unit:UnitDamaged(unit,attacker,damage)
	if unit.engineID == self.engineID then
-- 		--self.game:StartTimer(v:Name() .. 'G')
		for k,v in pairs(self.behaviours) do

			v:OwnerDamaged(attacker,damage)

		end
	else
		for k,v in pairs(self.behaviours) do

			v:UnitDamaged(unit,attacker,damage)

		end
-- 		--self.game:StopTimer(v:Name() .. 'G')
	end
end

function Unit:UnitIdle(unit)
	if unit.engineID == self.engineID then
		for k,v in pairs(self.behaviours) do
			--self.game:StartTimer(v:Name() .. 'I')
			v:OwnerIdle()
			--self.game:StopTimer(v:Name() .. 'I')
		end
	else
		for k,v in pairs(self.behaviours) do
			--self.game:StartTimer(v:Name() .. 'I')
			v:UnitIdle(unit)
			--self.game:StopTimer(v:Name() .. 'I')
		end
	end
end

function Unit:UnitMoveFailed(unit)
	if unit.engineID == self.engineID then
		for k,v in pairs(self.behaviours) do
			v:OwnerMoveFailed()
		end
	else
		for k,v in pairs(self.behaviours) do
			v:UnitMoveFailed(unit)
		end
	end
end

-- Adds a new behaviour to this unit.
--
-- It does not activate that behaviour though
--
-- @param behaviour The behaviour to add
function Unit:AddBehaviour(behaviour)
	table.insert(self.behaviours,behaviour)
end

--- Which behaviour has control of this unit?
--
-- @return the behaviour or nil
function Unit:ActiveBehaviour()
	return self.activeBehaviour
end

--- Does this unit have behaviours?
--
-- Units with no behaviours do not get events
--
-- @return true or false
function Unit:HasBehaviours()
	if self.behaviours ~= nil then
		if #self.behaviours > 0 then
			return true
		end
	end
	return false
end

--- Picks and activates the best behaviour to control this unit!
--
-- If there are no behaviours or all behaviours have a
-- negative/zero priority no behaviour is activated.
--
-- The elected behaviour will be activated on the next update,
-- the currently activated behaviour is deactivated immediatley.
--
-- If the current behaviour is elected, there is no change
-- The active behaviour has full control of the unit
function Unit:ElectBehaviour()
	-- Check if we have any behaviours to elect
	if self:HasBehaviours() == false then
		return -- exit early
	end

	local bestBehaviour = nil
	local bestScore = -1

	for k,behaviour in pairs(self.behaviours) do
		if bestBehaviour == nil then
			bestBehaviour = behaviour
			bestScore = behaviour:Priority()
		else
			local score = behaviour:Priority()
			if ( score > 0 ) and ( score > bestScore ) then
				bestScore = score
				bestBehaviour = behaviour
			end
		end
	end

	if bestBehaviour ~= nil then
		if ( self.activeBehaviour ~= bestBehaviour ) and ( self.nextBehaviour ~= bestBehaviour ) then
			if self.activeBehaviour ~= nil then
				self.activeBehaviour:PreDeactivate()
				self.activeBehaviour:Deactivate()
			end
			self.nextBehaviour = bestBehaviour
		end
	end
end
