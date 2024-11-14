--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_morph.lua
--  brief:   Adds unit morphing command
--  author:  Dave Rodgers (improved by jK, Licho, aegis, CarRepairer & MaDDoX)
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "UnitMorph",
    desc      = "Adds unit morphing",
    author    = "trepan (improved by jK, Licho, aegis, CarRepairer, MaDDoX)",
    date      = "Jan, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 500,
    enabled   = false
  }
end

--local unitDefsData = VFS.Include("gamedata/unitdefs_data.lua")  -- TA Prime all-inclusive unitDefs file format

-- Changes for "The Cursed"
--		CarRepairer: may add a customized texture in the morphdefs, otherwise uses original behavior (unit buildicon).
--		aZaremoth: may add a customized text in the morphdefs
-- Changes for "Advanced BA"
--		Deadnight Warrior: may add a customized command name in the morphdefs, otherwise defaults to "Upgrade"
--				   you may use "$$unitname" and "$$into" in 'text', both will be replaced with human readable unit names
-- Changes by raaar (04/2012):
--      commented out the preservation of cmd queue and unit lineage at lines 536 and 559
-- Changes by raaar (12/2013):
--      commented out turning unit off at lines 396 and 425, was giving errors in spring 95.0
-- Changes for "TA Prime" by _MaDDoX (12/2017):
--      Default buildtime, buildcostenergy and buildcostmetal is now the difference between original and target unit values
--      Accepts and prioritizes definitions in customData.morphdef
--      Properly talks to multi_tech.lua (tech tree gadget by zwzsg)
--      'require' entry now require techs instead of units
--      'require' supports multiple tech requirements (comma-separated)
--      Morph button text now shown in red when requirements not fulfilled

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Proposed Command ID Ranges:
--
--    all negative:  Engine (build commands)
--       0 -   999:  Engine
--    1000 -  9999:  Group AI
--   10000 - 19999:  LuaUI
--   20000 - 29999:  LuaCob
--   30000 - 39999:  LuaRules
--

local CMD_MORPH_STOP = 32410
local CMD_MORPH = 31410
local CMD_EZ_MORPH = 31337 -- accepts target unitDefID as optional 1st parameter (1st found morph if missing)
local MAX_MORPH = 0 --// will increase dynamically

--------------------------------------------------------------------------------
--  COMMON
--------------------------------------------------------------------------------

--[[ // for use with any mod -_-
function GetTechLevel(udid)
  local ud = UnitDefs[udid];
  return (ud and ud.techLevel) or 0
end
]]--

-- // for use with mods like CA <_<
local function GetTechLevel(UnitDefID)
  --return UnitDefs[UnitDefID].techLevel or 0
  local cats = UnitDefs[UnitDefID].modCategories
  if (cats) then
    --// bugfix, cuz lua don't remove uppercase :(
    if     (cats["LEVEL1"]) then return 1
    elseif (cats["LEVEL2"]) then return 2
    elseif (cats["LEVEL3"]) then return 3
      elseif (cats["level1"]) then return 1
      elseif (cats["level2"]) then return 2
      elseif (cats["level3"]) then return 3
    end
  end
  return 0
end

local function isFactory(UnitDefID)
  return UnitDefs[UnitDefID].isFactory or false
end


local function isFinished(UnitID)
  return not Spring.GetUnitIsBeingBuilt(UnitID)
end

local function HeadingToFacing(heading)
	--return math.floor((-heading - 24576) / 16384) % 4
	return math.floor((heading + 8192) / 16384) % 4
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


if (gadgetHandler:IsSyncedCode()) then
--------------------------------------------------------------------------------
--  SYNCED
--------------------------------------------------------------------------------

include("LuaRules/colors.h.lua")

local stopPenalty  = 0.667
local morphPenalty = 1.6
local upgradingBuildSpeed = 250   -- Commander workertime = 300
local XpScale = 1.0

local XpMorphUnits = {}

local devolution = true            --// remove upgrade capabilities after factory destruction?
local stopMorphOnDevolution = true --// should morphing stop during devolution

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local morphDefs  = {} --// make it global in Initialize()
local extraUnitMorphDefs = {} -- stores mainly planetwars morphs
local hostName = nil -- planetwars hostname
local PWUnits = {} -- planetwars units
local morphUnits = {} --// make it global in Initialize()

local reqTechs = {} --// all possible techs which are used as a requirement for a morph

--// per team techlevel and owned MorphReq. units table
local teamTechLevel = {}
--// Prime: Removing support for Required Units
local morphableUnits = {}  -- UnitTypeIDs which may be morphed [teamId] [# of required UnitTypeIDs currenty]
local teamList = Spring.GetTeamList()
for i=1,#teamList do
  local teamID = teamList[i]
  morphableUnits[teamID]  = {}
  teamTechLevel[teamID] = 0
end

local morphCmdDesc = {
--  id     = CMD_MORPH, -- added by the calling function because there is now more than one option
  type   = CMDTYPE.ICON,
  name   = 'Upgrade',
  cursor = 'Morph',  -- add with LuaUI?
  action = 'morph',
}

--// will be replaced in Initialize()
local RankToXp    = function() return 0 end
local GetUnitRank = function() return 0 end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--// translate lowercase UnitNames to real unitname (with upper-/lowercases)
local defNamesL = {}
for defName in pairs(UnitDefNames) do
  defNamesL[string.lower(defName)] = defName
end

--// Calculates Default values | edited for TA Prime by MaDDoX
local function DefCost(paramName, udSrc, udDst)
  local pSrc = udSrc[paramName]
  local pTgt = udDst[paramName]
  if ((not pSrc) or (not pTgt) or
      (type(pSrc) ~= 'number') or
      (type(pTgt) ~= 'number')) then
      Spring.Echo('Morph '..paramName..' error: NaN found')
    return 0
  end
  local cost = (pTgt - pSrc) * morphPenalty
  if (cost < 0) then
    cost = 0
  end
  return math.floor(cost)
end

-- That's only called on initialize, to validate morph_defs.lua & custom data
local function BuildMorphDef(udSrc, morphData)
  local udDst = UnitDefNames[defNamesL[string.lower(morphData.into)] or -1]
  if (not udDst) then
    if (not morphData.into) then
      Spring.Echo('Morph gadget: Invalid "into" field within morphData')
    else
      Spring.Echo('Morph gadget: Bad morph dst type: ' .. morphData.into)
    end
    return
  else
    local unitDef = udDst
    local newData = {}
    newData.into = udDst.id
    --newData.time = morphData.time or math.floor(unitDef.buildTime*7/upgradingBuildSpeed)
    newData.time = morphData.time or (DefCost('buildTime', udSrc, udDst) / upgradingBuildSpeed)
    newData.increment = (1 / (30 * newData.time))
    newData.metal  = morphData.metal  or DefCost('metalCost',  udSrc, udDst)
    newData.energy = morphData.energy or DefCost('energyCost', udSrc, udDst)
    newData.resTable = {
      m = (newData.increment * newData.metal),
      e = (newData.increment * newData.energy)
    }
    newData.tech = morphData.tech or 0
    newData.xp   = morphData.xp or 0
    newData.rank = morphData.rank or 0
    newData.facing = morphData.facing

    local requireDefined = -1
    local foundAllRequires = true
    if (morphData.require) then
      --require = (UnitDefNames[defNamesL[string.lower(morphData.require)] or -1] or {}).id
      local requires = morphData.require:split(',')
      -- // All required technologies must be defined, or else invalidate
      for i = 1, #requires do
        -- Team 0 is used just as a filler here, the important is that the return ~= nil
        requireDefined = GG.TechCheck(requires[i], 0) ~= nil
        if (requireDefined) then
          --echo('Morph gadget: Requirement defined: ' .. requires[i])
          reqTechs[requires[i]]=true
        else
          -- echo('Morph gadget: Bad morph requirement: ' .. requires[i].." tech not found")
          --require = -1
          foundAllRequires = false
        end
      end
    end
    --newData.require = require
    newData.require = foundAllRequires and morphData.require or -1

    newData.cmd     = CMD_MORPH      + MAX_MORPH
    newData.stopCmd = CMD_MORPH_STOP + MAX_MORPH
    MAX_MORPH = MAX_MORPH + 1

	newData.texture = morphData.texture
	if morphData.text then
		newData.text = string.gsub(morphData.text, "$$unitname", udSrc.humanName)
		newData.text = string.gsub(newData.text, "$$into", udDst.humanName)
	else
		newData.text = morphData.text
	end
	if morphData.cmdname then
		newData.cmdname = morphData.cmdname
	else
		newData.cmdname = "Upgrade"
	end
    return newData
  end
end

local function ValidateMorphDefs(mds)
  local newDefs = {}
  for src,morphData in pairs(mds) do
    --//#debug
--    Spring.Echo("Source: "..src)
--    for k,v in pairs(morphData) do
--      Spring.Echo("K, V:"..tostring(k),v)
--      for q,w in pairs(v) do
--        Spring.Echo("-- morphData v: "..q,w)
--      end
--    end
    local udSrc = UnitDefNames[defNamesL[string.lower(src)] or -1]
    if (not udSrc) then
      Spring.Echo('Morph gadget: Bad morph src type: ' .. src)
    else
      newDefs[udSrc.id] = {}
      if (morphData.into) then
        local morphDef = BuildMorphDef(udSrc, morphData)
        if (morphDef) then newDefs[udSrc.id][morphDef.cmd] = morphDef end
      else
        for _,morphData in pairs(morphData) do
          local morphDef = BuildMorphDef(udSrc, morphData)
          if (morphDef) then newDefs[udSrc.id][morphDef.cmd] = morphDef end
        end
      end
    end
  end
  return newDefs
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- //This is where multiple tech requirements check kick in.

-- Previously it returned how many of the required unit type there are in the game
  --return ((teamReqUnits[teamID][reqTechs] or 0) > 0)
-- Now it returns a list of all unreached techs
local function TechReqList(teamID, reqTechs)
  if (reqTechs == -1) then
    return {} end

  local unreachedTechs = {}
  if (reqTechs) then
    local requires = reqTechs:split(',')

    for i = 1, #requires do
      local hasRequire = GG.TechCheck(requires[i], teamID) == true
      if (hasRequire) then
        --Spring.Echo('Morph gadget: Requirement found: ' .. requires[i])
      else
        --Spring.Echo('Morph gadget: Unreached requirement: ' .. requires[i])
        --require = -1
        unreachedTechs[#unreachedTechs+1] = requires[i]
      end
    end
  end

  return unreachedTechs
end

local function TechReqCheck(teamID, reqTechs)
  if (not reqTechs or reqTechs == -1) then
    return true end

  local hasAllTechs = true
  local requires = reqTechs:split(',')

  for i = 1, #requires do
    local hasRequire = GG.TechCheck(requires[i], teamID) == true
    if not hasRequire then
      hasAllTechs = false
    end
  end

  return hasAllTechs
end

local function GetMorphToolTip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, unreachedTechs)
  local ud = UnitDefs[morphDef.into]
  local tt = ''
  if (morphDef.text ~= nil) then
	tt = tt .. WhiteStr  .. morphDef.text .. '\n'
  else
  	--tt = tt .. WhiteStr  .. 'Upgrade into a ' .. ud.humanName .. '\n'
  	tt = tt .. 'Upgrade into a ' .. ud.humanName .. '\n'
  end
  if (morphDef.time > 0) then
  	tt = tt .. GreenStr  .. 'time: '   .. morphDef.time     .. '\n'
  end
  if (morphDef.metal > 0) then
  	tt = tt .. CyanStr   .. 'metal: '  .. morphDef.metal    .. '\n'
  end
  if (morphDef.energy > 0) then
    tt = tt .. YellowStr .. 'energy: ' .. morphDef.energy   .. '\n'
  end
  if (morphDef.tech > teamTech) or
     (morphDef.xp > unitXP) or
     (morphDef.rank > unitRank) or
     (unreachedTechs and #unreachedTechs >= 1)
  then
    tt = tt .. RedStr .. 'needs'
    if (morphDef.tech>teamTech) then tt = tt .. ' level: ' .. morphDef.tech end
    if (morphDef.xp>unitXP)     then tt = tt .. ' xp: '    .. string.format('%.2f',morphDef.xp) end
    if (morphDef.rank>unitRank) then tt = tt .. ' rank: '  .. morphDef.rank .. ' (' .. string.format('%.2f',RankToXp(unitDefID,morphDef.rank)) .. 'xp)' end
    -- if (not teamOwnsReqUnit)	then tt = tt .. ' unit: '  .. UnitDefs[morphDef.require].humanName end
    -- Refactored to show unreached+required tech
    --tt = tt .. ' unit: '  .. reqTech[x]
      -- // Loop all unreachedTechs and add to the tooltip
    if (unreachedTechs and #unreachedTechs >= 1)	then
      local str = ' tech(s): '  .. unreachedTechs[1]
      if #unreachedTechs > 1 then
        for i = 2, #unreachedTechs do
          str = str .. ', '..unreachedTechs[i]
        end
      end
      tt = tt..str
    end
  end
  return tt
end

local function MorphRequirementsFulfilled(unitID, morphDef, techLevel, unreachedTechs)
	return morphDef.tech <= techLevel
	   and morphDef.rank <= GetUnitRank(unitID)
	   and morphDef.xp   <= Spring.GetUnitExperience(unitID)
	   and #unreachedTechs == 0
end

local function UpdateMorphReqs(teamID)
  local morphCmdDesc = {}

  local teamTech  = teamTechLevel[teamID] or 0
  local teamUnits = Spring.GetTeamUnits(teamID)
  for n=1,#teamUnits do
    local unitID   = teamUnits[n]
    local unitXP   = Spring.GetUnitExperience(unitID)
    local unitRank = GetUnitRank(unitID)
    local unitDefID = Spring.GetUnitDefID(unitID)
    local morphDefs = morphDefs[unitDefID] or {}

    for _,morphDef in pairs(morphDefs) do
      local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
      if (cmdDescID) then
        local unreachedTechs = TechReqList(teamID, morphDef.require)
        morphCmdDesc.disabled = not MorphRequirementsFulfilled(unitID, morphDef, teamTech, unreachedTechs)
        if (morphCmdDesc.disabled) then
          morphCmdDesc.name = "\255\255\64\64"..morphDef.cmdname
        else
          morphCmdDesc.name = "\255\255\255\255"..morphDef.cmdname
        end
        morphCmdDesc.tooltip = GetMorphToolTip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP,
                                                unitRank, unreachedTechs)
        Spring.EditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)
      end
    end
  end
end

local function AddMorphCmdDesc(unitID, unitDefID, teamID, morphDef, teamTech)
  local unitXP   = Spring.GetUnitExperience(unitID)
  local unitRank = GetUnitRank(unitID)
  local teamReqTechs = TechReqList(teamID, morphDef.require)
  local teamHasTechs = teamReqTechs and #teamReqTechs == 0
  morphCmdDesc.tooltip = GetMorphToolTip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, teamReqTechs)

  if morphDef.texture then
	morphCmdDesc.texture = "LuaRules/Images/Morph/".. morphDef.texture
  else
	morphCmdDesc.texture = "#" .. morphDef.into   --//only works with a patched layout.lua or the TweakedLayout widget!
  end
  morphCmdDesc.name = morphDef.cmdname

  morphCmdDesc.disabled= (morphDef.tech > teamTech) or (morphDef.rank > unitRank)
                          or(morphDef.xp > unitXP) or (not teamHasTechs)

  morphCmdDesc.id = morphDef.cmd

  local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
  if (cmdDescID) then
    Spring.EditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)
  else
    Spring.InsertUnitCmdDesc(unitID, morphCmdDesc)
  end

  morphCmdDesc.tooltip = nil
  morphCmdDesc.texture = nil
  morphCmdDesc.text = nil
end


local function AddExtraUnitMorph(unitID, unitDef, teamID, morphDef)  -- adds extra unit morph (planetwars morphing)
	morphDef = BuildMorphDef(unitDef, morphDef)
	extraUnitMorphDefs[unitID] = morphDef
	AddMorphCmdDesc(unitID, unitDef.id, teamID, morphDef, 0)
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function ReAssignAssists(newUnit,oldUnit)
  local ally = Spring.GetUnitAllyTeam(newUnit)
  local alliedTeams = Spring.GetTeamList(ally)
  for n=1,#alliedTeams do
    local teamID = alliedTeams[n]
    local alliedUnits = Spring.GetTeamUnits(teamID)
    for i=1,#alliedUnits do
      local unitID = alliedUnits[i]
      local cmds = Spring.GetCommandQueue(unitID, 1)
      for j=1,#cmds do
        local cmd = cmds[j]
        if (cmd.id == CMD.GUARD)and(cmd.params[1] == oldUnit) then
          Spring.GiveOrderToUnit(unitID,CMD.INSERT,{cmd.tag,CMD.GUARD,0,newUnit},{})
          Spring.GiveOrderToUnit(unitID,CMD.REMOVE,{cmd.tag},{})
        end
      end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function StartMorph(unitID, unitDefID, teamID, morphDef)

  -- do not allow morph for unfinsihed units
  if not isFinished(unitID)
  or not MorphRequirementsFulfilled(unitID, morphDef, teamTechLevel[teamID] or 0, TechReqList(teamID, morphDef.require))
  then
    return true
  end

  --Spring.SetUnitHealth(unitID, { paralyze = 1.0e9 })    --// turns mexes and mm off (paralyze the unit)
  Spring.SetUnitResourcing(unitID,"e",0)                --// turns solars off
  -- Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, { "alt" }) --// turns radars/jammers off

  morphUnits[unitID] = {
    def = morphDef,
    progress = 0.0,
    increment = morphDef.increment,
    morphID = morphID,
    teamID = teamID,
  }

  local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
  if (cmdDescID) then
    Spring.EditUnitCmdDesc(unitID, cmdDescID, {id=morphDef.stopCmd, name=RedStr.."Stop"})
  end

  SendToUnsynced("unit_morph_start", unitID, unitDefID, morphDef.cmd)
end


local function StopMorph(unitID, morphData)
  morphUnits[unitID] = nil

  --Spring.SetUnitHealth(unitID, { paralyze = -1})
  local scale = morphData.progress * stopPenalty
  local unitDefID = Spring.GetUnitDefID(unitID)

  Spring.SetUnitResourcing(unitID,"e", UnitDefs[unitDefID].energyMake)
  -- Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, { "alt" })
  local usedMetal  = morphData.def.metal  * scale
  Spring.AddUnitResource(unitID, 'metal',  usedMetal)
  --local usedEnergy = morphData.def.energy * scale
  --Spring.AddUnitResource(unitID, 'energy', usedEnergy)

  SendToUnsynced("unit_morph_stop", unitID)

  local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphData.def.stopCmd)
  if (cmdDescID) then
    Spring.EditUnitCmdDesc(unitID, cmdDescID, {id=morphData.def.cmd, name=morphData.def.cmdname})
  end
end



local function FinishMorph(unitID, morphData)
  local udDst = UnitDefs[morphData.def.into]
  local ud = UnitDefs[unitID]
  local defName = udDst.name
  local unitTeam = morphData.teamID
  local px, py, pz = Spring.GetUnitBasePosition(unitID)
  local h = Spring.GetUnitHeading(unitID)
  Spring.SetUnitBlocking(unitID, false)
  morphUnits[unitID] = nil

  local newUnit
  local face = HeadingToFacing(h)

  if udDst.isBuilding or udDst.isFactory then
  --if udDst.isBuilding then

	local x = math.floor(px/16)*16
	local y = py
	local z = math.floor(pz/16)*16

	local xsize = udDst.xsize
	local zsize =(udDst.zsize or udDst.ysize)
	if ((face == 1) or(face == 3)) then
	  xsize, zsize = zsize, xsize
	end
	if xsize/4 ~= math.floor(xsize/4) then
	  x = x+8
	end
	if zsize/4 ~= math.floor(zsize/4) then
	  z = z+8
	end
	newUnit = Spring.CreateUnit(defName, x, y, z, face, unitTeam)
	Spring.SetUnitPosition(newUnit, x, y, z)
  else
	newUnit = Spring.CreateUnit(defName, px, py, pz, face, unitTeam)
	--Spring.SetUnitRotation(newUnit, 0, -h * math.pi / 32768, 0)
	Spring.SetUnitPosition(newUnit, px, py, pz)
  end

  if (extraUnitMorphDefs[unitID] ~= nil) then
    -- nothing here for now
  end
  if (hostName ~= nil) and PWUnits[unitID] then
    -- send planetwars deployment message
    PWUnit = PWUnits[unitID]
    PWUnit.currentDef=udDst
    -- TODO: determine and apply smart orientation of the structure
	local data = PWUnit.owner..","..defName..","..math.floor(px)..","..math.floor(pz)..",".."S"
	Spring.SendCommands("w "..hostName.." pwmorph:"..data)
	extraUnitMorphDefs[unitID] = nil
	GG.PlanetWars.units[unitID] = nil
	GG.PlanetWars.units[newUnit] = PWUnit
	SendToUnsynced('PWCreate', unitTeam, newUnit)
  elseif (not morphData.def.facing) then  -- set rotation only if unit is not planetwars and facing is not true
    --Spring.Echo(morphData.def.facing)
    --Spring.SetUnitRotation(newUnit, 0, -h * math.pi / 32768, 0)
  end


  --//copy experience
  local newXp = Spring.GetUnitExperience(unitID)*XpScale
  local nextMorph = morphDefs[morphData.def.into]
  if nextMorph~= nil and nextMorph.into ~= nil then nextMorph = {morphDefs[morphData.def.into]} end
  if (nextMorph) then --//determine the lowest xp req. of all next possible morphs
    local maxXp = math.huge
    for _, nm in pairs(nextMorph) do
      local rankXpInto = RankToXp(nm.into,nm.rank)
      if (rankXpInto>0)and(rankXpInto<maxXp) then
        maxXp=rankXpInto
      end
      local xpInto     = nm.xp
      if (xpInto>0)and(xpInto<maxXp) then
        maxXp=xpInto
      end
    end
    newXp = math.min( newXp, maxXp*0.9)
  end
  Spring.SetUnitExperience(newUnit, newXp)

  --//copy some state
  local states = Spring.GetUnitStates(unitID)
  Spring.GiveOrderArrayToUnitArray({ newUnit }, {
    { CMD.FIRE_STATE, { states.firestate },             { } },
    { CMD.MOVE_STATE, { states.movestate },             { } },
    { CMD.REPEAT,     { states["repeat"] and 1 or 0 },  { } },
    { CMD.CLOAK,      { states.cloak     and 1 or udDst.initCloaked },  { } },
    { CMD.ONOFF,      { 1 },                            { } },
    { CMD.TRAJECTORY, { states.trajectory and 1 or 0 }, { } },
  })

  --//copy command queue        FIX : removed 04/2012, caused erros
  --local cmds = Spring.GetUnitCommands(unitID)
  --for i = 2, cmds.n do  -- skip the first command (CMD_MORPH)
    --local cmd = cmds[i]
    --Spring.GiveOrderToUnit(newUnit, cmd.id, cmd.params, cmd.options.coded)
  --end

  --//reassign assist commands to new unit
  ReAssignAssists(newUnit,unitID)

  --// copy health
  local oldHealth,oldMaxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
  local _,newMaxHealth         = Spring.GetUnitHealth(newUnit)
  local newHealth = (oldHealth / oldMaxHealth) * newMaxHealth
  if newHealth<=1 then newHealth = 1 end
  Spring.SetUnitHealth(newUnit, {health = newHealth, build = buildProgress})

  --// copy shield power
  local enabled,oldShieldState = Spring.GetUnitShieldState(unitID)
  if oldShieldState and Spring.GetUnitShieldState(newUnit) then
    Spring.SetUnitShieldState(newUnit, enabled,oldShieldState)
  end

  -- FIX : unit lineage was disabled in 84.0
  --local lineage = Spring.GetUnitLineage(unitID)
  --Spring.SetUnitLineage(newUnit,lineage,true)

  --// FIXME: - re-attach to current transport?
  --// update selection
  SendToUnsynced("unit_morph_finished", unitID, newUnit)

  Spring.SetUnitBlocking(newUnit, true)
  Spring.DestroyUnit(unitID, false, true) -- selfd = false, reclaim = true
end


local function UpdateMorph(unitID, morphData)
  if not isFinished(unitID) then return true end
  if Spring.GetUnitTransporter(unitID) then return true end

  if (Spring.UseUnitResource(unitID, morphData.def.resTable)) then
    morphData.progress = morphData.progress + morphData.increment
  end
  if (morphData.progress >= 1.0) then
    FinishMorph(unitID, morphData)
    return false -- remove from the list, all done
  end
  return true
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

  --// Add MorphDefs from customData entries (TODO: allow data merge, currently only overrides)
  local function AddCustomMorphDefs()
   -- Standard .fbi method: (needs testing, TA Prime uses UnitDefsData)
	for id,unitDef in pairs(UnitDefs) do
		if unitDef.customParams.morphdef and type(unitDef.customParams.morphdef) == "table" then
			local customMorphDef = unitDef.customParams.morphdef
			--#debug Spring.Echo(unitname.." morphdef into: "..tostring(unitDef.customParams.into))
			morphDefs[unitDef.name] = {customMorphDef}
		end
	end
	return

    -- UnitDefsData method:
    -- if unitDefsData == nil then
      -- return end

    -- for id,unitDef in pairs(UnitDefs) do
      -- local nam = unitDef.name
      -- for _, uData in pairs(unitDefsData.data) do
        -- if type(uData) == "table" and uData[1] == nam then
          -- local dataEntry = uData[2]
          -- if (dataEntry.customparams ~= nil and dataEntry.customparams.morphdef ~= nil) then
            -- local customMorphDef = dataEntry.customparams.morphdef
            --#debug Spring.Echo(nam .." morphdef into = ".. dataEntry.customparams.morphdef.into)
            -- morphDefs[nam] = {customMorphDef}
          -- end
        -- end
      -- end

    -- end
  end

local function RegisterAllowCommands()
  -- CMD_EZ_MORPH, CMD.STOP, CMD.ONOFF, CMD.SELFD, CMD_MORPH->CMD_MORPH+MAX_MORPH-1, CMD_STOP_MORPH+MAX_MORPH-1
  -- careful MAX_MORPH increases during Initialize
  gadgetHandler:RegisterAllowCommand(CMD_EZ_MORPH)
  gadgetHandler:RegisterAllowCommand(CMD.STOP)
  gadgetHandler:RegisterAllowCommand(CMD.ONOFF)
  gadgetHandler:RegisterAllowCommand(CMD.SELFD)
  for number = 0, MAX_MORPH-1 do
    gadgetHandler:RegisterAllowCommand(CMD_MORPH+number)
    gadgetHandler:RegisterAllowCommand(CMD_STOP_MORPH+number)
  end

end

function gadget:Initialize()
  --// RankApi linking
  if (GG.rankHandler) then
    GetUnitRank = GG.rankHandler.GetUnitRank
    RankToXp    = GG.rankHandler.RankToXp
  end

  -- self linking for planetwars
  GG['morphHandler'] = {}
  GG['morphHandler'].AddExtraUnitMorph = AddExtraUnitMorph

  hostName = GG.PlanetWars and GG.PlanetWars.options.hostname or nil
  PWUnits = GG.PlanetWars and GG.PlanetWars.units or {}

  if (type(GG.UnitRanked)~="table") then GG.UnitRanked = {} end
  table.insert(GG.UnitRanked, UnitRanked)

  --// get the morphDefs
  morphDefs = include("gamedata/morph_defs.lua")

  --// MorphDefs can now be all defined in customParams (by MaDDoX)
  AddCustomMorphDefs()
  morphDefs = ValidateMorphDefs(morphDefs)
--  if (not morphDefs)
--    then gadgetHandler:RemoveGadget()
--    return end

  --// make it global for unsynced access via SYNCED
  _G.morphUnits = morphUnits
  _G.morphDefs  = morphDefs
  _G.extraUnitMorphDefs  = extraUnitMorphDefs

  --// Register CmdIDs
  for number = 0, MAX_MORPH-1 do
    gadgetHandler:RegisterCMDID(CMD_MORPH + number)
    gadgetHandler:RegisterCMDID(CMD_MORPH_STOP + number)
  end
  RegisterAllowCommands()

  local allUnits = Spring.GetAllUnits()
  for i = 1, #allUnits do
    local unitID    = allUnits[i]
    local unitDefID = Spring.GetUnitDefID(unitID)
    local teamID    = Spring.GetUnitTeam(unitID)
    --// Deprecated, now just checks existing technologies on start
--    if (reqTechs[unitDefID])and(isFinished(unitID)) then
--      local morphUnits = morphableUnits[teamID]
--      morphUnits[unitDefID] = (morphUnits[unitDefID] or 0) + 1
--    end
    UpdateMorphReqs(teamID)
    AddFactory(unitID, unitDefID, teamID)
    local morphDefSet  = morphDefs[unitDefID]
    if (morphDefSet) then
      local useXPMorph = false
      for _,morphDef in pairs(morphDefSet) do
        if (morphDef) then
          local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
          if (not cmdDescID) then
            AddMorphCmdDesc(unitID, unitDefID, teamID, morphDef, teamTechLevel[teamID])
          end
          useXPMorph = (morphDef.xp > 0) or useXPMorph
        end
      end
      if (useXPMorph) then
        XpMorphUnits[#XpMorphUnits+1] = {id=unitID, defID=unitDefID, team=teamID} end
    end
  end

end


function gadget:Shutdown()
  for i,f in pairs(GG.UnitRanked or {}) do
    if (f==UnitRanked) then
      table.remove(GG.UnitRanked, i)
      break
    end
  end

  local allUnits = Spring.GetAllUnits()
  for i=1,#allUnits do
    local unitID    = allUnits[i]
    local morphData = morphUnits[unitID]
    if (morphData) then
      StopMorph(unitID, morphData)
    end
    for number=0,MAX_MORPH-1 do
      local cmdDescID = Spring.FindUnitCmdDesc(unitID, CMD_MORPH+number)
      if (cmdDescID) then
        Spring.RemoveUnitCmdDesc(unitID, cmdDescID)
      end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- When a unit starts being built, still in green-placeholder mode
function gadget:UnitCreated(unitID, unitDefID, teamID)
  local morphDefSet = morphDefs[unitDefID]
  if (morphDefSet) then
    local useXPMorph = false
    for _,morphDef in pairs(morphDefSet) do
      if (morphDef) then
    	AddMorphCmdDesc(unitID, unitDefID, teamID, morphDef, teamTechLevel[teamID])
        useXPMorph = (morphDef.xp > 0) or useXPMorph
      end
    end
    if (useXPMorph) then XpMorphUnits[#XpMorphUnits+1] = {id=unitID,defID=unitDefID,team=teamID} end
  end
end

-- When a unit is completed, it must re-check morphing prereqs, since some tech could've been unlocked
function gadget:UnitFinished(unitID, unitDefID, teamID)
  local bfrTechLevel = teamTechLevel[teamID] or 0
  AddFactory(unitID, unitDefID, teamID)

  UpdateMorphReqs(teamID)
--  if (reqTechs[unitDefID]) then
--    local teamReq = morphableUnits[teamID]
--    -- add 1 to amount of existing required units
--    teamReq[unitDefID] = (teamReq[unitDefID] or 0) + 1
--    if (teamReq[unitDefID]==1) then
--      UpdateMorphReqs(teamID)
--    end
--  end

  if (bfrTechLevel ~= teamTechLevel[teamID]) then
    UpdateMorphReqs(teamID)
  end
end


function gadget:UnitDestroyed(unitID, unitDefID, teamID)
  if (morphUnits[unitID]) then
    StopMorph(unitID,morphUnits[unitID])
    morphUnits[unitID] = nil
  end
  local bfrTechLevel = teamTechLevel[teamID] or 0

  RemoveFactory(unitID, unitDefID, teamID)

  local updateButtons = false
  if (reqTechs[unitDefID])and(isFinished(unitID)) then
    local teamReq = morphableUnits[teamID]
    -- Reduces 1 from amount of required units found
    teamReq[unitDefID] = (teamReq[unitDefID] or 0) - 1
    if (teamReq[unitDefID]==0) then
      StopMorphsOnDevolution(teamID)
      updateButtons = true
    end
  end

  if (bfrTechLevel~=teamTechLevel[teamID]) then
    StopMorphsOnDevolution(teamID)
    updateButtons = true
  end

  if (updateButtons) then UpdateMorphReqs(teamID) end
end


function gadget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
  self:UnitCreated(unitID, unitDefID, teamID)
  if (isFinished(unitID)) then
    self:UnitFinished(unitID, unitDefID, teamID)
  end
end


function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
  self:UnitDestroyed(unitID, unitDefID, oldTeamID)
end


function UnitRanked(unitID,unitDefID,teamID,newRank,oldRank)
  local morphDefSet = morphDefs[unitDefID]

  if (morphDefSet) then
    local teamTech = teamTechLevel[teamID] or 0
    local unitXP   = Spring.GetUnitExperience(unitID)
    for _, morphDef in pairs(morphDefSet) do
      if (morphDef) then
        local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
        if (cmdDescID) then
          local morphCmdDesc = {}
          local teamReqTechs = TechReqList(teamID,morphDef.require)
          local teamHasTechs = teamReqTechs and #teamReqTechs == 0

          morphCmdDesc.disabled = (morphDef.tech > teamTech) or (morphDef.rank > newRank)
                                  or (morphDef.xp > unitXP) or (not teamHasTechs)
          morphCmdDesc.tooltip  = GetMorphToolTip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, newRank, teamReqTechs)
          Spring.EditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)
        end
      end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function AddFactory(unitID, unitDefID, teamID)
  if (isFactory(unitDefID)) then
    local unitTechLevel = GetTechLevel(unitDefID)
    if (unitTechLevel > teamTechLevel[teamID]) then
      teamTechLevel[teamID]=unitTechLevel
    end
  end
end


function RemoveFactory(unitID, unitDefID, teamID)
  if (devolution)and(isFactory(unitDefID))and(isFinished(unitID)) then

    --// check all factories and determine team level
    local level = 0
    local teamUnits = Spring.GetTeamUnits(teamID)
    for i=1,#teamUnits do
      local unitID2 = teamUnits[i]
      if (unitID2 ~= unitID) then
        local unitDefID2 = Spring.GetUnitDefID(unitID2)
        if (isFactory(unitDefID2) and isFinished(unitID2)) then
          local unitTechLevel = GetTechLevel(unitDefID2)
          if (unitTechLevel>level) then level = unitTechLevel end
        end
      end
    end

    if (level ~= teamTechLevel[teamID]) then
      teamTechLevel[teamID] = level
    end

  end
end

function StopMorphsOnDevolution(teamID)
  if (stopMorphOnDevolution) then
    for unitID, morphData in pairs(morphUnits) do
      local morphDef = morphData.def
      if (morphData.teamID == teamID)and
         (
           (morphDef.tech>teamTechLevel[teamID])or
           (not TechReqCheck(teamID, morphDef.require))
         )
      then
        StopMorph(unitID, morphData)
      end
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GameFrame(n)

  --if n == startFrame then

  --end

  if ((n+24)%150<1) then
    --AddCustomMorphDefs()

    local unitCount = #XpMorphUnits
    local i = 1

    while (i<=unitCount) do
      local unitdata    = XpMorphUnits[i]
      local unitID      = unitdata.id
      local unitDefID   = unitdata.defID

      local morphDefSet = morphDefs[unitDefID]
      if (morphDefSet) then
        local teamID   = unitdata.team
        local teamTech = teamTechLevel[teamID] or 0
        local unitXP   = Spring.GetUnitExperience(unitID)
        local unitRank = GetUnitRank(unitID)

        local xpMorphLeft = false
        for _,morphDef in pairs(morphDefSet) do
          if (morphDef) then
            local cmdDescID = Spring.FindUnitCmdDesc(unitID, morphDef.cmd)
            if (cmdDescID) then
              local morphCmdDesc = {}
              local teamOwnsReqUnit = TechReqList(teamID, morphDef.require)
              morphCmdDesc.disabled = (morphDef.tech > teamTech)or(morphDef.rank > unitRank)or(morphDef.xp > unitXP)or(not teamOwnsReqUnit)
              morphCmdDesc.tooltip  = GetMorphToolTip(unitID, unitDefID, teamID, morphDef, teamTech, unitXP, unitRank, teamOwnsReqUnit)
              Spring.EditUnitCmdDesc(unitID, cmdDescID, morphCmdDesc)

              xpMorphLeft = morphCmdDesc.disabled or xpMorphLeft
            end
          end
        end
        if (not xpMorphLeft) then
          --// remove unit in list (it fullfills all xp requirements)
          XpMorphUnits[i] = XpMorphUnits[unitCount]
          XpMorphUnits[unitCount] = nil
          unitCount = unitCount - 1
          i = i - 1
        end
      end
      i = i + 1

    end
  end

  for unitID, morphData in pairs(morphUnits) do
    if (not UpdateMorph(unitID, morphData)) then
      morphUnits[unitID] = nil
    end
  end
end

local function handleEzMorph(unitID, unitDefID, teamID, targetDefID)
	local morphData = morphUnits[unitID]
	if morphData then
		return true, false
	end
 	local morphSet = morphDefs[unitDefID]
	if not morphSet then
		return true, true
	end

	local validMorphs = {}
 	for morphCmd, morphDef in pairs(morphSet) do
		if (not targetDefID or morphDef.into == targetDefID)
		and MorphRequirementsFulfilled(unitID, morphDef, teamTechLevel[teamID] or 0, TechReqList(teamID, morphDef.require)) then
			validMorphs[#validMorphs+1] = morphDef
		end
	end

	if #validMorphs > 0 then
		StartMorph(unitID, unitDefID, teamID, validMorphs[math.random(1, #validMorphs)])
	end

 	return true, true
end

--// Allows or disallow the morph command button
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
  local morphData = morphUnits[unitID]
  if cmdID == CMD_EZ_MORPH and isFactory(unitDefID) then
    handleEzMorph(unitID, unitDefID, teamID, cmdParams[1])
    return false
  end
  if (morphData) then
    if (cmdID==morphData.def.stopCmd)or(cmdID == CMD.STOP) then
	  if not Spring.GetUnitTransporter(unitID) then
        StopMorph(unitID, morphData)
        morphUnits[unitID] = nil
        return false
	  end
    elseif (cmdID == CMD.ONOFF) then
      return false
	elseif cmdID == CMD.SELFD then
	  StopMorph(unitID, morphData)
      morphUnits[unitID] = nil
    --else --// disallow ANY command to units in morph
    --  return false
    end
  elseif (cmdID >= CMD_MORPH and cmdID < CMD_MORPH+MAX_MORPH) then
    local morphDef = (morphDefs[unitDefID] or {})[cmdID] or extraUnitMorphDefs[unitID]
    if ( (morphDef)and
         (morphDef.tech<=teamTechLevel[teamID])and
         (morphDef.rank<=GetUnitRank(unitID))and
         (morphDef.xp<=Spring.GetUnitExperience(unitID))and
         (TechReqCheck(teamID, morphDef.require)) )
    then
      if (isFactory(unitDefID)) then
        --// the factory cai is broken and doesn't call CommandFallback(),
        --// so we have to start the morph here
        StartMorph(unitID, unitDefID, teamID, morphDef)
        return false
      else
        return true
      end
    end
    return false
  end

  return true
end

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
  if cmdID == CMD_EZ_MORPH then
    return handleEzMorph(unitID, unitDefID, teamID, cmdParams[1])
  end
  if (cmdID < CMD_MORPH or cmdID >= CMD_MORPH+MAX_MORPH) then
    return false  --// command was not used
  end
  local morphDef = (morphDefs[unitDefID] or {})[cmdID] or extraUnitMorphDefs[unitID]
  if (not morphDef) then
    return true, true  --// command was used, remove it
  end
  local morphData = morphUnits[unitID]
  if (not morphData) then
    StartMorph(unitID, unitDefID, teamID, morphDef)
    return true, true
  end
  return true, false  --// command was used, do not remove it
end



--------------------------------------------------------------------------------
--  END SYNCED
--------------------------------------------------------------------------------
else
--------------------------------------------------------------------------------
--  UNSYNCED
--------------------------------------------------------------------------------

--// 75b2 compability (removed it in the next release)
if (Spring.GetTeamColor==nil) then
  Spring.GetTeamColor = function(teamID) local _,_,_,_,_,_,r,g,b = Spring.GetTeamInfo(teamID); return r,g,b end
end

--
-- speed-ups
--

local gameFrame;
local SYNCED = SYNCED
local CallAsTeam = CallAsTeam

local GetUnitTeam         = Spring.GetUnitTeam
local GetUnitHeading      = Spring.GetUnitHeading
local GetUnitBasePosition = Spring.GetUnitBasePosition
local GetGameFrame        = Spring.GetGameFrame
local GetSpectatingState  = Spring.GetSpectatingState
local AddWorldIcon        = Spring.AddWorldIcon
local AddWorldText        = Spring.AddWorldText
local IsUnitVisible       = Spring.IsUnitVisible
local GetLocalTeamID      = Spring.GetLocalTeamID
local spAreTeamsAllied    = Spring.AreTeamsAllied
local spGetGameFrame      = Spring.GetGameFrame

local glBillboard    = gl.Billboard
local glColor        = gl.Color
local glPushMatrix   = gl.PushMatrix
local glTranslate    = gl.Translate
local glRotate       = gl.Rotate
local glUnitShape    = gl.UnitShape
local glPopMatrix    = gl.PopMatrix
local glText         = gl.Text
local glPushAttrib   = gl.PushAttrib
local glPopAttrib    = gl.PopAttrib
local glBlending     = gl.Blending
local glDepthTest    = gl.DepthTest

local GL_LEQUAL      = GL.LEQUAL
local GL_ONE         = GL.ONE
local GL_SRC_ALPHA   = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_COLOR_BUFFER_BIT = GL.COLOR_BUFFER_BIT

local headingToDegree = (360 / 65535)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local useLuaUI = false
local oldFrame = 0        --//used to save bandwidth between unsynced->LuaUI
local drawProgress = true --//a widget can do this job too (see healthbars)

local morphUnits

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--//synced -> unsynced actions

local function SelectSwap(cmd, oldID, newID)
  local selUnits = Spring.GetSelectedUnits()
  for i=1,#selUnits do
    local unitID = selUnits[i]
    if (unitID == oldID) then
      selUnits[i] = newID
      Spring.SelectUnitArray(selUnits)
      break
    end
  end


  if (Script.LuaUI('MorphFinished')) then
    if (useLuaUI) then
      local readTeam, spec, specFullView = nil,GetSpectatingState()
      if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
      CallAsTeam({ ['read'] = readTeam }, function()
        if (IsUnitVisible(oldID)) then
          Script.LuaUI.MorphFinished(oldID,newID)
        end
      end)
    end
  end

  return true
end

local function StartMorph(cmd, unitID, unitDefID, morphID)
  if (Script.LuaUI('MorphStart')) then
    if (useLuaUI) then
      local readTeam, spec, specFullView = nil,GetSpectatingState()
      if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
      CallAsTeam({ ['read'] = readTeam }, function()
        if (unitID)and(IsUnitVisible(unitID)) then
          Script.LuaUI.MorphStart(unitID, (SYNCED.morphDefs[unitDefID] or {})[morphID] or SYNCED.extraUnitMorphDefs[unitID])
        end
      end)
    end
  end
  return true
end

local function StopMorph(cmd, unitID)
  if (Script.LuaUI('MorphStop')) then
    if (useLuaUI) then
      local readTeam, spec, specFullView = nil,GetSpectatingState()
      if (specFullView)
        then readTeam = Script.ALL_ACCESS_TEAM
        else readTeam = GetLocalTeamID() end
      CallAsTeam({ ['read'] = readTeam }, function()
        if (unitID)and(IsUnitVisible(unitID)) then
          Script.LuaUI.MorphStop(unitID)
        end
      end)
    end
  end
  return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
  gadgetHandler:AddSyncAction("unit_morph_finished", SelectSwap)
  gadgetHandler:AddSyncAction("unit_morph_start", StartMorph)
  gadgetHandler:AddSyncAction("unit_morph_stop", StopMorph)

  --startFrame = spGetGameFrame()
end


function gadget:Shutdown()
  gadgetHandler:RemoveSyncAction("unit_morph_finished")
  gadgetHandler:RemoveSyncAction("unit_morph_start")
  gadgetHandler:RemoveSyncAction("unit_morph_stop")
end

function gadget:Update()
  local frame = spGetGameFrame()
  if (frame>oldFrame) then
    oldFrame = frame
    if next(SYNCED.morphUnits) then
      local useLuaUI_ = Script.LuaUI('MorphUpdate')
      if (useLuaUI_~=useLuaUI) then --//Update Callins on change
        drawProgress = not Script.LuaUI('MorphDrawProgress')
        useLuaUI     = useLuaUI_
      end

      if (useLuaUI) then
        local morphTable = {}
        local readTeam, spec, specFullView = nil,GetSpectatingState()
        if (specFullView)
          then readTeam = Script.ALL_ACCESS_TEAM
          else readTeam = GetLocalTeamID() end
        CallAsTeam({ ['read'] = readTeam }, function()
          for unitID, morphData in pairs(SYNCED.morphUnits) do
            if (unitID and morphData)and(IsUnitVisible(unitID)) then
              morphTable[unitID] = {progress=morphData.progress, into=morphData.def.into}
            end
          end
        end)
        Script.LuaUI.MorphUpdate(morphTable)
      end

    end
  end
end


local teamColors = {}
local function SetTeamColor(teamID,a)
  local color = teamColors[teamID]
  if (color) then
    color[4]=a
    glColor(color)
    return
  end
  local r, g, b = Spring.GetTeamColor(teamID)
  if (r and g and b) then
    color = { r, g, b }
    teamColors[teamID] = color
    glColor(color)
    return
  end
end


--//patchs an annoying popup the first time you morph a unittype(+team)
local alreadyInit = {}
local function InitializeUnitShape(unitDefID,unitTeam)
  local iTeam = alreadyInit[unitTeam]
  if (iTeam)and(iTeam[unitDefID]) then return end

  glPushMatrix()
  gl.ColorMask(false)
  gl.Scale(1.002,1.002,1.002)
  glUnitShape(unitDefID, unitTeam)
  gl.ColorMask(true)
  glPopMatrix()
  if (alreadyInit[unitTeam]==nil) then alreadyInit[unitTeam] = {} end
  alreadyInit[unitTeam][unitDefID] = true
end


local function DrawMorphUnit(unitID, morphData, localTeamID)
  local h = GetUnitHeading(unitID)
  if (h==nil) then
    return  --// bonus, heading is only available when the unit is in LOS
  end
  local px,py,pz = GetUnitBasePosition(unitID)
  if (px==nil) then
    return
  end
  local unitTeam = morphData.teamID

  InitializeUnitShape(morphData.def.into,unitTeam) --BUGFIX

  local frac = ((gameFrame + unitID) % 30) / 30
  local alpha = 2.0 * math.abs(0.5 - frac)
  local angle
  if morphData.def.facing then
    angle = -HeadingToFacing(h) * 90 + 180
  else
    angle = h * headingToDegree
  end

  SetTeamColor(unitTeam,alpha)
  glPushMatrix()
  glTranslate(px, py, pz)
  glRotate(angle, 0, 1, 0)
  gl.Scale(1.002,1.002,1.002)
  glUnitShape(morphData.def.into, unitTeam)
  glPopMatrix()

  --// cheesy progress indicator
  if (drawProgress)and(localTeamID)and
     ( (spAreTeamsAllied(unitTeam,localTeamID)) or (localTeamID==Script.ALL_ACCESS_TEAM) )
  then
    glPushMatrix()
    glPushAttrib(GL_COLOR_BUFFER_BIT)
    glTranslate(px, py+14, pz)
    glBillboard()
    local progStr = string.format("%.1f%%", 100 * morphData.progress)
    gl.Text(progStr, 0, -65, 24, "oc")
    glPopAttrib()
    glPopMatrix()
  end
end


function gadget:DrawWorld()
  if (not next(SYNCED.morphUnits)) then
    return --//no morphs to draw
  end

  gameFrame = GetGameFrame()

  glBlending(GL_SRC_ALPHA, GL_ONE)
  glDepthTest(GL_LEQUAL)

  local spec, specFullView = GetSpectatingState()
  local readTeam
  if (specFullView) then
    readTeam = Script.ALL_ACCESS_TEAM
  else
    readTeam = GetLocalTeamID()
  end

  CallAsTeam({ ['read'] = readTeam }, function()
    for unitID, morphData in pairs(SYNCED.morphUnits) do
      if (unitID and morphData)and(IsUnitVisible(unitID)) then
        DrawMorphUnit(unitID, morphData,readTeam)
      end
    end
  end)
  glDepthTest(false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end



--------------------------------------------------------------------------------
--  UNSYNCED
--------------------------------------------------------------------------------
end
--------------------------------------------------------------------------------
--  COMMON
--------------------------------------------------------------------------------
