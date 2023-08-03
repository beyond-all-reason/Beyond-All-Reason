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


local unitArray_ = {

  --comms
  "armcom",
  "corcom",

  --aa units
  "armjeth",
  "armaak",
  "corcrash",
  "coraak",
  
  "armsam",
  "armyork",
  "cormist",
  "corsent",
  
  "armah",
  "corah",
  "armmls",
  "cormls",
  "armaas",
  "corarch",
  
  --arty
  "armart",
  "armham",
  "corwolv",
  
  "armmart",
  "armmerl",
  "cormart",
  "corvroc",
  "cortrem",
  "armsnipe",
  "corhrk",
  
  "armmh",
  "cormh",
  "armroy",
  "corroy",
  "armserp",
  "corssub",
  
  "armmship",
  "cormship",
  "armbats",
  "corbats",

  "armepoch",
  "corblackhy",
  
  "corcat",
  "armvang",
  
  --skirmishers/fire support
  "armjanus",
  "armrock",
  "corstorm",

  "corban",
  "armmanni",
  "cormort",
  
  --scouts
  "armflea",
  "armfav",
  "corfav",
  "armspy",
  "armgremlin",
  
  "armpt",
  "corpt",
  
  --shields/jammers/radars
  "armaser",
  "armjam",
  "corspec",
  
  "armseer",
  "armmark",
  "corvrad",
  "corvoyr",
  
  --antinukes
  "armscab",
  "cormabm",
  "armcarry",
  "corcarry",
  "armantiship",
  "corantiship",

  --misc
  
}
local unitArray = {}
for _, name in pairs(unitArray_) do
  if UnitDefNames[name] then
    unitArray[UnitDefNames[name].id] = true
  end
end
unitArray_ = nil

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

function widget:UnitFromFactory(unitID, unitDefID, unitTeam)
  if unitTeam == myTeamID then
    if unitArray[unitDefID] then
      Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
    end 
  end
end
