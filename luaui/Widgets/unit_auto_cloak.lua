function widget:GetInfo()
    return {
        name      = "Auto Cloak Units",
        desc      = "Auto cloaks Units with Cloak",
        author    = "wilkubyk",
        date      = "2022.12.29",
        license   = "GNU GPL, v2 or later",
        layer     = math.huge,
        enabled   = true  -- loaded by default
    }
end

local cloaking_Unit_Default = {
	[UnitDefNames["armjamt"].id]=true,
	[UnitDefNames["armckfus"].id]=true,
	[UnitDefNames["armdecom"].id]=true,
    [UnitDefNames["cordecom"].id]=true,
    [UnitDefNames["armamex"].id]=true,
    [UnitDefNames["armferret"].id]=true,
    [UnitDefNames["armamb"].id]=true,
    [UnitDefNames["armpb"].id]=true,
    [UnitDefNames["armsnipe"].id]=true,
    [UnitDefNames["corsktl"].id]=true,
    [UnitDefNames["armspy"].id]=true,
    [UnitDefNames["corspy"].id]=true,
    [UnitDefNames["armgremlin"].id]=true,
}

--[[local wanted_cloak_values = {
    [UnitDefNames.armjamt.id]= true,
    [UnitDefNames.armckfus.id]= true,
    [UnitDefNames.armdecom.id] = true,
    [UnitDefNames.cordecom.id] = true,
    [UnitDefNames.armamex.id] = true,
    [UnitDefNames.armferret.id] = true,
    [UnitDefNames.armamb.id] = true,
    [UnitDefNames.armpb.id] = true,
    [UnitDefNames.armsnipe.id] = true,
    [UnitDefNames.corsktl.id] = true,
    [UnitDefNames.armspy.id] = true,
    [UnitDefNames.corspy.id] = true,
    [UnitDefNames.armgremlin.id] = true,
}]]--

--[[
- Sneaky pete | default on armjamt
- Cloakable fussion | default on armckfus
- Decoy coms | default off armdecom / cordecom
- Twilight | default on armamex
- Pack0 | default off armferret
- Rattlesnake | default off armamb
- PitBull | default off armpb
- Snipers | default off armsnipe
- Skuttle | default off corsktl
- Spies | default on armspy / corspy
- Gremlin | default off armgremlin
]]--
local CMD_CLOAK = 37382
local cloak = CMD_CLOAK
local cloakunits = {}
local gameStarted
local giveOrderToUnit = Spring.GiveOrderToUnit
local default = false
local cloakOn = true
local spEcho = Spring.Echo
local spUnitTeam = Spring.GetMyTeamID

--[[local function cloakOnAndOff(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] and default == true and cloakOn == false then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0)
    end
    if cloaking_Unit_Default[unitDefID] and default == true and cloakOn == true then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end
end]]--
local function cloakDeActive(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] then--and default == true and cloakOn == false then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0)
    end
end
local function cloakActive(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] then--and default == true and cloakOn == true then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end
end
local function unitIDs(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] then
        cloakunits[unitID] = true
    end
end
local function NewUnit(unitID, unitDefID, unitTeam)
    if unitTeam ~= spUnitTeam then
        return
        unitIDs()
    end
    
end
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  --  NewUnit(unitID, unitDefID, unitTeam)
  if default == true and cloakOn ==false then
    cloakActive(unitID, unitDefID)
  else
    cloakDeActive(unitID, unitDefID)
  end
    --if cloaking_Unit_Default[unitDefID] and default == true then
      --  cloakunits[unitID] = true
       -- giveOrderToUnit(unitID, cloak, {0}, 0) --changing default cloak to Off
   -- elseif default == true and cloaking_Unit_Default[UnitDefNames]==true then
   --     giveOrderToUnit(unitID, cloak, {1}, 0)
    --end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if cloakunits[unitID] then
        cloakunits[unitID] = nil
    end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
 --   NewUnit(unitID, unitDefID, unitTeam)
    cloakDeActive(unitID, unitDefID)
   --[[ if cloaking_Unit_Default[unitDefID] and default == true then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0) --changing default cloak to Off
    end]]--
   --[[ if cloaking_Unit_Default[unitDefID] and WG['init_cloak'] and not default then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end]]--
end

--[[function widget:UnitTaken(unitID, unitDefID, unitTeam)
    if cloaking_Unit_Default[unitDefID] and default == true then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0) --changing default cloak to Off
    end]]--
   --[[ if cloaking_Unit_Default[unitDefID] and WG['init_cloak'] and not default then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end]]--
--end

--[[function widget:UnitGiven(unitID, unitDefID, unitTeam)
    if cloaking_Unit_Default[unitDefID] and default == true then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0) --changing default cloak to Off
    end]]--
   --[[ if cloaking_Unit_Default[unitDefID] and WG['init_cloak'] and not default then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end]]--
--end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

--[[local function toggleDefault(unitID, Default)
    if Default then
        cloaking_Unit_Default(unitID)
    end

end]]--

function widget:Initialize()
    spEcho("[Auto Cloak Units] Initializing plugin")  -- DEBUG
    WG['default_cloak']= {}
    WG['default_cloak'].get_Default     = function() return default end
    WG['default_cloak'].set_Default     = function(value)
        spEcho("[Auto Cloak Units] Toggling Default from "..tostring(default).." to "..tostring(value))  -- DEBUG
        default = value
        cloakDeActive()
    --    toggleDefault()
    end
    WG['init_cloak'] = {}
    WG['init_cloak'].get_ArmJamt = function() return cloaking_Unit_Default[UnitDefNames["armjamt"].id] end
    WG['init_cloak'].set_ArmJamt = function(value)
        spEcho("[Auto Cloak Units] Toggling Sneaky Pete from "..tostring(cloaking_Unit_Default[UnitDefNames["armjamt"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armjamt"].id] = value
        cloakActive()
    end
   -- WG['init_cloak'].get_ArmCkFus     = function() return wanted_cloak_values[UnitDefNames.armckfus.id] end
   -- WG['init_cloak'].set_ArmCkFus     = function(value) wanted_cloak_values[UnitDefNames.armckfus.id] = value end
   -- WG['init_cloak'].get_ArmDeCom = function() return wanted_cloak_values[UnitDefNames.armdecom.id] end
   -- WG['init_cloak'].set_ArmDeCom = function(value) wanted_cloak_values[UnitDefNames.armdecom.id] = value end

    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:GetConfigData()
    spEcho("[Auto Cloak Units] widget:GetConfigData (default: "..tostring(default).."".."******".."armjamt: "..tostring(cloaking_Unit_Default[UnitDefNames["armjamt"].id])..")") -- DEBUG
    return {
	    default = default,
        armjamt = cloaking_Unit_Default[UnitDefNames["armjamt"].id] --and cloakOn==false,
     --   armckfus     = wanted_cloak_values[UnitDefNames.armckfus.id],
     --   armgremlin = wanted_cloak_values[UnitDefNames.armgremlin.id],

    }
end

function widget:SetConfigData(cfg)
    spEcho("[Auto Cloak Units] widget:SetConfigData (default: "..tostring(cfg.default).."".."******".." ArmJammer: "..tostring(cfg.armjamt)..")")  -- DEBUG
    default = cfg.default == true
    cloaking_Unit_Default[UnitDefNames["armjamt"].id] = cfg.armjamt == false --and cloakOn == cfg.armjamt
    cloakOn = cloaking_Unit_Default.id
  --  end
  --  wanted_cloak_values[UnitDefNames.armckfus.id]     = data.armckfus or true
  --  wanted_cloak_values[UnitDefNames.armgremlin.id] = data.armgremlin or true

end