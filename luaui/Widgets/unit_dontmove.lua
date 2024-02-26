--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "DontMove",
    desc      = "Sets pre-defined units on hold position.",
    author    = "quantum",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


local unitNames = {

  --comms added below separately

  --aa units
  "armada_crossbow",
  "armada_archangel",
  "cortex_trasher",
  "cortex_manticore",

  "armada_whistler",
  "armada_shredder",
  "cortex_lasher",
  "cortex_fury",

  "armada_sweeper",
  "cortex_birdeater",
  "armada_voyager",
  "cortex_pathfinder",
  "armada_dragonslayer",
  "cortex_arrowstorm",

  --arty
  "armada_shellshocker",
  "armada_mace",
  "cortex_wolverine",

  "armada_mauser",
  "armada_ambassador",
  "cortex_quaker",
  "cortex_negotiator",
  "cortex_tremor",
  "armada_sharpshooter",
  "cortex_arbiter",

  "armada_possum",
  "cortex_mangonel",
  "armada_corsair",
  "cortex_oppressor",
  "armada_serpent",
  "cortex_kraken",

  "armada_longbow",
  "cortex_messenger",
  "armada_dreadnought",
  "cortex_despot",

  "armada_epoch",
  "cortex_blackhydra",

  "cortex_catapult",
  "armada_vanguard",

  --skirmishers/fire support
  "armada_janus",
  "armada_rocketeer",
  "cortex_aggravator",

  "cortex_banisher",
  "armada_starlight",
  "cortex_sheldon",

  --scouts
  "armada_tick",
  "armada_rover",
  "cortex_rascal",
  "armada_ghost",
  "armada_gremlin",

  "armada_skater",
  "cortex_herring",

  --shields/jammers/radars
  "armada_radarjammerbot",
  "armada_umbra",
  "cortex_deceiver",

  "armada_prophet",
  "armada_compass",
  "cortex_omen",
  "cortex_augur",

  --antinukes
  "armada_umbrella",
  "cortex_saviour",
  "armada_haven",
  "cortex_oasis",
  "armada_t2supportship",
  "cortex_t2supportship",

  --misc
}
-- add commanders too
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		unitNames[#unitNames+1] = unitDef.name
	end
end

local unitArray = {}
for _, name in pairs(unitNames) do
	if UnitDefNames[name] then
		unitArray[UnitDefNames[name].id] = true
	end
end
unitNames = nil

local myTeamID = Spring.GetMyTeamID()


function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
	myTeamID = Spring.GetMyTeamID()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		if unitArray[unitDefID] then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
		end
	end
end
