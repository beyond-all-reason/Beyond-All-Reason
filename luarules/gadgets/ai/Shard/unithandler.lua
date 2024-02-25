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
	armasp = true,
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
	armada_navalradar = true,
	armada_sonarstation = true,

	-- corbhmth = true,
	-- corbuzz = true,
	-- cordoom = true,
	corerad = true,
	corexp = true,
	corflak = true,
	corhllt = true,
	corhlt = true,
	-- corint = true,
	corllt = true,
	cormadsam = true,
	cormaw = true,
	cormexp = true,
	corpun = true,
	corrl = true,
	-- cortoast = true,
	corvipe = true,
	coradvsol = true,
	corafus = true,
	corageo = true,
	coruwageo = true,
	corestor = true,
	corfus = true,
	corgeo = true,
	coruwgeo = true,
	cormakr = true,
	cormex = true,
	cormmkr = true,
	cormoho = true,
	cormstor = true,
	corsolar = true,
	corwin = true,
	corarad = true,
	corasp = true,
	cordrag = true,
	coreyes = true,
	corfort = true,
	corgate = true,
	corjamt = true,
	cormine1 = true,
	cormine2 = true,
	cormine3 = true,
	cormine4 = true,
	corrad = true,
	corsd = true,
	corshroud = true,
	cortarg = true,
	coratl = true,
	cordl = true,
	corenaa = true,
	corfhlt = true,
	corfrock = true,
	corfrt = true,
	corgplat = true,
	corptl = true,
	cortl = true,
	corfmkr = true,
	cortide = true,
	coruwadves = true,
	coruwadvms = true,
	coruwes = true,
	coruwms = true,
	coruwfus = true,
	coruwmex = true,
	coruwmme = true,
	coruwmmm = true,
	corason = true,
	corfatf = true,
	corfdrag = true,
	corfgate = true,
	corfmine3 = true,
	corfrad = true,
	corsonar = true
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
