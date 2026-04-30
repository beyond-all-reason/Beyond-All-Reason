local function experimentalExtraUnits(name, unitDef)
	local buildoptions = unitDef.buildoptions

	-- Armada T1 Land Constructors
	if name == "armca" or name == "armck" or name == "armcv" then
		local numBuildoptions = #buildoptions
	end

	-- Armada T1 Sea Constructors
	if name == "armcs" or name == "armcsa" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armgplat" -- Gun Platform - Light Plasma Defense
		buildoptions[numBuildoptions + 2] = "armfrock" -- Scumbag - Anti Air Missile Battery
	end

	-- Armada T1 Vehicle Factory
	if name == "armvp" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armzapper" -- Zapper - Light EMP Vehicle
	end

	-- Armada T1 Aircraft Plant
	if name == "armap" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armfify" -- Firefly - Resurrection Aircraft
	end

	-- Armada T2 Land Constructors
	if name == "armaca" or name == "armack" or name == "armacv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armshockwave" -- Shockwave - T2 EMP Armed Metal Extractor
		buildoptions[numBuildoptions + 2] = "armwint2" -- T2 Wind Generator
		buildoptions[numBuildoptions + 3] = "armnanotct2" -- T2 Constructor Turret
		buildoptions[numBuildoptions + 4] = "armlwall" -- Dragon's Fury - T2 Pop-up Wall Turret
		buildoptions[numBuildoptions + 5] = "armgatet3" -- Asylum - Advanced Shield Generator
	end

	-- Armada T2 Sea Constructors
	if name == "armacsub" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armfgate" -- Aurora - Floating Plasma Deflector
		buildoptions[numBuildoptions + 2] = "armnanotc2plat" -- Floating T2 Constructor Turret
	end

	-- Armada T2 Shipyard
	if name == "armasy" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armexcalibur" -- Excalibur - Coastal Assault Submarine
		buildoptions[numBuildoptions + 2] = "armseadragon" -- Seadragon - Nuclear ICBM Submarine
	end

	-- Armada T3 Gantry
	if name == "armshltx" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
		buildoptions[numBuildoptions + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech
	end

	-- Armada T3 Underwater Gantry
	if name == "armshltxuw" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "armmeatball" -- Meatball - Amphibious Assault Mech
		buildoptions[numBuildoptions + 2] = "armassimilator" -- Assimilator - Amphibious Battle Mech
	end

	-- Cortex T1 Land Constructors
	if name == "corca" or name == "corck" or name == "corcv" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T1 Sea Constructors
	if name == "corcs" or name == "corcsa" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corgplat" -- Gun Platform - Light Plasma Defense
		buildoptions[numBuildoptions + 2] = "corfrock" -- Janitor - Anti Air Missile Battery
	end

	-- Cortex T1 Bots Factory
	if name == "corlab" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T2 Land Constructors
	if name == "coraca" or name == "corack" or name == "coracv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corwint2" -- T2 Wind Generator
		buildoptions[numBuildoptions + 2] = "cornanotct2" -- T2 Constructor Turret
		buildoptions[numBuildoptions + 3] = "cormwall" -- Dragon's Rage - T2 Pop-up Wall Turret
		buildoptions[numBuildoptions + 4] = "corgatet3" -- Sanctuary - Advanced Shield Generator
	end

	-- Cortex T2 Sea Constructors
	if name == "coracsub" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corfgate" -- Atoll - Floating Plasma Deflector
		buildoptions[numBuildoptions + 2] = "cornanotc2plat" -- Floating T2 Constructor Turret
	end

	-- Cortex T2 Bots Factory
	if name == "coralab" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "cordeadeye"
	end

	-- Cortex T2 Vehicle Factory
	if name == "coravp" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corvac"   -- Printer - Armored Field Engineer
		buildoptions[numBuildoptions + 2] = "corphantom" -- Phantom - Amphibious Stealth Scout
		buildoptions[numBuildoptions + 3] = "corsiegebreaker" -- Siegebreaker - Heavy Long Range Destroyer
		buildoptions[numBuildoptions + 4] = "corforge" -- Forge - Flamethrower Combat Engineer
		buildoptions[numBuildoptions + 5] = "cortorch" -- Torch - Fast Flamethrower Tank
	end

	-- Cortex T2 Aircraft Plant
	if name == "coraap" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T2 Shipyard
	if name == "corasy" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "coresuppt3" -- Adjudictator - Heavy Heatray Battleship
		buildoptions[numBuildoptions + 2] = "coronager" -- Onager - Coastal Assault Submarine
		buildoptions[numBuildoptions + 3] = "cordesolator" -- Desolator - Nuclear ICBM Submarine
		buildoptions[numBuildoptions + 4] = "corprince" -- Black Prince - Shore bombardment battleship
	end

	-- Cortex T3 Gantry
	if name == "corgant" then
		local numBuildoptions = #buildoptions
	end

	-- Cortex T3 Underwater Gantry
	if name == "corgantuw" then
		local numBuildoptions = #buildoptions
	end

	-- Legion T1 Land Constructors
	if name == "legca" or name == "legck" or name == "legcv" then
		local numBuildoptions = #buildoptions
	end

	-- Legion T2 Land Constructors
	if name == "legaca" or name == "legack" or name == "legacv" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "legwint2" -- T2 Wind Generator
		buildoptions[numBuildoptions + 2] = "legnanotct2" -- T2 Constructor Turret
		buildoptions[numBuildoptions + 3] = "legrwall" -- Dragon's Constitution - T2 (not Pop-up) Wall Turret
		buildoptions[numBuildoptions + 4] = "leggatet3" -- Elysium - Advanced Shield Generator
	end

	-- Legion T2 Sea Constructors
	if name == "leganavyconsub" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "corfgate" -- Atoll - Floating Plasma Deflector
		buildoptions[numBuildoptions + 2] = "legnanotct2plat" -- Floating T2 Constructor Turret
	end

	-- Legion T3 Gantry
	if name == "leggant" then
		local numBuildoptions = #buildoptions
		buildoptions[numBuildoptions + 1] = "legbunk" -- Pilum - Fast Assault Mech
	end
end

return {
	Tweaks = experimentalExtraUnits,
}