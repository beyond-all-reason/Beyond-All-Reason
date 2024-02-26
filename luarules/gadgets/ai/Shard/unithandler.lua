UnitHandler = class(Module)

local inactive = {
	armada_solarcollector = true,
	-- armada_rattlesnake = true,
	-- armada_pulsar = true,
	armada_beamer = true,
	-- armada_basilica = true,
	armada_chainsaw = true,
	armada_dragonsclaw = true,
	-- armada_paralyzer = true,
	armada_arbalest = true,
	armada_gauntlet = true,
	armada_overwatch = true,
	armada_sentry = true,
	armada_ferret = true,
	armada_pitbull = true,
	armada_nettle = true,
	-- armada_ragnarok = true,
	armada_advancedsolarcollector = true,
	armada_advancedfusionreactor = true,
	armada_geothermalpowerplant = true,
	armada_advancedgeothermalpowerplant = true,
	armada_geothermalpowerplant = true,
	armada_advancedgeothermalpowerplant = true,
	armada_twilight = true,
	armada_cloakablefusionreactor = true,
	armada_energystorage = true,
	armada_fusionreactor = true,
	armada_prude = true,
	armada_energyconverter = true,
	armada_metalextractor = true,
	armada_advancedenergyconverter = true,
	armada_advancedmetalextractor = true,
	armada_metalstorage = true,
	armada_windturbine = true,
	armada_advancedradartower = true,
	armada_airrepairpad = true,
	armada_decoyfusionreactor = true,
	armada_dragonsteeth = true,
	armada_beholder = true,
	armada_fortificationwall = true,
	armada_keeper = true,
	armada_sneakypete = true,
	armada_lightmine = true,
	armada_mediummine = true,
	armada_heavymine = true,
	armada_radartower = true,
	armada_pinpointer = true,
	armada_veil = true,
	armada_moray = true,
	armada_anemone = true,
	armada_navalarbalest = true,
	armada_manta = true,
	armada_scumbag = true,
	armada_navalnettle = true,
	armada_gunplatform = true,
	armada_harpoon2 = true,
	armada_harpoon = true,
	armada_navalenergyconverter = true,
	armada_tidalgenerator = true,
	armada_hardenedenergystorage = true,
	armada_hardenedmetalstorage = true,
	armada_navalenergystorage = true,
	armada_navalmetalstorage = true,
	armada_navalfusionreactor = true,
	armada_navalmetalextractor = true,
	armada_navaladvancedmetalextractor = true,
	armada_navaladvancedenergyconverter = true,
	armada_advancedsonarstation = true,
	armada_navalpinpointer = true,
	armada_sharksteeth = true,
	armada_aurora = true,
	armada_heavymine = true,
	armada_navalradarsonar = true,
	armada_sonarstation = true,

	-- cortex_cerberus = true,
	-- cortex_calamity = true,
	-- cortex_calamity = true,
	cortex_eradicator = true,
	cortex_exploiter = true,
	corflak = true,
	cortex_twinguard = true,
	cortex_warden = true,
	-- cortex_basilisk = true,
	cortex_guard = true,
	cortex_sam = true,
	cortex_dragonsmaw = true,
	cortex_advancedexploiter = true,
	cortex_agitator = true,
	cortex_thistle = true,
	-- cortex_persecutor = true,
	cortex_scorpion = true,
	cortex_advancedsolarcollector = true,
	cortex_advancedfusionreactor = true,
	cortex_advancedgeothermalpowerplant = true,
	cortex_advancednavalgeothermalpowerplant = true,
	cortex_energystorage = true,
	cortex_fusionreactor = true,
	cortex_geothermalpowerplant = true,
	cortex_navalgeothermalpowerplant = true,
	cortex_energyconverter = true,
	cortex_metalextractor = true,
	cortex_advancedenergyconverter = true,
	cortex_advancedmetalextractor = true,
	cortex_metalstorage = true,
	cortex_solarcollector = true,
	cortex_windturbine = true,
	cortex_advancedradartower = true,
	cortex_airrepairpad = true,
	cortex_dragonsteeth = true,
	cortex_beholder = true,
	cortex_fortificationwall = true,
	cortex_overseer = true,
	cortex_castro = true,
	cortex_lightmine = true,
	cortex_mediummine = true,
	cortex_heavymine = true,
	cortex_mediumminecommando = true,
	cortex_radartower = true,
	cortex_nemesis = true,
	cortex_shroud = true,
	cortex_pinpointer = true,
	cortex_lamprey = true,
	cortex_jellyfish = true,
	cortex_navalbirdshot = true,
	cortex_coral = true,
	cortex_janitor = true,
	cortex_slingshot = true,
	cortex_gunplatform = true,
	cortex_oldurchin = true,
	cortex_urchin = true,
	cortex_navalenergyconverter = true,
	cortex_tidalgenerator = true,
	cortex_hardenedenergystorage = true,
	cortex_hardenedmetalstorage = true,
	cortex_navalenergystorage = true,
	cortex_navalmetalstorage = true,
	cortex_navalfusionreactor = true,
	cortex_navalmetalextractor = true,
	cortex_navaladvancedmetalextractor = true,
	cortex_navaladvancedenergyconverter = true,
	cortex_advancedsonarstation = true,
	cortex_navalpinpointer = true,
	cortex_sharksteeth = true,
	cortex_atoll = true,
	cortex_navalheavymine = true,
	cortex_radarsonartower = true,
	cortex_sonarstation = true
	}

function UnitHandler:Name()
	return "UnitHandler"
end

function UnitHandler:internalName()
	return "unithandler"
end

function UnitHandler:Init()
	self.units = {}
	self.myActiveUnits = {}
	self.myInactiveUnits = {}
	self.reallyActuallyDead = {}
	self.behaviourFactory = BehaviourFactory()
	self.behaviourFactory:SetAI(self.ai)
	self.behaviourFactory:Init()
end

function UnitHandler:Update()
	for k,v in pairs(self.myActiveUnits) do
		if ShardSpringLua then
			local ux, uy, uz = Spring.GetUnitPosition(v:Internal():ID())
			if not ux then
				-- game:SendToConsole(self.ai.id, "nil unit position", v:Internal():ID(), v:Internal():Name(), k)
				self.myActiveUnits[k] = nil
				v = nil
			end
		end
		if v then
			v:Update()
		end
	end
	for uID, frame in pairs(self.reallyActuallyDead) do
		if self.game:Frame() > frame + 1800 then
			self.reallyActuallyDead[uID] = nil
		end
	end
end

function UnitHandler:GameEnd()
	for k,v in pairs(self.myActiveUnits) do
		v:GameEnd()
	end
end

function UnitHandler:UnitCreated(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	for k,v in pairs(self.myActiveUnits) do
		v:UnitCreated(u)
	end
end

function UnitHandler:UnitBuilt(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.myActiveUnits) do
			v:UnitBuilt(u)
		end
	end
end

function UnitHandler:UnitDead(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.myActiveUnits) do
			v:UnitDead(u)
		end
	end
	-- game:SendToConsole(self.ai.id, "removing unit from unithandler tables", engineUnit:ID(), engineUnit:Name())
	self.units[engineUnit:ID()] = nil
	self.myActiveUnits[engineUnit:ID()] = nil
	self.myInactiveUnits[engineUnit:ID()] = nil
	self.reallyActuallyDead[engineUnit:ID()] = self.game:Frame()
end

function UnitHandler:UnitDamaged(engineUnit,engineAttacker,damage)
	local u = self:AIRepresentation(engineUnit)
	-- local a = self:AIRepresentation(engineAttacker)
	for k,v in pairs(self.myActiveUnits) do
		v:UnitDamaged(u,engineAttacker,damage)
	end
end

function UnitHandler:AIRepresentation(engineUnit)
	if engineUnit == nil then
		return nil
	end
	if self.reallyActuallyDead[engineUnit:ID()] then
		-- self.game:SendToConsole(self.ai.id, "unit already died, not representing unit", engineUnit:ID(), engineUnit:Name())
		return nil
	end
	local ux, uy, uz = engineUnit:GetPosition()
	if not ux then
		-- self.game:SendToConsole(self.ai.id, "nil engineUnit position, not representing unit", engineUnit:ID(), engineUnit:Name())
		return nil
	end
	local unittable = self.units
	local u = unittable[engineUnit:ID()]
	if u == nil then
		-- self.game:SendToConsole(self.ai.id, "adding unit to unithandler tables", engineUnit:ID(), engineUnit:Name())
		u = Unit()
		u:SetAI( self.ai )
		self.units[engineUnit:ID()] = u
		u:SetEngineRepresentation(engineUnit)
		u:Init()
		if engineUnit:Team() == self.game:GetTeamID() then
			if inactive[engineUnit:Name()] then
				self.myInactiveUnits[engineUnit:ID()] = u
			else
				-- game:SendToConsole(self.ai.id, "giving my unit behaviours", engineUnit:ID(), engineUnit:Name())
				self.behaviourFactory:AddBehaviours(u)
				self.myActiveUnits[engineUnit:ID()] = u
			end
		end
	end
	return u
end

function UnitHandler:UnitIdle(engineUnit)
	local u = self:AIRepresentation(engineUnit)
	if u ~= nil then
		for k,v in pairs(self.units) do
			v:UnitIdle(u)
		end
	end
end
