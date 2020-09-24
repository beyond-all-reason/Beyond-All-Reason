shard_include( "behaviour" )
BehaviourFactory = class(AIBase)

function BehaviourFactory:Init()
	self.behaviours = shard_include( "behaviours" )
	self.scoutslist = shard_include( "scouts" )
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
		t:SetAI(ai)
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
		table.insert(b, STAssistBehaviour)
		table.insert(b, STWardBehaviour)
		table.insert(b, CleanerBST)
	end

	if unitTable[un].isBuilding then
		table.insert(b, STWardBehaviour) --tells defending units to rush to threatened buildings
		if nukeList[un] then
			table.insert(b, NukeBehaviour)
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
			if ai.advCons == nil then ai.advCons = 0 end
			if ai.advCons == 0 then
				-- game:SendToConsole(u:Name() .. " taskqueuing")
				table.insert(b, MexUpgradeBehaviour)
				ai.advCons = 1
			else
				-- game:SendToConsole(u:Name() .. " mexupgrading")
				ai.advCons = 0
			end
			table.insert(b,TaskQueueBehaviour)
		else
			table.insert(b,TaskQueueBehaviour)
			if unitTable[un].isBuilding then
				table.insert(b, LabRegisterBST)
			else
				table.insert(b, STAssistBehaviour)
				table.insert(b, ReclaimBehaviour)
				table.insert(b, CleanerBST)
			end
		end
		table.insert(b, STWardBehaviour)
	elseif IsReclaimer(unit) then
		table.insert(b, ReclaimBehaviour)
		table.insert(b, STWardBehaviour)
	else
		if IsAttacker(unit) then
			table.insert(b, AttackerBST)
			-- if battleList[un] or breakthroughList[un] then
				-- arty and merl don't make good defense
				table.insert(b, DefendBST)
			-- end
		end
		if IsRaider(unit) then
			table.insert(b, RaiderBehaviour)
			table.insert(b, ScoutBehaviour)
			if unitTable[un].mtype ~= "air" then table.insert(b, DefendBST) end -- will only defend when scrambled by danger
		end
		if IsBomber(unit) then
			table.insert(b, BomberBST)
		end
		if IsScout(unit, self.scoutlist) then
			table.insert(b, ScoutBehaviour)
			table.insert(b, STWardBehaviour)
		end
		if IsDefender(unit) then
			table.insert(b, DefendBST)
		end
	end

	local alreadyHave = {}
	for i = #b, 1, -1 do
		local behaviour = b[i]
		if alreadyHave[behaviour] then
			-- game:SendToConsole(ai.id, "duplicate behaviour", u:ID(), u:Name())
			table.remove(b, i)
		else
			alreadyHave[behaviour] = true
		end
	end
	-- game:SendToConsole(ai.id, #b, "behaviours", u:ID(), u:Name())

	return b
end


function IsScouts(unit, scoutslist)
	for i,name in ipairs(scoutslist) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end
