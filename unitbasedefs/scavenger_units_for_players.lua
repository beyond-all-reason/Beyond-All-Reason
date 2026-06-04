local function scavengerUnitsForPlayers(name, unitDef)
	local buildoptions = unitDef.buildoptions

	-- Armada T1 Land Constructors
	if name == "armca" or name == "armck" or name == "armcv" then
		local numBuildoptions = #buildoptions
	end

	-- Armada T1 Sea Constructors
	if name == "armcs" or name == "armcsa" then
		local numBuildoptions = #buildoptions
	end

	-- Armada T1 Vehicle Factory
	if name == "armvp" then
		local numBuildoptions = #buildoptions
	end

	-- Armada T1 Aircraft Plant
	if name == "armap" then
		local numBuildoptions = #buildoptions
	end

	-- Armada T2 Constructors
	if name == "armaca" or name == "armack" or name == "armacv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armapt3" -- T3 Aircraft Gantry
		buildoptions[numBuildoptions + 2] = "armminivulc" -- Mini Ragnarok
		buildoptions[numBuildoptions + 3] = "armbotrail" -- Pawn Launcher
		buildoptions[numBuildoptions + 4] = "armannit3" -- Epic Pulsar
		buildoptions[numBuildoptions + 5] = "armafust3" -- Epic Fusion Reactor
		buildoptions[numBuildoptions + 6] = "armmmkrt3" -- Epic Energy Converter
	end

	-- Armada T2 Shipyard
	if name == "armasy" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armdronecarry" -- Nexus - Drone Carrier
		buildoptions[numBuildoptions + 2] = "armptt2"  -- Epic Skater
		buildoptions[numBuildoptions + 3] = "armdecadet3" -- Epic Dolphin
		buildoptions[numBuildoptions + 4] = "armpshipt3" -- Epic Ellysaw
		buildoptions[numBuildoptions + 5] = "armserpt3" -- Epic Serpent
		buildoptions[numBuildoptions + 6] = "armtrident" -- Trident - Depth Charge Drone Carrier
	end

	-- Armada T3 Gantry
	if name == "armshltx" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armrattet4"   -- Ratte - Very Heavy Tank
		buildoptions[numBuildoptions + 2] = "armsptkt4"    -- Epic Recluse
		buildoptions[numBuildoptions + 3] = "armpwt4"      -- Epic Pawn
		buildoptions[numBuildoptions + 4] = "armvadert4"   -- Epic Tumbleweed - Nuclear Rolling Bomb
		buildoptions[numBuildoptions + 5] = "armdronecarryland" -- Nexus Terra - Drone Carrier
	end

	-- Armada T3 Underwater Gantry
	if name == "armshltxuw" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armrattet4" -- Ratte - Very Heavy Tank
		buildoptions[numBuildoptions + 2] = "armsptkt4" -- Epic Recluse
		buildoptions[numBuildoptions + 3] = "armpwt4" -- Epic Pawn
		buildoptions[numBuildoptions + 4] = "armvadert4" -- Epic Tumbleweed - Nuclear Rolling Bomb
	end

	-- Cortex T1 Bots Factory
	if name == "corlab" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corkark" -- Archaic Karkinos
	end

	-- Cortex T2 Land Constructors
	if name == "coraca" or name == "corack" or name == "coracv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corapt3" -- T3 Aircraft Gantry
		buildoptions[numBuildoptions + 2] = "corminibuzz" -- Mini Calamity
		buildoptions[numBuildoptions + 3] = "corhllllt" -- Quad Guard - Quad Light Laser Turret
		buildoptions[numBuildoptions + 4] = "cordoomt3" -- Epic Bulwark
		buildoptions[numBuildoptions + 5] = "corafust3" -- Epic Fusion Reactor
		buildoptions[numBuildoptions + 6] = "cormmkrt3" -- Epic Energy Converter
	end

	-- Cortex T2 Sea Constructors
	if name == "coracsub" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T2 Bots Factory
	if name == "coralab" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T2 Vehicle Factory
	if name == "coravp" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corgatreap" -- Laser Tiger
		buildoptions[numBuildoptions + 2] = "corftiger" -- Heat Tiger
	end

	-- Cortex T2 Aircraft Plant
	if name == "coraap" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corcrw" -- Archaic Dragon
	end

	-- Cortex T2 Shipyard
	if name == "corasy" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "cordronecarry" -- Dispenser - Drone Carrier
		buildoptions[numBuildoptions + 2] = "corslrpc" -- Leviathan - LRPC Ship
		buildoptions[numBuildoptions + 3] = "corsentinel" -- Sentinel - Depth Charge Drone Carrier
	end

	-- Cortex T3 Gantry
	if name == "corgant" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corkarganetht4" -- Epic Karganeth
		buildoptions[numBuildoptions + 2] = "corgolt4"  -- Epic Tzar
		buildoptions[numBuildoptions + 3] = "corakt4"   -- Epic Grunt
		buildoptions[numBuildoptions + 4] = "corthermite" -- Thermite/Epic Termite
		buildoptions[numBuildoptions + 5] = "cormandot4" -- Epic Commando
	end

	-- Cortex T3 Underwater Gantry
	if name == "corgantuw" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corkarganetht4" -- Epic Karganeth
		buildoptions[numBuildoptions + 2] = "corgolt4"  -- Epic Tzar
		buildoptions[numBuildoptions + 3] = "corakt4"   -- Epic Grunt
		buildoptions[numBuildoptions + 4] = "cormandot4" -- Epic Commando
	end

	-- Legion T1 Land Constructors
	if name == "legca" or name == "legck" or name == "legcv" then
		local numBuildoptions = #buildoptions
	end

	-- Legion T2 Land Constructors
	if name == "legaca" or name == "legack" or name == "legacv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "legapt3"    -- T3 Aircraft Gantry
		buildoptions[numBuildoptions + 2] = "legministarfall" -- Mini Starfall
		buildoptions[numBuildoptions + 3] = "legafust3"  -- Epic Fusion Reactor
		buildoptions[numBuildoptions + 4] = "legadveconvt3" -- Epic Energy Converter
	end

	-- Legion T3 Gantry
	if name == "leggant" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "legsrailt4"     -- Epic Arquebus
		buildoptions[numBuildoptions + 2] = "leggobt3"       -- Epic Goblin
		buildoptions[numBuildoptions + 3] = "legpede"        -- Mukade - Heavy Multi Weapon Centipede
		buildoptions[numBuildoptions + 4] = "legeheatraymech_old" -- Old Sol Invictus - Quad Heatray Mech
	end
end

return {
	Tweaks = scavengerUnitsForPlayers,
}