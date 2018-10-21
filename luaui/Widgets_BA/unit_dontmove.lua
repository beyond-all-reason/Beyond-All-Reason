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


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local unitSet = {}

local unitArray = {

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
  "armbc",
  "zulu",
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
  
  --misc
  
}

if UnitDefNames.armcom_bar then
  function tableMerge(t1, t2)
    for k,v in pairs(t2) do if type(v) == "table" then if type(t1[k] or false) == "table" then tableMerge(t1[k] or {}, t2[k] or {}) else t1[k] = v end else t1[k] = v end end
    return t1
  end
  local unitArrayBAR = {}
  for _,name in pairs(unitArray) do
    unitArrayBAR[#unitArrayBAR+1] = name
  end
  unitArray = tableMerge(unitArray, unitArrayBAR)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() then
    widgetHandler:RemoveWidget(self)
  end
end

function widget:Initialize()
  if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
    widget:PlayerChanged()
  end
  for i, v in pairs(unitArray) do
    unitSet[v] = true
  end
end


function widget:UnitFromFactory(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  if ((ud ~= nil) and (unitTeam == Spring.GetMyTeamID())) then
    if (unitSet[ud.name]) then
      Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, {})
    end 
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

