ArmyHST = class(Module)

function ArmyHST:Name()
	return "ArmyHST"
end

function ArmyHST:internalName()
	return "armyhst"
end


function ArmyHST:Init()
	self.DebugEnabled = true
	self:setRanks()

end


ArmyHST.techPenalty = {
	armamsub = -1,
	coramsub = -1,
	armfhp = -1,
	corfhp = -1,
	armhp = -1,
	corhp = -1,
}

ArmyHST.factoryMobilities = {
	corap = {"air"},
	armap = {"air"},
	corlab = {"bot"},
	armlab = {"bot"},
	corvp = {"veh", "amp"},
	armvp = {"veh", "amp"},
	coralab = {"bot"},
	coravp = {"veh", "amp"},
	corhp = {"hov"},
	armhp = {"hov"},
	corfhp = {"hov"},
	armfhp = {"hov"},
	armalab = {"bot"},
	armavp = {"veh", "amp"},
	coraap = {"air"},
	armaap = {"air"},
	corplat = {"air"},
	armplat = {"air"},
	corsy = {"shp", "sub"},
	armsy = {"shp", "sub"},
	corasy = {"shp", "sub"},
	armasy = {"shp", "sub"},
	coramsub = {"amp","sub"},
	armamsub = {"amp","sub"},
	corgant = {"bot", "amp"},
	armshltx = {"bot", "amp"},
	corgantuw = {"amp"},
	armshltxuw = {"amp"},
}

-- for calculating what factories to build
-- higher values mean more effecient
ArmyHST.mobilityEffeciencyMultiplier = {
	veh = 1,
	shp = 1,
	bot = 0.9,
	sub = 0.9,
	hov = 0.7,
	amp = 0.4,
	air = 0.55,
}

ArmyHST.factoryExitSides = {
	corap = 0,
	armap = 0,
	corlab = 2,
	armlab = 2,
	corvp = 1,
	armvp = 1,
	coralab = 3,
	coravp = 1,
	corhp = 2,
	armhp = 2,
	corfhp = 2,
	armfhp = 2,
	armalab = 2,
	armavp = 2,
	coraap = 0,
	armaap = 0,
	corplat = 0,
	armplat = 0,
	corsy = 4,
	armsy = 4,
	corasy = 4,
	armasy = 4,
	coramsub = 4,
	armamsub = 4,
	corgant = 1,
	armshltx = 1,
	corgantuw = 1,
	armshltxuw = 1,
}

ArmyHST.littlePlasmaList = {
	corpun = 1,
	armguard = 1,
	cortoast = 1,
	armamb = 1,
	corbhmth = 1,
}

-- these big energy plants will be shielded in addition to factories
ArmyHST.bigEnergyList = {
	corageo = 1,
	armageo = 1,
	corfus = 1,
	armfus = 1,
	corafus = 1,
	armafus = 1,
}

-- geothermal plants
ArmyHST.geothermalPlant = {
	corgeo = 1,
	armgeo = 1,
	corageo = 1,
	armageo = 1,
	corbhmth = 1,
	armgmm = 1,
}

-- what mexes upgrade to what
ArmyHST.mexUpgrade = {
	cormex = "cormoho",
	armmex = "armmoho",
	coruwmex = "coruwmme",--ex coruwmex caution this will be changed --TODO
	armuwmex = "armuwmme",--ex armuwmex
	armamex = "armmoho",
	corexp = "cormexp",

}

-- these will be abandoned faster
ArmyHST.hyperWatchdog = {
	armmex = 1,
	cormex = 1,
	armgeo = 1,
	corgeo = 1,
}

-- things we really need to construct other than factories
-- value is max number of assistants to get if available (0 is all available)
ArmyHST.helpList = {
	corfus = 0,
	armfus = 0,
	coruwfus = 0,
	armuwfus = 0,
	armafus = 0,
	corafus = 0,
	corgeo = 2,
	armgeo = 2,
	corageo = 0,
	armageo = 0,
	cormoho = 2,
	armmoho = 2,
	coruwmme = 2,
	armuwmme = 2,
}

-- priorities of things to defend that can't be accounted for by the formula in turtlehst
ArmyHST.turtleList = {
	cormakr = 0.5,
	armmakr = 0.5,
	corfmkr = 0.5,
	armfmkr = 0.5,
	cormmkr = 4,
	armmmkr = 4,
	corfmmm = 4,
	armfmmm = 4,
	corestor = 0.5,
	armestor = 0.5,
	cormstor = 0.5,
	armmstor = 0.5,
	coruwes = 0.5,
	armuwes = 0.5,
	coruwms = 0.5,
	armuwms = 0.5,
	coruwadves = 2,
	armuwadves = 2,
	coruwadvms = 2,
	armuwadvms = 2,
}

-- factories that can build advanced construction units (i.e. moho mines)
ArmyHST.advFactories = {
	coravp = 1,
	coralab = 1,
	corasy = 1,
	coraap = 1,
	corplat = 1,
	armavp = 1,
	armalab = 1,
	armasy = 1,
	armaap = 1,
	armplat = 1,
}

-- experimental factories
ArmyHST.expFactories = {
	corgant = 1,
	armshltx = 1,
	corgantuw = 1,
	armshltxuw = 1,
}

-- leads to experimental
ArmyHST.leadsToExpFactories = {
	corlab = 1,
	armlab = 1,
	coralab = 1,
	armalab = 1,
	corsy = 1,
	armsy = 1,
	corasy = 1,
	armasy = 1,
}

-- sturdy, cheap units to be built in larger numbers than siege units
ArmyHST.battleList = {
	corraid = 1,
	armstump = 1,
	corthud = 1,
	armham = 1,
	corstorm = 1,
	armrock = 1,
	coresupp = 1,
	armdecade = 1,
	corroy = 1,
	armroy = 1,
	corsnap = 1,
	armanac = 1,
	corseal = 1,
	armcroc = 1,
	correap = 2,
	armbull = 2,
	corcan = 2,
	armzeus = 2,
	corcrus = 2,
	armcrus = 2,
	armmav = 2,
-- 	cordecom = 2,
-- 	armdecom = 2,
	corkarg = 3,
	armraz = 3,

}

-- sturdier units to use when battle units get killed
ArmyHST.breakthroughList = {
	corlevlr = 1,
	armwar = 1,
	corgol = 2,
	corsumo = 2,
	armfboy = 2,
	corparrow = 2,
	corhal = 2,
	corbats = 2,
	armbats = 2,
	corkorg = 3,
	corjugg = 3,
	armbanth = 3,
	corblackhy = 3,
	armepoch = 3,
	corcrw = 3,
	armliche = 3,
}

-- for milling about next to con units and factories only
ArmyHST.defenderList = {
	armaak = 1 ,
	corcrash = 1 ,
	armjeth = 1 ,
	corsent = 1 ,
	armyork = 1 ,
	corah = 1 ,
	armaas = 1 ,
	armah = 1 ,
	corarch = 1 ,
	armaser = 1 ,
	armjam = 1 ,
	armsjam = 1 ,
	coreter = 1 ,
	corsjam = 1 ,
	corspec = 1 ,
	armfig = 1 ,
	armhawk = 1 ,
	armsfig = 1 ,
	corveng = 1 ,
	corvamp = 1 ,
	corsfig = 1 ,
}

ArmyHST.attackerlist = {
	--t1bot
	corstorm = 1 ,
	armrock = 1 ,
	corthud = 1 ,
	armham = 1 ,
	armwar = 1 ,
	--t1veh
	armsam = 1 ,
	corwolv = 1 ,
	armstump = 1 ,
	corraid = 1 ,
	corlevlr = 1 ,

	--t2bot
	--t2veh
	armart = 1 ,
	armjanus = 1 ,




	correap = 1 ,
	armbull = 1 ,

	cormart = 1 ,
	armmart = 1 ,
	cormort = 1 ,

	armsnipe = 1 ,
	armzeus = 1 ,

	corsumo = 1 ,
	corcan = 1 ,
	corhrk = 1 ,
	corgol = 1 ,
	corvroc = 1 ,
	cormh = 1 ,
	armmanni = 1 ,
	armmerl = 1 ,
	armfido = 1 ,
	armsptk = 1 ,
	armmh = 1 ,
	cormist = 1 ,
	armfboy = 1 ,
	corcrw = 1 ,
	-- experimentals
	armraz = 1 ,
	armvang = 1 ,
	armbanth = 1 ,
	corshiva = 1 ,
	corcat = 1 ,
	corkarg = 1 ,
	corjugg = 1 ,
	corkorg = 1 ,
	-- ships
	coresupp = 1 ,
	armdecade = 1 ,
	corroy = 1 ,
	armroy = 1 ,
	corcrus = 1 ,
	armcrus = 1 ,
	corblackhy = 1 ,
	armepoch = 1 ,
	armserp = 1 ,
	corssub = 1 ,
	-- hover
	corsnap = 1 ,
	armanac = 1 ,
	corhal = 1 ,
	-- amphib
	corseal = 1 ,
	armcroc = 1 ,
	corparrow = 1 ,
}

-- these units will be used to raid weakly defended spots
ArmyHST.raiderList = {
	armfast = 1,
	corgator = 1,
	armflash = 1,
	corpyro = 1,
	armlatnk = 1,
	armpw = 1,
	corak = 1,
	armmar = 1,
	-- amphibious
	corgarp = 1,
	armpincer = 1,
	-- hover
	corsh = 1,
	armsh = 1,
	-- air gunships
	armbrawl = 1,
	armkam = 1,
	armsaber = 1,
	armblade = 1,
	corbw = 1,
	corape = 1,
	corcut = 1,
	corcrw = 1,
	-- subs
	corsub = 1,
	armsub = 1,
	armsubk = 1,
	corshark = 1,
}

ArmyHST.scoutList = {
	corfink = 1,
	armpeep = 1,
	corfav = 1,
	armfav = 1,
	armflea = 1,
	corawac = 1,
	armawac = 1,
	corpt = 1,
	armpt = 1,
	corhunt = 1,
	armsehak = 1,
}

ArmyHST.raiderDisarms = {
	corbw = 1,
}

-- units in this list are bombers or torpedo bombers
ArmyHST.bomberList = {
	corshad = 1,
	armthund = 1,
	corhurc = 2,
	armpnix = 2,
	armliche = 3,
	corsb = 2,
	armsb = 2,
	cortitan = 2,
	armlance = 2,
	corseap = 2,
	armseap = 2,
}

ArmyHST.antinukeList = {
	corfmd = 1,
	armamd = 1,
	corcarry = 1,
	armcarry = 1,
	cormabm = 1,
	armscab = 1,
}

ArmyHST.shieldList = {
	corgate = 1,
	armgate = 1,
}

ArmyHST.commanderList = {
	armcom = 1,
	corcom = 1,
}

ArmyHST.nanoTurretList = {
	cornanotc = 1,
	armnanotc = 1,
	armnanotcplat = 1,
	cornanotcplat = 1,
}

-- cheap construction units that can be built in large numbers
ArmyHST.assistList = {
	armfark = 1,
	corfast = 1,
	armconsul = 1,
}

ArmyHST.reclaimerList = {
	cornecro = 1,
	armrectr = 1,
	correcl = 1,
	armrecl = 1,
}

-- advanced construction units
ArmyHST.advConList = {
	corack = 1,
	armack = 1,
	coracv = 1,
	armacv = 1,
	coraca = 1,
	armaca = 1,
	coracsub = 1,
	armacsub = 1,
}

ArmyHST.groundFacList = {
	corvp = 1,
	armvp = 1,
	coravp = 1,
	armavp = 1,
	corlab = 1,
	armlab = 1,
	coralab = 1,
	armalab = 1,
	corhp = 1,
	armhp = 1,
	corfhp = 1,
	armfhp = 1,
	coramsub = 1,
	armamsub = 1,
	corgant = 1,
	armshltx = 1,
	corfast = 1,
	armconsul = 1,
	armfark = 1,
}

-- if any of these is found among enemy units, AA units and fighters will be built
ArmyHST.airFacList = {
	corap = 1,
	armap = 1,
	coraap = 1,
	armaap = 1,
	corplat = 1,
	armplat = 1,
}

-- if any of these is found among enemy units, torpedo launchers and sonar will be built
ArmyHST.subFacList = {
	corsy = 1,
	armsy = 1,
	corasy = 1,
	armasy = 1,
	coramsub = 1,
	armamsub = 1,
}

-- if any of these is found among enemy units, plasma shields will be built
ArmyHST.bigPlasmaList = {
	corint = 1,
	armbrtha = 1,
}

-- if any of these is found among enemy units, antinukes will be built
-- also used to assign nuke behaviour to own units
-- values are how many frames it takes to stockpile
ArmyHST.nukeList = {
	armsilo = 3600,
	corsilo = 5400,
	armemp = 2700,
	cortron = 2250,
}

-- ArmyHST.seaplaneConList = {
-- 	corcsa = 1,
-- 	armcsa = 1,
-- }


ArmyHST.Eco1={
	armsolar=1,
	armwin=1,
	armadvsol=1,
	armtide=1,

	corsolar=1,
	corwin=1,
	coradvsol=1,
	cortide=1,

	corgeo=1,
	armgeo=1,

	--store

	armestor=1,
	armmstor=1,
	armuwes=1,
	armuwms=1,

	corestor=1,
	cormstor=1,
	coruwes=1,
	coruwms=1,

	--conv
	armmakr=1,
	cormakr=1,
	armfmkr=1,
	corfmkr=1,


	--metalli
	corexp=1,
	armamex=1,

	cormex=1,
	armmex=1,

	armuwmex=1,
	coruwmex=1,

	armnanotc=1,
	cornanotc=1,
	armnanotcplat = 1,
	cornanotcplat = 1,
}

ArmyHST.Eco2={
	--metalli
	armmoho=4,
	cormoho=4,
	cormexp=4,

	coruwmme=0,
	armuwmme=0,

	--magazzini
	armuwadves=3,
	armuwadvms=3,

	coruwadves=3,
	coruwadvms=3,

	corageo = 4,
	armageo = 4,
	corbhmth = 4,
	armgmm = 4,

	corfus = 1,
	armfus = 1,
	corafus = 1,
	armafus = 1,
	armuwfus = 0,
	coruwfus = 0,

	--convertitori
	cormmkr=1,
	armmmkr=1,
	corfmmm=0,
	armfmmm=0,
}

ArmyHST.cleaners = {
	armbeaver = 1,
	cormuskrat = 1,
	armcom = 1,
	corcom = 1,
	armdecom = 1,
	cordecom = 1,
}
ArmyHST.decoy ={
	armdecom = 2,
	cordecom = 2,
}
ArmyHST.cleanable = {
	armsolar= 'ground',
	corsolar= 'ground',
	armadvsol = 'ground',
	coradvsol = 'ground',
	armtide = 'floating',
	cortite = 'floating',
	armfmkr = 'floating',
	corfmkr = 'floating',
	cormakr = 'ground',
	armmakr = 'ground',
	corwin = 'ground',
	armwin = 'ground',
}

-- minimum, maximum, starting point units required to attack, bomb
ArmyHST.minAttackCounter = 8
ArmyHST.maxAttackCounter = 30
ArmyHST.baseAttackCounter = 15
ArmyHST.breakthroughAttackCounter = 16 -- build heavier battle units
ArmyHST.siegeAttackCounter = 20 -- build siege units
ArmyHST.minBattleCount = 4 -- how many battle units to build before building any breakthroughs, even if counter is too high
ArmyHST.minBomberCounter = 0
ArmyHST.maxBomberCounter = 16
ArmyHST.baseBomberCounter = 2
ArmyHST.breakthroughBomberCounter = 8 -- build atomic bombers or air fortresses

-- raid counter works backwards: it determines the number of raiders to build
-- if it reaches ArmyHST.minRaidCounter, none are built
ArmyHST.minRaidCounter = 0
ArmyHST.maxRaidCounter = 8
ArmyHST.baseRaidCounter = 5

-- Taskqueuebehaviour was modified to skip this name
ArmyHST.DummyUnitName = "skipthisorder"

-- Taskqueuebehaviour was modified to use this as a generic "build me a factory" order
ArmyHST.FactoryUnitName = "buildfactory"

-- this unit is used to check for underwater metal spots
ArmyHST.UWMetalSpotCheckUnit = "coruwmex"

-- for non-lua only; tests build orders of these units to determine mobility there
-- multiple units for one mtype function as OR
ArmyHST.mobUnitNames = {
	veh = {"corcv", "armllt"},
	bot = {"corck", "armeyes"},
	amp = {"cormuskrat"},
	hov = {"corsh", "armfdrag"},
	shp = {"corcs"},
	sub = {"coracsub"},
}

-- tests move orders of these units to determine mobility there
ArmyHST.mobUnitExampleName = {
	veh = "armcv",
	bot = "armck",
	amp = "armbeaver",
	hov = "armch",
	shp = "armcs",
	sub = "armacsub"
}

-- side names
ArmyHST.CORESideName = "cortex"
ArmyHST.ARMSideName = "armada"

-- how much metal to assume features with these strings in their names have
ArmyHST.baseFeatureMetal = { rock = 30, heap = 80, wreck = 150 }

-- BEGIN CODE BLOCK TO COPY AND PASTE INTO shard_help_unit_feature_table.lua

local hoverplatform = {
	armhp = 1,
	armfhp = 1,
	corhp = 1,
	corfhp = 1,
}

local fighter = {
	armfig = 1,
	corveng = 1,
	armhawk = 1,
	corvamp = 1,
}


local unitsLevels = {}
local armTechLv ={}
local corTechLv ={}
corTechLv.corcom = false
armTechLv.armcom = false
local parent = 0
local continue = false

local featureKeysToGet = { "metal" , "energy", "reclaimable", "blocking", }

local function getDPS(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local dps = 0
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		dps = dps + weaponDef['damages'][0] / weaponDef['reload']
	end
	--Spring.Echo('dps',dps)
	return dps
end



local function getInterceptor(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local interceptor = false
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef['interceptor'] then
			interceptor  =  weaponDef['interceptor'] == 1
		end
	end
	--Spring.Echo('interceptor',interceptor)
	return interceptor
end

local function getParalyzer(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		paralyzer  =  weaponDef['paralyzer']
	end
	--Spring.Echo('paralyzer',paralyzer)
	return paralyzer
end

local function getOnlyTargets(weapons)
	local targets = {}
	for index,weapon in pairs (weapons) do
		if weapon.onlyTargets then
			for name,_ in pairs(weapon.onlyTargets) do
				local  weaponDefID = weapon["weaponDef"]
				local weaponDef = WeaponDefs[weaponDefID]
				targets[name] = weaponDef.range
			end
		end
	end
	return targets
end

local function getBadTargets(weapons)
	local targets = {}
	for index,weapon in pairs (weapons) do
		if weapon.badTargets then
			for name,_ in pairs(weapon.badTargets) do
				local  weaponDefID = weapon["weaponDef"]
				local weaponDef = WeaponDefs[weaponDefID]
				targets[name] = weaponDef.range
				--Spring.Echo('defbadtargets', targets[name])
			end
		end
	end
	--Spring.Echo('badtargets',targets)
	return targets
end
local function GetLongestWeaponRange(unitDefID, GroundAirSubmerged)
	local weaponRange = 0
	local unitDef = UnitDefs[unitDefID]
	local weapons = unitDef["weapons"]
	local dps = 0
	for i=1, #weapons do
		local weaponDefID = weapons[i]["weaponDef"]
		local weaponDef = WeaponDefs[weaponDefID]
		-- Spring.Echo(weaponDefID)
		-- Spring.Echo(weaponDef["canAttackGround"])
		-- Spring.Echo(weaponDef["waterWeapon"])
		--Spring.Echo(weaponDef["range"])
		--Spring.Echo(weaponDef["type"])
		local wType = 0
		if weaponDef["canAttackGround"] == false then
			wType = 1
		elseif weaponDef["waterWeapon"] then
			wType = 2
		else
			wType = 0
		end
		-- Spring.Echo(wType)
		if wType == GroundAirSubmerged then
			if weaponDef["range"] > weaponRange then
				weaponRange = weaponDef["range"]
			end
		end

	end

	return weaponRange
end

local function GetBuiltBy()
	local builtBy = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		if unitDef.buildOptions and #unitDef.buildOptions > 0 then
			for i, buildDefID in pairs(unitDef.buildOptions) do
				local buildDef = UnitDefs[buildDefID]
				builtBy[buildDefID] = builtBy[buildDefID] or {}
				table.insert(builtBy[buildDefID], unitDefID)
			end
		end
	end
	return builtBy
end

local function GetWeaponParams(weaponDefID)
	local WD = WeaponDefs[weaponDefID]
	local WDCP = WD.customParams
	local weaponDamageSingle = tonumber(WDCP.statsdamage) or WD.damages[0] or 0
	local weaponDamageMult = tonumber(WDCP.statsprojectiles) or ((tonumber(WDCP.script_burst) or WD.salvoSize) * WD.projectiles)
	local weaponDamage = weaponDamageSingle * weaponDamageMult
	local weaponRange = WD.range

	local reloadTime = tonumber(WD.customParams.script_reload) or WD.reload

	if WD.dyndamageexp and WD.dyndamageexp > 0 then
		local dynDamageExp = WD.dyndamageexp
		local dynDamageMin = WD.dyndamagemin or 0.0001
		local dynDamageRange = WD.dyndamagerange or weaponRange
		local dynDamageInverted = WD.dyndamageinverted or false
		local dynMod

		if dynDamageInverted then
			dynMod = math.pow(distance3D / dynDamageRange, dynDamageExp)
		else
			dynMod = 1 - math.pow(distance3D / dynDamageRange, dynDamageExp)
		end

		weaponDamage = math.max(weaponDamage * dynMod, dynDamageMin)
	end

	local dps = weaponDamage / reloadTime
	return dps, weaponDamage, reloadTime
end



function ArmyHST:getJammer(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  not spec.buildOptions then
				if spec.jammerRadius and spec.jammerRadius > cost then
					cost = spec.jammerRadius
					target = name
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is jammer of', lab)
		self.ranks[lab][target] = 'jammer'
	end

end

function ArmyHST:getEngineer(units,lab)
	local cost = 0
	local target = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.isBuilder and spec.canAssist and not spec.isWeapon  then
				if spec.buildSpeed > cost then
					target = name
					cost = spec.buildSpeed
				end

			end
		end
	end
	if target then
		self:EchoDebug(target,'is Engineer of', lab)
		self.ranks[lab][target] = 'engineer'
	end
end
function ArmyHST:getWartech(units,lab)
	local cost = 0
	local target = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.buildOptions and spec.isWeapon  then
				self.ranks[lab][name] = 'wartech'
				self:EchoDebug(name,'is fightingBuilders of', lab)
			end
		end
	end
end



function ArmyHST:getCloakabe(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canCloak and spec.isWeapon and not spec.isBuilder then
				self:EchoDebug(name,'is cloakable of', lab)
				self.ranks[lab][name] = 'cloakable'
			end
		end
	end
end

function ArmyHST:getSpy(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canCloak and not spec.isWeapon and spec.isBuilder then
				self:EchoDebug(name,'is spy of', lab)
				self.ranks[lab][name] = 'spy'
			end
		end
	end
end

function ArmyHST:getSpiders(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.mclass == 'tbot3' then
				self:EchoDebug(name,'is spider of', lab)
				self.ranks[lab][name] = 'spider'
			end
		end
	end
end

function ArmyHST:getMiner(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isBuilder and spec.buildOptions and not spec.canAssist then
				self:EchoDebug(name,'is miner of', lab)
				self.ranks[lab][name] = 'miner'
			end
		end
	end
end

function ArmyHST:getBomberAir(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isAirUnit and spec.isBomberAirUnit then
				self:EchoDebug(name,'is BomberAir of', lab)
				self.ranks[lab][name] = 'bomberair'
			end
		end
	end
end

function ArmyHST:getFighterAir(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isAirUnit and spec.isFighterAirUnit then
				self:EchoDebug(name,'is fighterair of', lab)
				self.ranks[lab][name] = 'fighterair'
			end
		end
	end
end

function ArmyHST:getRez(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.canResurrect  then
				self:EchoDebug(name,'is rez of', lab)
				self.ranks[lab][name] = 'rez'
			end
		end
	end
end

function ArmyHST:getAntiNuke(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.antiNuke then
				self:EchoDebug(name,'is antinuke of', lab)
				self.ranks[lab][name] = 'antinuke'
			end
		end
	end
end

function ArmyHST:getFreezer(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.paralyzer and not spec.buildOptions then
				self:EchoDebug(name,'is paralyzer of', lab)
				self.ranks[lab][name] = 'paralyzer'
			end
		end
	end
end

function ArmyHST:getTransport(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isTransport then
				self:EchoDebug(name,'is transport of', lab)
				self.ranks[lab][name] = 'transport'
			end
		end
	end
end


function ArmyHST:getTech(units,lab)
	local cost = 0
	local target = nil
	local ampBuilder = nil
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  spec.isCon and not spec.isWeapon  then
				for i,v in pairs(spec.factoriesCanBuild) do
					if v == lab then
						if spec.mtype == 'amp' then
							ampBuilder = name
						else
							target = name
						end
					end
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is tech of', lab)
		self.ranks[lab][target] = 'tech'
	end
	if ampBuilder then
		self:EchoDebug(ampBuilder,'is amptech of', lab)
		self.ranks[lab][ampBuilder] = 'amptech'
	end

end

function ArmyHST:getRadar(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if  not spec.buildOptions and not spec.isWeapon and spec.radarRadius and not spec.isBuilder then
				if  spec.radarRadius > cost then
					cost = spec.radarRadius
					target = name
				end
			end
		end
	end

	if target then
		self:EchoDebug(target,'is radar of', lab)
		self.ranks[lab][target] = 'radar'
	end
end

function ArmyHST:getCrawlingBomb(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.mclass == 'abotbomb2' then
				target = name
				self.ranks[lab][name] = 'crawrawling'
				self:EchoDebug(target,'is crowling bomb of', lab)
			end
		end
	end

end



function ArmyHST:getRaiders(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.noChaseCat['vtol'] and not spec.buildOptions then
				if (spec.move * spec.dps ) / spec.metalCost > cost then
					cost = (spec.move * spec.dps ) / spec.metalCost
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is raider of', lab)
		self.ranks[lab][target] = 'raider'
	end
end

function ArmyHST:getBattle(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  then
				if  spec.dps   > cost then
					cost =  spec.dps
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is battle of', lab)
		self.ranks[lab][target] = 'battle'
	end
end

function ArmyHST:getBreak(units,lab)
	local cost = 0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and spec.noChaseCat['vtol'] and not spec.buildOptions then
				if  spec.dps   > cost then
					cost =  spec.dps
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is break of', lab)
		self.ranks[lab][target] = 'break'
	end
end

function ArmyHST:getLongRange(units,lab)
	local cost = 0
	local target = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype ~='air' then
				if spec.maxWeaponRange  > cost then
					cost = spec.maxWeaponRange
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is LongRange of', lab)
		self.ranks[lab][target] = 'longrange'
	end
end

function ArmyHST:getArtillery(units,lab)
	local cost = 0
	local target = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype ~='air' then
				if spec.maxWeaponRange / spec.metalCost > cost then
					cost = spec.maxWeaponRange / spec.metalCost
					target = name
				end
			end
		end
	end
	if target then
		self:EchoDebug(target,'is artillery of', lab)
		self.ranks[lab][target] = 'artillery'
	end
end

function ArmyHST:getAmphibious(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon  and spec.noChaseCat['vtol']  and  spec.mtype == 'amp' then
				self:EchoDebug(name,'is amphibious of', lab)
				self.ranks[lab][name] = 'amphibious'
			end
		end
	end
end

function ArmyHST:getSubK(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon    and  spec.mtype == 'sub' and not spec.buildOptions then
				self:EchoDebug(name,'is subKiller of', lab)
				self.ranks[lab][name] = 'subKiller'
			end
		end
	end
end

function ArmyHST:getAttackers(units,lab)
	local cost = 1/0
	local target = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if spec[name].isWeapon and spec[name].noChaseCat['vtol'] then
			target = name
		end
	end
	self:EchoDebug(target,'is attacker of', lab)
end

function ArmyHST:getScouts(units,lab)
	local cost = 1/0
	local target = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.isWeapon and not spec.onlyTargets['vtol'] and not spec.buildOptions and spec.metalCost  < cost then
				cost = spec.metalCost
				target = name
			end
		end
	end

	if target then
		self:EchoDebug(target,'is scout of', lab)
		self.ranks[lab][target] = 'scout'
	end


end

function ArmyHST:getAntiAir(units,lab)
	local range = 0
	local aa = nil
	local spec = self.unitTable
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			if spec[name].noChaseCat['notair'] then
				aa = name
			end
		end
	end
	if not aa then
		for i, name in pairs(units) do
			if not self.ranks[lab][name] then
				if spec[name].onlyTargets and spec[name].onlyTargets['vtol'] then
					if spec[name].onlyTargets['vtol'] > range then
						range = spec[name].onlyTargets['vtol']
						aa = name
					end
				end
			end
		end
	end
	if not aa then
		for i, name in pairs(units) do
			if not self.ranks[lab][name] then
				if spec[name].badTargets and spec[name].badTargets['notair'] then
					if spec[name].badTargets['notair'] > range then
						range = spec[name].badTargets['notair']
						aa = name
					end
				end
			end
		end
	end

	if aa then
		self:EchoDebug(aa,'is AntiAir of', lab)
		self.ranks[lab][aa] = 'antiair'
	end

end

function ArmyHST:getAntiAir2(units,lab)
	local range = 0
	local aa = nil

	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			local spec = self.unitTable[name]
			if spec.noChaseCat['notair'] then
				aa = name
			end
		end
	end
	if aa then
		self:EchoDebug(aa,'is AntiAir2 of', lab)
		self.ranks[lab][aa] = 'antiair2'
	end
end


function ArmyHST:getUnranked(units,lab)
	for i, name in pairs(units) do
		if not self.ranks[lab][name] then
			Spring:Echo(name,'is UNRANKED in', lab)
		end
	end
end

local function scanLabs(units,lab)
	local counter = 0
	local _metal = 0
	local _energy = 0
	local _speed = 0
	local _maxWeaponRange = 0
	local _hp = 0
	local _dps = 0
	local maxM
	local minM
	local scout
	local scoutR
	local attacker
	local attackerR
	local maxMunit
	local minMunit
	--Spring.Echo('LAB:',lab,#units)
	for i, name in pairs(units) do
		local def = UnitDefNames[name]
		if def.maxWeaponRange > 0 and not def.isBuilder and  def.selfDCountdown ~= 0 then
			counter = counter + 1
		end
	end
	for i, name in pairs(units) do
		local def = UnitDefNames[name]
		_metal = _metal + def.metalCost
		_energy = _energy + def.energyCost
		_maxWeaponRange = _maxWeaponRange + def.maxWeaponRange
		_hp = _hp + def.health
		_dps = _dps + ArmyHST.unitTable[name].dps
		--Spring.Echo(name,def.maxWeaponRange)
		if def.maxWeaponRange > 0 and not def.isBuilder and  def.selfDCountdown ~= 0 then

			if not maxM then
				maxM = def.metalCost
				maxMunit = name
			elseif def.metalCost > maxM then
				maxM = def.metalCost
				maxMunit = name
			end
			if not minM then
				minM = def.metalCost
				minMunit = name
			elseif def.metalCost < minM then
				minM = def.metalCost
				minMunit = name
			end
			if not scout then
				scoutR = (def.speed ) / (def.metalCost * def.energyCost)
				scout = name
			elseif  (def.speed ) / (def.metalCost * def.energyCost) > scoutR  then
				scoutR = (def.speed ) / (def.metalCost * def.energyCost)
				scout = name
			end
			if not attacker then
				attackerR =  (ArmyHST.unitTable[name].dps * def.health * (def.speed * def.maxAcc) )
				attacker = name
			elseif   (ArmyHST.unitTable[name].dps * def.health * (def.speed * def.maxAcc) ) > attackerR then
				attackerR =  (ArmyHST.unitTable[name].dps * def.health * (def.speed * def.maxAcc)  )
				attacker = name
			end

		end


	end
-- 	Spring.Echo('maxmname',maxMunit)
-- 	Spring.Echo('minmname',minMunit)
--	Spring.Echo('scout',scout)
	--Spring.Echo(lab,'attacker',attacker,attackerR)
	_metal = _metal / counter
	_energy = _energy / counter
	_maxWeaponRange = _maxWeaponRange / counter
	_hp = _hp / counter
	_dps = _dps /  counter
	for i, name in pairs(units) do
		ArmyHST.unitTable[name].metalRatio = UnitDefNames[name].metalCost / _metal
		ArmyHST.unitTable[name].energyRatio = UnitDefNames[name].energyCost / _energy
		ArmyHST.unitTable[name].maxWeaponRangeRatio =  UnitDefNames[name].maxWeaponRange / _maxWeaponRange
		ArmyHST.unitTable[name].healthR =  UnitDefNames[name].health / _hp
		ArmyHST.unitTable[name].dpsR =  ArmyHST.unitTable[name].dps / _dps
-- 		if ArmyHST.unitTable[name].maxWeaponRangeRatio > 0.75 and ArmyHST.unitTable[name].maxWeaponRangeRatio < 1.25 then
-- 			Spring.Echo(lab,name,'TRUE')
-- 		else
-- 			Spring.Echo(lab,name,ArmyHST.unitTable[name].maxWeaponRangeRatio)
-- 		end
-- 		if ArmyHST.unitTable[name].healthR > 0.75 and ArmyHST.unitTable[name].healthR < 1.25 then
-- 			Spring.Echo(lab,name,'TRUE')
-- 		else
-- 			Spring.Echo(lab,name,ArmyHST.unitTable[name].healthR)
-- 		end
	--Spring.Echo(lab,name ,ArmyHST.unitTable[name].dpsR)
	end

end



local function GetUnitSide(name)--TODO change to the internal name armada cortex
	if string.find(name, 'arm') then
		return 'arm'
	elseif string.find(name, 'cor') then
		return 'core'
	elseif string.find(name, 'chicken') then
		return 'chicken'
	end
	return 'unknown'
end

local function getTechTree(sideTechLv)
	continue = false
	local tmp = {}
	for name,lv in pairs(sideTechLv) do
		if lv == false then
			sideTechLv[name] = parent
			if ArmyHST.techPenalty[name] then sideTechLv[name] = sideTechLv[name] + ArmyHST.techPenalty[name] end--here cause some not corresponding at true and seaplane maybe
			canBuild = UnitDefNames[name].buildOptions
			if canBuild and #canBuild > 0 then
				for index,id in pairs(UnitDefNames[name].buildOptions) do
					if not sideTechLv[UnitDefs[id].name] then
						tmp[UnitDefs[id].name] = false
						continue = true
					end
				end
			end
		end
	end
	for name,lv in pairs(tmp) do
		sideTechLv[name] = lv
	end
	if continue  then
		parent = parent + 1
		getTechTree(sideTechLv)
	end
	parent = 0
end
local function GetUnitTable()
	local builtBy = GetBuiltBy()
	local unitTable = {}
	local wrecks = {}
	for unitDefID,unitDef in pairs(UnitDefs) do
		local side = GetUnitSide(unitDef.name)
		if unitsLevels[unitDef.name] then
			-- Spring.Echo(unitDef.name, "build slope", unitDef.maxHeightDif)
			-- if unitDef.moveDef.maxSlope then
			-- Spring.Echo(unitDef.name, "move slope", unitDef.moveDef.maxSlope)
			-- end
			local utable = {}
			utable.side = side
-- 			Spring:Echo(unitDef.name)
			utable.techLevel = unitsLevels[unitDef["name"]]
			if unitDef["modCategories"]["weapon"] then
				utable.isWeapon = true

				if unitDef["weapons"][1] then
					local defWepon1 = unitDef["weapons"][1]
					utable.onlyTargets = getOnlyTargets(unitDef["weapons"])
					utable.badTargets = getBadTargets(unitDef["weapons"])
					utable.firstWeapon = WeaponDefs[unitDef["weapons"][1]["weaponDef"]]
					utable.weaponType = utable.firstWeapon['type']
					utable.badTg = ''
					if defWepon1.badTargets then
						for ii,vv in pairs(defWepon1.badTargets) do
							--Spring:Echo(ii)
							utable.badTg = utable.badTg .. ii

						end
					end
					utable.onlyTg = ''
					if defWepon1.onlyTargets then
						for ii,vv in pairs(defWepon1.onlyTargets) do
							utable.onlyTg = utable.onlyTg .. ii
						end
					end
					utable.onlyBadTg = utable.onlyTg .. utable.badTg
				end
			else
				utable.isWeapon = false
			end

			if unitDef["isBuilding"] then
				utable.isBuilding = true
			else
				utable.isBuilding = false
			end
			utable.groundRange = GetLongestWeaponRange(unitDefID, 0)
			utable.airRange = GetLongestWeaponRange(unitDefID, 1)
			utable.submergedRange = GetLongestWeaponRange(unitDefID, 2)
			utable.dps = getDPS(unitDefID)
			utable.antiNuke = getInterceptor(unitDefID)
			utable.paralyzer = getParalyzer(unitDefID)
			Spring:Echo(unitDef.name,utable.antiNuke)
			if unitDef.speed == 0 and utable.isWeapon then
				utable.isTurret = true
				if unitDef.modCategories.mine then
					utable.isMine = utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == ('StarburstLauncher' or 'MissileLauncher') then
					utable.isTacticalTurret =  utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'Cannon' then
					utable.isCannonTurret = utable.techLevel
					if not utable.firstWeapon.selfExplode then
						utable.isPlasmaCannon = utable.techLevel
					end
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'BeamLaser' then
					utable.isLaserTurret = utable.techLevel
				elseif utable.firstWeapon and utable.firstWeapon['type'] == 'TorpedoLauncher' then
					utable.isTorpedoTurret = utable.techLevel
				end
				if utable.groundRange and utable.groundRange > 0 then
					utable.isGroundTurret = utable.groundRange
				end
				if utable.airRange and utable.airRange > 0 then
					utable.isAirTurret = utable.airRange
				end
				if utable.submergedRange and utable.submergedRange > 0 then
					utable.isSubTurret = utable.submergedRange
				end
			end
			if fighter[unitDef["name"]] then
				utable.airRange = utable.groundRange
			end
			utable.radarRadius = unitDef["radarRadius"]
			utable.airLosRadius = unitDef["airLosRadius"]
			utable.losRadius = unitDef["losRadius"]
			utable.sonarRadius = unitDef["sonarRadius"]
			utable.jammerRadius = unitDef["jammerRadius"]
			utable.stealth = unitDef["stealth"]
			utable.metalCost = unitDef["metalCost"]
			utable.energyCost = unitDef["energyCost"]
			utable.buildTime = unitDef["buildTime"]
			utable.totalEnergyOut = unitDef["totalEnergyOut"]
			utable.extractsMetal = unitDef["extractsMetal"]
			utable.isTransport = unitDef.isTransport
			utable.isImmobile = unitDef.isImmobile
			utable.isBuilding = unitDef.isBuild
			utable.isBuilder = unitDef.isBuilder
			utable.isMobileBuilder = unitDef.isMobileBuilder
			utable.isStaticBuilder = unitDef.isStaticBuilder
			utable.isFactory = unitDef.isLab
			utable.isExtractor = unitDef.Extractor
			utable.isGroundUnit = unitDef.isGroundUnit
			utable.isAirUnit = unitDef.isAirUnit
			utable.isStrafingAirUnit = unitDef.isStrafingAirUnit
			utable.isHoveringAirUnit = unitDef.isHoveringAirUnit
			utable.isFighterAirUnit = unitDef.isFighterAirUnit
			utable.isBomberAirUnit = unitDef.isBomberAirUnit
			utable.noChaseCat = unitDef.noChaseCategories
			utable.maxWeaponRange = unitDef.maxWeaponRange
			utable.mclass = unitDef.moveDef.name
			utable.speed = unitDef.speed
			utable.accel = unitDef.maxAcc
			utable.move = unitDef.speed * unitDef.maxAcc * unitDef.turnRate * unitDef.maxDec
			utable.hp = unitDef.health
			utable.buildSpeed = unitDef.buildSpeed
			utable.canAssist = unitDef.canAssist
			utable.canCloak = unitDef.canCloak
			utable.canResurrect = unitDef.canResurrect
			if unitDef["minWaterDepth"] > 0 then
				utable.needsWater = true
			else
				utable.needsWater = false
			end
			if unitDef["canFly"] then
				utable.mtype = "air"
			elseif	utable.isBuilding and utable.needsWater then
				utable.mtype = 'sub'
			elseif	utable.isBuilding and not utable.needsWater then
				utable.mtype = 'veh'
			elseif  unitDef.moveDef.name and (string.find(unitDef.moveDef.name, 'abot') or string.find(unitDef.moveDef.name, 'vbot')  or string.find(unitDef.moveDef.name,'atank'))  then
				utable.mtype = 'amp'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'uboat') then
				utable.mtype = 'sub'
			elseif unitDef.moveDef.name and  string.find(unitDef.moveDef.name, 'hover') then
				utable.mtype = 'hov'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'boat') then
				utable.mtype = 'shp'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'tank') then
				utable.mtype = 'veh'
			elseif unitDef.moveDef.name and string.find(unitDef.moveDef.name, 'bot') then
				utable.mtype = 'bot'
			else
				if unitDef.maxwaterdepth and unitDef.maxwaterdepth < 0 then
					utable.mtype = 'shp'
				else
					utable.mtype = 'veh'
				end
			end

			if unitDef["isBuilder"] and #unitDef["buildOptions"] < 1 and not unitDef.moveDef.name then
				utable.isNano = true
			end

			if unitDef["isBuilder"] and #unitDef["buildOptions"] > 0 then
				utable.buildOptions = true
				if unitDef["isBuilding"] then
					utable['isFactory'] = {}
					utable.unitsCanBuild = {}
					for i, oid in pairs (unitDef["buildOptions"]) do
						local buildDef = UnitDefs[oid]
						-- if is a factory insert all the units that can build
						table.insert(utable.unitsCanBuild, buildDef["name"])
						--and save all the mtype that can andle
						--utable.isFactory[unitName[buildDef.name].mtype] = TODO
					end

				else
					utable.factoriesCanBuild = {}
					for i, oid in pairs (unitDef["buildOptions"]) do
						local buildDef = UnitDefs[oid]
						if #buildDef["buildOptions"] > 0 and buildDef["isBuilding"] then
							-- build option is a factory, add it to factories this unit can build
							table.insert(utable.factoriesCanBuild, buildDef["name"])
						end
					end
					if #utable.factoriesCanBuild > 0 then
						utable.isCon = true
					else
						utable.isEngineer = true
					end



				end
			end
			utable.bigExplosion = unitDef["deathExplosion"] == "atomic_blast"
			utable.xsize = unitDef["xsize"]
			utable.zsize = unitDef["zsize"]
			utable.wreckName = unitDef["wreckName"]
			wrecks[unitDef["wreckName"]] = unitDef["name"]
			unitTable[unitDef.name] = utable
		end
	end
	return unitTable, wrecks
end

local function GetFeatureTable(wrecks)
	local featureTable = {}
	-- feature defs
	for featureDefID, featureDef in pairs(FeatureDefs) do
		local ftable = {}
		for i, k in pairs(featureKeysToGet) do
			local v = featureDef[k]
			ftable[k] = v
		end
		if wrecks[featureDef["name"]] then
			ftable.unitName = wrecks[featureDef["name"]]
		end
		featureTable[featureDef.name] = ftable
	end
	return featureTable
end

getTechTree(armTechLv)
getTechTree(corTechLv)
for k,v in pairs(corTechLv) do unitsLevels[k] = v end
for k,v in pairs(armTechLv) do unitsLevels[k] = v end
ArmyHST.unitTable, ArmyHST.wrecks = GetUnitTable()
ArmyHST.featureTable = GetFeatureTable(ArmyHST.wrecks)

function ArmyHST:setRanks()
	self.ranks = {}
	for lab,t in pairs (self.unitTable) do
		if t.isFactory then
			self.ranks[lab] = {}
			--scanLabs(t.unitsCanBuild,lab)

			self:getSpy(t.unitsCanBuild,lab)
			self:getSpiders(t.unitsCanBuild,lab)
			self:getFreezer(t.unitsCanBuild,lab)
			self:getBomberAir(t.unitsCanBuild,lab)
			self:getFighterAir(t.unitsCanBuild,lab)
			self:getAntiNuke(t.unitsCanBuild,lab)
			self:getCrawlingBomb(t.unitsCanBuild,lab)
			self:getTransport(t.unitsCanBuild,lab)
			self:getCloakabe(t.unitsCanBuild,lab)
			self:getJammer(t.unitsCanBuild,lab)
			self:getRadar(t.unitsCanBuild,lab)
			self:getScouts(t.unitsCanBuild,lab)
			self:getAntiAir(t.unitsCanBuild,lab)
			self:getTech(t.unitsCanBuild,lab)
			self:getRez(t.unitsCanBuild,lab)
			self:getMiner(t.unitsCanBuild,lab)
			self:getWartech(t.unitsCanBuild,lab)
			self:getEngineer(t.unitsCanBuild,lab)


	-- self:getRaiders(t.unitsCanBuild,lab)


			self:getSubK(t.unitsCanBuild,lab)
			self:getArtillery(t.unitsCanBuild,lab)

			self:getAmphibious(t.unitsCanBuild,lab)
			self:getAntiAir(t.unitsCanBuild,lab)
			self:getRaiders(t.unitsCanBuild,lab)
			self:getBattle(t.unitsCanBuild,lab)
			self:getBreak(t.unitsCanBuild,lab)
			self:getLongRange(t.unitsCanBuild,lab)




			self:getUnranked(t.unitsCanBuild,lab)


		end
	end
end
wrecks = nil



--[[
    [f=-000001] repairSpeed, 300
   [f=-000001] highTrajectoryType, 0
   [f=-000001] captureSpeed, 1800
   [f=-000001] isMobileBuilder, true
   [f=-000001] maxThisUnit, 32000
   [f=-000001] trackWidth, 32
   [f=-000001] buildingDecalType, -1
   [f=-000001] startCloaked, false
   [f=-000001] canRestore, true
   [f=-000001] transportMass, 100000
   [f=-000001] losHeight, 60
   [f=-000001] leaveTracks, false
   [f=-000001] canLoopbackAttack, false
   [f=-000001] wingAngle, 0.08
   [f=-000001] isBomberAirUnit, false
   [f=-000001] id, 583
   [f=-000001] idleTime, 1800
   [f=-000001] isHoveringAirUnit, false
   [f=-000001] isBuilding, false
   [f=-000001] decloakDistance, 50
   [f=-000001] canFight, true
   [f=-000001] flankingBonusDirZ, 1
   [f=-000001] frontToSpeed, 0.1
   [f=-000001] turnRadius, 500
   [f=-000001] hideDamage, true
   [f=-000001] sonarStealth, false
   [f=-000001] shieldWeaponDef, nil
   [f=-000001] cantBeTransported, false
   [f=-000001] decoyDef, nil
   [f=-000001] kamikazeDist, 0
   [f=-000001] useBuildingGroundDecal, false
   [f=-000001] buildingDecalDecaySpeed, 0.1
   [f=-000001] nanoColorG, 0.69999999
   [f=-000001] scriptName, scripts/Units/CORCOM.cob
   [f=-000001] stealth, false
   [f=-000001] canResurrect, false
   [f=-000001] transportUnloadMethod, 0
   [f=-000001] minWaterDepth, -10000000
   [f=-000001] modeltype, s3o
   [f=-000001] name, corcom
   [f=-000001] canSelfRepair, false
   [f=-000001] canReclaim, true
   [f=-000001] springCategories, <table>
   [f=-000001] maxRudder, 0.004
   [f=-000001] waterline, 0
   [f=-000001] releaseHeld, false
   [f=-000001] canAttack, true
   [f=-000001] energyMake, 25
   [f=-000001] speedToFront, 0.07
   [f=-000001] transportByEnemy, false
   [f=-000001] noChaseCategories, <table>
   [f=-000001] wingDrag, 0.07
   [f=-000001] flareDropVectorY, 0
   [f=-000001] tidalGenerator, 0
   [f=-000001] isFeature, false
   [f=-000001] isTransport, false
   [f=-000001] buildingDecalSizeX, 4
   [f=-000001] modelpath, objects3d/Units/CORCOM.s3o
   [f=-000001] losRadius, 450
   [f=-000001] windGenerator, 0
   [f=-000001] sonarJamRadius, 0
   [f=-000001] fallSpeed, 0.2
   [f=-000001] verticalSpeed, 3
   [f=-000001] metalStorage, 0
   [f=-000001] crashDrag, 0.005
   [f=-000001] kamikazeUseLOS, false
   [f=-000001] buildingDecalSizeY, 4
   [f=-000001] flankingBonusDirX, 0
   [f=-000001] energyStorage, 0
   [f=-000001] trackStrength, 0
   [f=-000001] fireState, -1
   [f=-000001] isAirUnit, false
   [f=-000001] humanName, Commander
   [f=-000001] autoHeal, 2.5
   [f=-000001] fullHealthFactory, false
   [f=-000001] buildOptions, <table>
   [f=-000001] canCapture, true
   [f=-000001] dlHoverFactor, -1
   [f=-000001] isFactory, false
   [f=-000001] sounds, <table>
   [f=-000001] flankingBonusMode, 1
   [f=-000001] flankingBonusDirY, 0
   [f=-000001] airLosRadius, 675
   [f=-000001] targfac, false
   [f=-000001] canRepeat, true
   [f=-000001] canRepair, true
   [f=-000001] maxDec, 1.125
   [f=-000001] resurrectSpeed, 300
   [f=-000001] flareDropVectorX, 0
   [f=-000001] turnRate, 1133
   [f=-000001] extractsMetal, 0
   [f=-000001] terraformSpeed, 1500
   [f=-000001] buildpicname, CORCOM.PNG
   [f=-000001] isStrafingAirUnit, false
   [f=-000001] flankingBonusMax, 1.89999998
   [f=-000001] floatOnWater, false
   [f=-000001] flareSalvoDelay, 0
   [f=-000001] rSpeed, 0
   [f=-000001] turnInPlace, true
   [f=-000001] buildTime, 75000
   [f=-000001] canFly, false
   [f=-000001] canAssist, true
   [f=-000001] maxAcc, 0.18000001
   [f=-000001] transportSize, 0
   [f=-000001] decloakOnFire, true
   [f=-000001] wreckName, corcom_dead
   [f=-000001] flareEfficiency, 0.5
   [f=-000001] maxRepairSpeed, 300
   [f=-000001] moveDef, <table>
   [f=-000001] flareDelay, 0.30000001
   [f=-000001] canSubmerge, false
   [f=-000001] canMove, true
   [f=-000001] reclaimable, false
   [f=-000001] holdSteady, false
   [f=-000001] energyUpkeep, 0
   [f=-000001] radarRadius, 700
   [f=-000001] needGeo, false
   [f=-000001] flareReloadTime, 5
   [f=-000001] speed, 37.5
   [f=-000001] strafeToAttack, false
   [f=-000001] showNanoSpray, true
   [f=-000001] maxWeaponRange, 300
   [f=-000001] nanoColorB, 0.2
   [f=-000001] buildSpeed, 300
   [f=-000001] flareSalvoSize, 4
   [f=-000001] canKamikaze, false
   [f=-000001] deathExplosion, commanderexplosion
   [f=-000001] isBuilder, true
   [f=-000001] extractRange, 0
   [f=-000001] upright, true
   [f=-000001] canFireControl, true
   [f=-000001] levelGround, true
   [f=-000001] scriptPath, scripts/Units/CORCOM.cob
   [f=-000001] flareDropVectorZ, 0
   [f=-000001] hoverAttack, false
   [f=-000001] xsize, 4
   [f=-000001] maxCoverage, 0
   [f=-000001] isExtractor, false
   [f=-000001] transportCapacity, 0
   [f=-000001] repairable, true
   [f=-000001] bankingAllowed, true
   [f=-000001] maxBank, 0.80000001
   [f=-000001] canBeAssisted, true
   [f=-000001] isFighterAirUnit, false
   [f=-000001] tooltip, Commander
   [f=-000001] mass, 5000
   [f=-000001] trackStretch, 1
   [f=-000001] flankingBonusMobilityAdd, 0.01
   [f=-000001] trackType, -1
   [f=-000001] trackOffset, 0
   [f=-000001] activateWhenBuilt, true
   [f=-000001] canGuard, true
   [f=-000001] buildRange3D, false
   [f=-000001] selfDCountdown, 5
   [f=-000001] maxElevator, 0.01
   [f=-000001] moveState, -1
   [f=-000001] isFirePlatform, false
   [f=-000001] unitFallSpeed, 0
   [f=-000001] sonarRadius, 450
   [f=-000001] cloakCost, 100
   [f=-000001] makesMetal, 0
   [f=-000001] maxPitch, 0.44999999
   [f=-000001] customParams, <table>
   [f=-000001] iconType, nil
   [f=-000001] height, 52
   [f=-000001] airStrafe, true
   [f=-000001] collide, true
   [f=-000001] weapons, <table>
   [f=-000001] modelname, Units/CORCOM.s3o
   [f=-000001] selectionVolume, <table>
   [f=-000001] energyCost, 26000
   [f=-000001] seismicRadius, 0
   [f=-000001] zsize, 4
   [f=-000001] metalUpkeep, 0
   [f=-000001] nanoColorR, 0.2
   [f=-000001] slideTolerance, 0
   [f=-000001] maxHeightDif, 23.0940132
   [f=-000001] stopToAttack, false
   [f=-000001] modCategories, <table>
   [f=-000001] cobID, -1
   [f=-000001] useSmoothMesh, true
   [f=-000001] cloakCostMoving, 1000
   [f=-000001] isGroundUnit, true
   [f=-000001] metalCost, 2700
   [f=-000001] onOffable, false
   [f=-000001] flareTime, 90
   [f=-000001] buildDistance, 145
   [f=-000001] collisionVolume, <table>
   [f=-000001] turnInPlaceSpeedLimit, 0.82499999
   [f=-000001] totalEnergyOut, 25
   [f=-000001] isStaticBuilder, false
   [f=-000001] idleAutoHeal, 2.5
   [f=-000001] armoredMultiple, 1
   [f=-000001] reclaimSpeed, 300
   [f=-000001] myGravity, 0.40000001
   [f=-000001] maxAileron, 0.015
   [f=-000001] seismicSignature, 0
   [f=-000001] maxWaterDepth, 35
   [f=-000001] metalMake, 1.5
   [f=-000001] canDropFlare, false
   [f=-000001] stockpileWeaponDef, nil
   [f=-000001] isImmobile, false
   [f=-000001] model, <table>
   [f=-000001] jammerRadius, 0
   [f=-000001] canCloak, true
   [f=-000001] power, 3133.33325
   [f=-000001] canManualFire, true
   [f=-000001] health, 3000
   [f=-000001] minCollisionSpeed, 1
   [f=-000001] radius, 33
   [f=-000001] capturable, true
   [f=-000001] factoryHeadingTakeoff, true
   [f=-000001] armorType, 3
   [f=-000001] decloakSpherical, true
   [f=-000001] canPatrol, true
   [f=-000001] canSelfD, true
   [f=-000001] showPlayerName, true
   [f=-000001] showNanoFrame, true
   [f=-000001] loadingRadius, 220
   [f=-000001] wantedHeight, 0
   [f=-000001] flankingBonusMin, 0.89999998
   [f=-000001] selfDExplosion, commanderexplosion
   [f=-000001] canParalyze, false
   [f=-000001] power_xp_coeffient, 0.13263173
   [f=-000001] pairs, <function>
   [f=-000001] next, <function>
   [f=-000001] canStockpile, false
   [f=-000001] hasShield, false
   [f=-000001] canAttackWater, true
   [f=-000001] cost, 3133.33325

]]



