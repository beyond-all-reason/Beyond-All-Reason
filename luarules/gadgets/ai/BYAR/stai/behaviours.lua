shard_include ("taskqueuebehaviour",subf)
shard_include ("attackerbehaviour",subf)
shard_include ("raiderbehaviour",subf)
shard_include ("bomberbehaviour",subf)
shard_include ("wardbehaviour",subf)
shard_include ("mexupgradebehaviour",subf)
shard_include ("assistbehaviour",subf)
shard_include ("reclaimbehaviour",subf)
shard_include ("cleanerbehaviour",subf)
shard_include ("defendbehaviour",subf)
shard_include ("factoryregisterbehaviour",subf)
shard_include ("scoutbehaviour",subf)
shard_include ("antinukebehaviour",subf)
shard_include ("nukebehaviour",subf)
shard_include ("bombardbehaviour",subf)
shard_include ("commanderbehaviour",subf)
shard_include ("bootbehaviour",subf)
shard_include ("countbehaviour",subf)


behaviours = {

}


function defaultBehaviours(unit, ai)
	local b = {}
	local u = unit:Internal()
	local un = u:Name()
	-- game:SendToConsole(un, "getting default behaviours")

	-- keep track of how many of each kind of unit we have
	table.insert(b, CountBehaviour)
	table.insert(b, BootBehaviour)

	if commanderList[un] then
		table.insert(b, CommanderBehaviour)
	end

	if nanoTurretList[un] then
		table.insert(b, AssistBehaviour)
		table.insert(b, WardBehaviour)
		table.insert(b, CleanerBehaviour)
	end

	if unitTable[un].isBuilding then
		table.insert(b, WardBehaviour) --tells defending units to rush to threatened buildings
		if nukeList[un] then
			table.insert(b, NukeBehaviour)
		elseif antinukeList[un] then
			table.insert(b, AntinukeBehaviour)
		elseif bigPlasmaList[un] then
			table.insert(b, BombardBehaviour)
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
				table.insert(b, FactoryRegisterBehaviour)
			else
				table.insert(b, AssistBehaviour)
				table.insert(b, ReclaimBehaviour)
				table.insert(b, CleanerBehaviour)
			end
		end
		table.insert(b, WardBehaviour)
	elseif IsReclaimer(unit) then
		table.insert(b, ReclaimBehaviour)
		table.insert(b, WardBehaviour)
	else
		if IsAttacker(unit) then
			table.insert(b, AttackerBehaviour)
			-- if battleList[un] or breakthroughList[un] then
				-- arty and merl don't make good defense
				table.insert(b, DefendBehaviour)
			-- end
		end
		if IsRaider(unit) then
			table.insert(b, RaiderBehaviour)
			table.insert(b, ScoutBehaviour)
			if unitTable[un].mtype ~= "air" then table.insert(b, DefendBehaviour) end -- will only defend when scrambled by danger
		end
		if IsBomber(unit) then
			table.insert(b, BomberBehaviour)
		end
		if IsScout(unit) then
			table.insert(b, ScoutBehaviour)
			table.insert(b, WardBehaviour)
		end
		if IsDefender(unit) then
			table.insert(b, DefendBehaviour)
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
