shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
	self.scoutslist = {}
end

--[[
local function HasKey( value, list )
	for k,v in pairs(list) do
		if k == value then
			return true
		end
	end
	return false
end]]

local function HasKey( value, list )
	if list[value] then
		return true
	end
	return false
end

function BehaviourFactory:AddBehaviours(unit)
	if unit == nil then
		self.game:SendToConsole("Warning: Shard BehaviourFactory:AddBehaviours was asked to provide behaviours to a nil unit")
		return
	end
	-- add behaviours here
	-- unit:AddBehaviour(behaviour)
	local b = self.behaviours[unit:Internal():Name()]
	if b == nil then
		b = self:defaultBehaviours(unit)
	end
	for i,behaviour in ipairs(b) do
		t = behaviour()
		t:SetAI(self.ai)
		t:SetUnit(unit)
		t:Init()
		unit:AddBehaviour(t)
	end
end

function BehaviourFactory:defaultBehaviours(unit)
	local b = {}
	local u = unit:Internal()
	local un = u:Name()
	-- game:SendToConsole(un, "getting default behaviours")

	-- keep track of how many of each kind of unit we have
	table.insert(b, CountBST)
	table.insert(b, BootBST)

	if commanderList[un] then
		table.insert(b, CommanderBST)
	end

	if nanoTurretList[un] then
		table.insert(b, AssistBST)
		table.insert(b, WardBST)
		table.insert(b, CleanerBST)
	end

	if self.ai.data.unitTable[un].isBuilding then
		table.insert(b, WardBST) --tells defending units to rush to threatened buildings
		if nukeList[un] then
			table.insert(b, NukeBST)
		elseif antinukeList[un] then
			table.insert(b, AntinukeBST)
		elseif bigPlasmaList[un] then
			table.insert(b, BombardBST)
		end
	end

	if u:CanBuild() then
		-- game:SendToConsole(u:Name() .. " can build")
		-- moho engineer doesn't need the queue!
		if advConList[un] then
			-- game:SendToConsole(u:Name() .. " is advanced construction unit")
			-- half advanced engineers upgrade mexes instead of building things
			if self.ai.advCons == nil then self.ai.advCons = 0 end
			if self.ai.advCons == 0 then
				-- game:SendToConsole(u:Name() .. " taskqueuing")
				table.insert(b, MexUpgradeBehaviour)
				self.ai.advCons = 1
			else
				-- game:SendToConsole(u:Name() .. " mexupgrading")
				self.ai.advCons = 0
			end
			table.insert(b,TaskQueueBST)
		else
			table.insert(b,TaskQueueBST)
			if self.ai.data.unitTable[un].isBuilding then
				table.insert(b, LabRegisterBST)
			else
				table.insert(b, AssistBST)
				table.insert(b, ReclaimBST)
				table.insert(b, CleanerBST)
			end
		end
		table.insert(b, WardBST)
	elseif IsReclaimer(unit) then
		table.insert(b, ReclaimBST)
		table.insert(b, WardBST)
	else
		if HasKey(un,attackerlist)then
			table.insert(b, AttackerBST)
			-- if battleList[un] or breakthroughList[un] then
				-- arty and merl don't make good defense
				table.insert(b, DefendBST)
			-- end
		end
		if HasKey(un,raiderList) then
			table.insert(b, RaiderBST)
			table.insert(b, ScoutBST)
			if self.ai.data.unitTable[un].mtype ~= "air" then
				table.insert(b, DefendBST)
			end -- will only defend when scrambled by danger
		end
		if HasKey(un,bomberList) then
			table.insert(b, BomberBST)
		end
		if HasKey(un,scoutList)then
			table.insert(b, ScoutBST)
			table.insert(b, WardBST)
		end
		if IsDefender(unit) then
			table.insert(b, DefendBST)
		end
	end

	local alreadyHave = {}
	for i = #b, 1, -1 do
		local behaviour = b[i]
		if alreadyHave[behaviour] then
			-- game:SendToConsole(self.ai.id, "duplicate behaviour", u:ID(), u:Name())
			table.remove(b, i)
		else
			alreadyHave[behaviour] = true
		end
	end
	-- game:SendToConsole(self.ai.id, #b, "behaviours", u:ID(), u:Name())

	return b
end
