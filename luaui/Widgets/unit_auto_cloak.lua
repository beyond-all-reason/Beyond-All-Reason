
local info = {
    name      = "Auto Cloak Units",
    desc      = "Auto cloaks Units with Cloak",
    author    = "wilkubyk",
    date      = "2022.12.29",
    license   = "GNU GPL, v2 or later",
    layer     = math.huge,
    enabled   = true  -- loaded by default
}

local cloaking_Unit_Default = {
	[UnitDefNames["armjamt"].id]=true,
	[UnitDefNames["armdecom"].id]=true,
    [UnitDefNames["cordecom"].id]=true,
    [UnitDefNames["armferret"].id]=true,
    [UnitDefNames["armamb"].id]=true,
    [UnitDefNames["armpb"].id]=true,
    [UnitDefNames["armsnipe"].id]=true,
    [UnitDefNames["corsktl"].id]=true,
    [UnitDefNames["armgremlin"].id]=true,
    [UnitDefNames["armamex"].id]=true,
    [UnitDefNames["armckfus"].id]=true,
    [UnitDefNames["armspy"].id]=true,
    [UnitDefNames["corspy"].id]=true,
}

--[[
- Sneaky pete | default on armjamt
- Decoy coms | default off armdecom / cordecom
- Pack0 | default off armferret
- Rattlesnake | default off armamb
- PitBull | default off armpb
- Snipers | default off armsnipe
- Skuttle | default off corsktl
- Gremlin | default off armgremlin
]]--

local CMD_CLOAK = 37382
local cloak = CMD_CLOAK
local cloakunits = {}
local gameStarted
local giveOrderToUnit = Spring.GiveOrderToUnit
local spEcho = Spring.Echo
local spUnitTeam = Spring.GetMyTeamID
local default = false
local armjamt = { [UnitDefNames["armjamt"].id]=true }

local function cloakDeActive(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0)
    end
end
local function cloakActive(unitID, unitDefID)
    if cloaking_Unit_Default[unitDefID] then
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
        unitIDs(unitID, unitDefID)
    end

end

function widget:GetInfo()
    return info
end

function widget:GetConfigData()
    spEcho("[Auto Cloak Units] widget:GetConfigData (default: "..tostring(default).."".."******".."armjamt: "..tostring(cloaking_Unit_Default[UnitDefNames["armjamt"].id])..")") -- DEBUG
    return {
	    default = default,
        armjamt = cloaking_Unit_Default[UnitDefNames["armjamt"].id],
        armdecom = cloaking_Unit_Default[UnitDefNames["armdecom"].id],
        cordecom = cloaking_Unit_Default[UnitDefNames["cordecom"].id],
        armferret = cloaking_Unit_Default[UnitDefNames["armferret"].id],
        armamb = cloaking_Unit_Default[UnitDefNames["armamb"].id],
        armpb = cloaking_Unit_Default[UnitDefNames["armpb"].id],
        armsnipe = cloaking_Unit_Default[UnitDefNames["armsnipe"].id],
        corsktl = cloaking_Unit_Default[UnitDefNames["corsktl"].id],
        armgremlin = cloaking_Unit_Default[UnitDefNames["armgremlin"].id],
        armamex = cloaking_Unit_Default[UnitDefNames["armamex"].id],
        armckfus = cloaking_Unit_Default[UnitDefNames["armckfus"].id],
        armspy = cloaking_Unit_Default[UnitDefNames["armspy"].id],
        corspy = cloaking_Unit_Default[UnitDefNames["corspy"].id],
    }
end

function widget:SetConfigData(cfg)
    spEcho("[Auto Cloak Units] widget:SetConfigData (default: "..tostring(cfg.default).."".."******".." ArmJammer: "..tostring(cfg.armjamt)..")")  -- DEBUG
    default = cfg.default == true
    cloaking_Unit_Default[UnitDefNames["armjamt"].id] = cfg.armjamt == true
    cloaking_Unit_Default[UnitDefNames["armdecom"].id] = cfg.armdecom == false
    cloaking_Unit_Default[UnitDefNames["cordecom"].id] = cfg.cordecom == false
    cloaking_Unit_Default[UnitDefNames["armferret"].id] = cfg.armferret == false
    cloaking_Unit_Default[UnitDefNames["armamb"].id] = cfg.armamb == false
    cloaking_Unit_Default[UnitDefNames["armpb"].id] = cfg.armpb == false
    cloaking_Unit_Default[UnitDefNames["armsnipe"].id] = cfg.armsnipe == false
    cloaking_Unit_Default[UnitDefNames["corsktl"].id] = cfg.corsktl == false
    cloaking_Unit_Default[UnitDefNames["armgremlin"].id] = cfg.armgremlin == false
    cloaking_Unit_Default[UnitDefNames["armamex"].id] = cfg.armamex == true
    cloaking_Unit_Default[UnitDefNames["armckfus"].id] = cfg.armckfus == true
    cloaking_Unit_Default[UnitDefNames["armspy"].id] = cfg.armspy == true
    cloaking_Unit_Default[UnitDefNames["corspy"].id] = cfg.corspy == true
end

function widget:Initialize()
    spEcho("[Auto Cloak Units] Initializing plugin")  -- DEBUG

    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end

    WG['default_cloak']= {}
    WG['default_cloak'].get_Default     = function() return default end
    WG['default_cloak'].set_Default     = function(value)
        spEcho("[Auto Cloak Units] Toggling Default from "..tostring(default).." to "..tostring(value))  -- DEBUG
        default = value
    --    cloakDeActive()
    end
    WG['init_cloak'] = {}
    WG['init_cloak'].get_ArmJamt = function() return cloaking_Unit_Default[UnitDefNames["armjamt"].id] end
    WG['init_cloak'].set_ArmJamt = function(value)
        spEcho("[Auto Cloak Units] Toggling Sneaky Pete from "..tostring(cloaking_Unit_Default[UnitDefNames["armjamt"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armjamt"].id] = value
    --    cloakActive()
    end
    --WG['init_cloak'] = {}
    WG['init_cloak'].get_ArmDeCom     = function() return cloaking_Unit_Default[UnitDefNames["armdecom"].id] end
    WG['init_cloak'].set_ArmDeCom     = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Decoy Commander from "..tostring(cloaking_Unit_Default[UnitDefNames["armdecom"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armdecom"].id] = value
    end
    --WG['init_cloak'] = {}
    WG['init_cloak'].get_CorDeCom = function() return cloaking_Unit_Default[UnitDefNames["cordecom"].id] end
    WG['init_cloak'].set_CorDeCom = function(value)
        spEcho("[Auto Cloak Units] Toggling Cortex Decoy Commander from "..tostring(cloaking_Unit_Default[UnitDefNames["cordecom"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["cordecom"].id] = value
    end
    WG['init_cloak'].get_ArmFerret = function() return cloaking_Unit_Default[UnitDefNames["armferret"].id] end
    WG['init_cloak'].set_ArmFerret = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Ferret from "..tostring(cloaking_Unit_Default[UnitDefNames["armferret"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armferret"].id] = value
    end
    WG['init_cloak'].get_ArmAmb = function() return cloaking_Unit_Default[UnitDefNames["armamb"].id] end
    WG['init_cloak'].set_ArmAmb = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Rattlesnake from "..tostring(cloaking_Unit_Default[UnitDefNames["armamb"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armamb"].id] = value
    end
    WG['init_cloak'].get_ArmPb = function() return cloaking_Unit_Default[UnitDefNames["armpb"].id] end
    WG['init_cloak'].set_ArmPb = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Pit Bull from "..tostring(cloaking_Unit_Default[UnitDefNames["armpb"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armpb"].id] = value
    end
    WG['init_cloak'].get_ArmSnipe = function() return cloaking_Unit_Default[UnitDefNames["armsnipe"].id] end
    WG['init_cloak'].set_ArmSnipe = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Sharpshooter from "..tostring(cloaking_Unit_Default[UnitDefNames["armsnipe"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armsnipe"].id] = value
    end
    WG['init_cloak'].get_CorSktl = function() return cloaking_Unit_Default[UnitDefNames["corsktl"].id] end
    WG['init_cloak'].set_CorSktl = function(value)
        spEcho("[Auto Cloak Units] Toggling Cortex Skuttle from "..tostring(cloaking_Unit_Default[UnitDefNames["corsktl"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["corsktl"].id] = value
    end
    WG['init_cloak'].get_ArmGremlin = function() return cloaking_Unit_Default[UnitDefNames["armgremlin"].id] end
    WG['init_cloak'].set_ArmGremlin = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Gremlin from "..tostring(cloaking_Unit_Default[UnitDefNames["armgremlin"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armgremlin"].id] = value
    end
    WG['init_cloak'].get_ArmAmex = function() return cloaking_Unit_Default[UnitDefNames["armamex"].id] end
    WG['init_cloak'].set_ArmAmex = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Gremlin from "..tostring(cloaking_Unit_Default[UnitDefNames["armamex"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armamex"].id] = value
    end
    WG['init_cloak'].get_ArmCkfus = function() return cloaking_Unit_Default[UnitDefNames["armckfus"].id] end
    WG['init_cloak'].set_ArmCkfus = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Gremlin from "..tostring(cloaking_Unit_Default[UnitDefNames["armckfus"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armckfus"].id] = value
    end
    WG['init_cloak'].get_ArmSpy = function() return cloaking_Unit_Default[UnitDefNames["armspy"].id] end
    WG['init_cloak'].set_ArmSpy = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Gremlin from "..tostring(cloaking_Unit_Default[UnitDefNames["armspy"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["armspy"].id] = value
    end
    WG['init_cloak'].get_CorSpy = function() return cloaking_Unit_Default[UnitDefNames["corspy"].id] end
    WG['init_cloak'].set_CorSpy = function(value)
        spEcho("[Auto Cloak Units] Toggling Armada Gremlin from "..tostring(cloaking_Unit_Default[UnitDefNames["corspy"].id]).." to "..tostring(value))  -- DEBUG
        cloaking_Unit_Default[UnitDefNames["corspy"].id] = value
    end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if default == false then
        cloakDeActive(unitID, unitDefID)
        elseif default == true then
            cloakActive(unitID, unitDefID)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
      if cloakunits[unitID] then
         cloakunits[unitID] = nil
      end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
        NewUnit(unitID, unitDefID, unitTeam)
        cloakDeActive(unitID, unitDefID)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
        NewUnit(unitID, unitDefID, unitTeam)
        cloakDeActive(unitID, unitDefID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
        NewUnit(unitID, unitDefID, unitTeam)
        cloakDeActive(unitID, unitDefID)
end

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