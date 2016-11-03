-- $Id: lups_nano_spray.lua 3171 2008-11-06 09:06:29Z det $
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "LupsNanoSpray",
    desc      = "Wraps the nano spray to LUPS",
    author    = "jK",
    date      = "2008-2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end


local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetCommandQueue    = Spring.GetCommandQueue

local function GetCmdTag(unitID) 
    local cmdTag = 0
    local cmds = spGetFactoryCommands(unitID,1)
	if (cmds) then
		local cmd = cmds[1]
		if cmd then
			cmdTag = cmd.tag
		end
	end
	if cmdTag == 0 then 
		local cmds = spGetCommandQueue(unitID,1)
		if (cmds) then
			local cmd = cmds[1]
			if cmd then
				cmdTag = cmd.tag
			end
        end
	end 
	return cmdTag
end 
	

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
  --// bw-compability
  local alreadyWarned = 0
  local function WarnDeprecated()
	if (alreadyWarned<10) then
		alreadyWarned = alreadyWarned + 1
		Spring.Log("LUPS", LOG.WARNING, "LUS/COB: QueryNanoPiece is deprecated! Use Spring.SetUnitNanoPieces() instead!")
	end
  end

  function gadget:Initialize()
	GG.LUPS = GG.LUPS or {}
	GG.LUPS.QueryNanoPiece = WarnDeprecated
	gadgetHandler:RegisterGlobal("QueryNanoPiece", WarnDeprecated)
  end

  function gadget:Shutdown()
	gadgetHandler:DeregisterGlobal("QueryNanoPiece")
  end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
else
------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local Lups  --// Lua Particle System
local initialized = false --// if LUPS isn't started yet, we try it once a gameframe later
local tryloading  = 1     --// try to activate lups if it isn't found

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

--// Speed-ups
local GetUnitRadius        = Spring.GetUnitRadius
local GetFeatureRadius     = Spring.GetFeatureRadius
local spGetFeatureDefID    = Spring.GetFeatureDefID
local spGetTeamColor       = Spring.GetTeamColor
local spGetGameFrame       = Spring.GetGameFrame

local type  = type
local pairs = pairs

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not GetFeatureRadius) then
  GetFeatureRadius = function(featureID)
    local fDefID = spGetFeatureDefID(featureID)
    return (FeatureDefs[fDefID].radius or 0)
  end
end


local function SetTable(table,arg1,arg2,arg3,arg4)
  table[1] = arg1
  table[2] = arg2
  table[3] = arg3
  table[4] = arg4
end


local function CopyTable(outtable,intable)
  for i,v in pairs(intable) do 
    if (type(v)=='table') then
      if (type(outtable[i])~='table') then outtable[i] = {} end
      CopyTable(outtable[i],v)
    else
      outtable[i] = v
    end
  end
end


local function CopyMergeTables(table1,table2)
  local ret = {}
  CopyTable(ret,table2)
  CopyTable(ret,table1)
  return ret
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  «« some basic functions »»
--

local supportedFxs = {}
local function fxSupported(fxclass)
  if (supportedFxs[fxclass]~=nil) then
    return supportedFxs[fxclass]
  else
    supportedFxs[fxclass] = Lups.HasParticleClass(fxclass)
    return supportedFxs[fxclass]
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Lua StrFunc parsing and execution
--

local loadstring = loadstring
local pcall = pcall
local function ParseLuaStrFunc(strfunc)
  local luaCode = [[
    return function(count,inversed)
      local limcount = (count/6)
            limcount = limcount/(limcount+1)
      return ]] .. strfunc .. [[
    end
  ]]

  local luaFunc = loadstring(luaCode)
  local success,ret = pcall(luaFunc)

  if (success) then
    return ret
  else
    Spring.Echo("LUPS(NanoSpray): parsing error in user function: \n" .. ret)
    return function() return 0 end
  end
end

local function ParseLuaCode(t)
  for fxname,fxparams in pairs(t) do
	  for i,v in pairs(fxparams) do
	    if (type(v)=="string")and(i~="texture")and(i~="fxtype") then
	      t[fxname][i] = ParseLuaStrFunc(v)
	    end
    end
  end
end

local function ExecuteLuaCode(t)
  for fxname,fxparams in pairs(t) do
	  for i,v in pairs(fxparams) do
	    if (type(v)=="function") then
	      t[fxname][i]=v(fxparams.count,fxparams.inversed)
	    end
	  end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  «« NanoSpray handling »»
--

local maxEngineParticles = Spring.GetConfigInt("MaxNanoParticles", 20000)

local function GetFaction(udid)
  --local udef_factions = UnitDefs[udid].factions or {}
  --return ((#udef_factions~=1) and 'unknown') or udef_factions[1]
  return "default" -- default 
end

local function SetParticleDefinitions()
	factionsNanoFx = {
	  default = {
	  	laser = {
		    fxtype          = "NanoLasers",
		    alpha           = "0.2+count/30",
		    corealpha       = "0.2+count/120",
		    corethickness   = "limcount",
		    streamThickness = "0.5+5*limcount",
		    streamSpeed     = "limcount*0.05",
	    }
	  },
	  default_high_quality = {
	  	cloud = {
		    fxtype      = "NanoParticles",
		    alpha       = 0.115,
		    size        = 7,
		    sizeSpread  = 6,
		    sizeGrowth  = 0.29,
		    rotSpeed    = "math.random(1)/2",
		    rotSpread   = 360,
		    texture     = "bitmaps/Other/Poof.png",
		    particles   = 2.8,
	    },
	  	cloud2 = {
		    fxtype      = "NanoParticles",
		    alpha       = 0.08,
		    size        = 3.5,
		    sizeSpread  = 2.7,
		    sizeGrowth  = 0.26,
		    rotSpeed    = "math.random(1)/2",
		    rotSpread   = 360,
		    texture     = "bitmaps/Other/Poof.png",
		    particles   = 1.4,
		    color				= {0,0,0}
	    },
	    energypart = {
		    fxtype      = "NanoParticles",
		    alpha       = "0.22+math.random(1)/4",
		    size        = 0.5,
		    sizeSpread  = 1.1,
		    sizeGrowth  = 0.035,
		    rotSpeed    = "math.random(1)/2",
		    rotSpread   = 360,
		    particles   = "math.random(1)/2.5",
		    color       = {1,1,1}
		  },
	    energypart2 = {
		    fxtype      = "NanoParticles",
		    alpha       = "0.2+math.random(1)/3.5",
		    size        = 0.5,
		    sizeSpread  = 1.35,
		    sizeGrowth  = 0.05,
		    rotSpeed    = "math.random(1)/1.5",
		    rotSpread   = 360,
		    particles   = "math.random(1)*2.5",
		    texture     = "bitmaps/projectiletextures/flashcrap.png",
		    color       = {1,1,1}
		  },
	    energypart3 = {
		    fxtype      = "NanoParticles",
		    alpha       = 0.32,
		    size        = 5.2,
		    sizeSpread  = 3,
		    sizeGrowth  = 0.12,
		    rotSpeed    = "math.random(1)/2.2",
		    rotSpread   = 360,
		    particles   = "math.random(1)/3",
		    texture     = "bitmaps/projectiletextures/randdots.tga",
		    color       = {1,1,1}
		  },
		}
	}
	if (currentDate ~= nil and tonumber(string.sub(currentDate, 5, 6)) == 12 and tonumber(string.sub(currentDate, 7, 8)) >= 19) then
		factionsNanoFx.default_high_quality.energypart = nil
		local xmas = {
	    fxtype      = "NanoParticles",
	    alpha       = "0.2+(math.random(1)/2.5)",
	    size        = 1,
	    sizeSpread  = 5,
	    sizeGrowth  = 0.035,
	    rotSpeed    = "0.3+math.random(1)/1.3",
	    rotSpread   = 360,
	    particles   = "math.random(1)/10",
	    color       = {1,1,1},
	    texture     = "bitmaps/xmas/star.png",
	  }
		factionsNanoFx.default_high_quality.xmas1 = deepcopy(xmas)
		factionsNanoFx.default_high_quality.xmas1.texture = "bitmaps/xmas/mistletoe.png"
		factionsNanoFx.default_high_quality.xmas1.particles = "math.random(1)/10"
		factionsNanoFx.default_high_quality.xmas2 = deepcopy(xmas)
		factionsNanoFx.default_high_quality.xmas2.texture = "bitmaps/xmas/hat.png"
		factionsNanoFx.default_high_quality.xmas2.particles = "math.random(1)/14"
		factionsNanoFx.default_high_quality.xmas3 = deepcopy(xmas)
		factionsNanoFx.default_high_quality.xmas3.texture = "bitmaps/xmas/ball.png"
		factionsNanoFx.default_high_quality.xmas3.particles = "math.random(1)/12"
		factionsNanoFx.default_high_quality.xmas4 = deepcopy(xmas)
		factionsNanoFx.default_high_quality.xmas4.texture = "bitmaps/xmas/star.png"
		factionsNanoFx.default_high_quality.xmas4.particles = "math.random(1)/7"
		factionsNanoFx.default_high_quality.xmas5 = deepcopy(xmas)
		factionsNanoFx.default_high_quality.xmas5.texture = "bitmaps/xmas/cane.png"
		factionsNanoFx.default_high_quality.xmas5.particles = "math.random(1)/22"
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local builders = {}

local function BuilderFinished(unitID)
	builders[#builders+1] = unitID
end

local function BuilderDestroyed(unitID)
	for i=1,#builders do
		if (builders[i] == unitID) then
			builders[i] = builders[#builders]
		end
	end
	builders[#builders] = nil
end

function gadget:GameFrame(frame)
	for i=1,#builders do
		local unitID = builders[i]
		if ((unitID + frame) % 20 < 1) then --// only update once per second
			local strength = (Spring.GetUnitCurrentBuildPower(unitID) or 0)*(Spring.GetUnitRulesParam(unitID, "totalEconomyChange") or 1)	-- * 16
			if (strength > 0) then
				local type, target, isFeature = Spring.Utilities.GetUnitNanoTarget(unitID)

				if (target) then
					local endpos
					local radius = 30
					if (type=="restore") then
						endpos = target
						radius = target[4]
						target = -1
					elseif (not isFeature) then
						radius = (GetUnitRadius(target) or 1) * 0.80
					else
						radius = (GetFeatureRadius(target) or 1) * 0.80
					end

					local terraform = false
					local inversed  = false
					if (type=="restore") then
						terraform = true
					elseif (type=="reclaim") then
						inversed  = true
					end

					--[[
					if (type=="reclaim") and (strength > 0) then
						--// reclaim is done always at full speed
						strength = 1
					end
					]]--

					local cmdTag = GetCmdTag(unitID)
					local teamID = Spring.GetUnitTeam(unitID)
					local allyID = Spring.GetUnitAllyTeam(unitID)
					local unitDefID = Spring.GetUnitDefID(unitID)
					local faction = GetFaction(unitDefID)
					local teamColor = {Spring.GetTeamColor(teamID)}
					local nanoPieces = Spring.GetUnitNanoPieces(unitID) or {}
					
					for j=1,#nanoPieces do
						local nanoPieceID = nanoPieces[j]
						--local nanoPieceIDAlt = Spring.GetUnitScriptPiece(unitID, nanoPieceID)
						--if (unitID+frame)%60 == 0 then
						--	Spring.Echo("Nanopiece nums (output)", j, UnitDefs[unitDefID].name, nanoPieceID, nanoPieceIDAlt)
						--end
						local nanoParams = {
							targetID     = target,
							isFeature    = isFeature,
							unitpiece    = nanoPieceID,
							unitID       = unitID,
							unitDefID    = unitDefID,
							teamID       = teamID,
							allyID       = allyID,
							nanopiece    = nanoPieceID,
							targetpos    = endpos,
							count        = strength * 20,
							color        = teamColor,
							type         = type,
							targetradius = radius,
							terraform    = terraform,
							inversed     = inversed,
							cmdTag       = cmdTag, --//used to end the fx when the command is finished
							life = 60,
						}
						local nanoSettings = deepcopy(factionsNanoFx[faction] or factionsNanoFx.default)
						for fxname, fxparams in pairs(nanoSettings) do
							nanoSettings[fxname] = CopyMergeTables(fxparams, nanoParams)
						end
						ExecuteLuaCode(nanoSettings)
						if Lups then
							for fxname, fxparams in pairs(nanoSettings) do
								--if not inversed or (inversed and string.sub(fxname, 1, 4) ~= 'xmas') then
									Lups.AddParticles(fxparams.fxtype, fxparams)
								--end
							end
						end
					end
				end
			end
		end

	end --//for
end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:Update()
  if (spGetGameFrame()<1) then 
    return
  end

  gadgetHandler:RemoveCallIn("Update")

  Lups = GG['Lups']

  if (Lups) then
    initialized=true
  else
    return
  end

  --// enable freaky arm nano fx when quality>3
  if ((Lups.Config["quality"] or 3) >= 3) then
    factionsNanoFx.default = factionsNanoFx["default_high_quality"]
  end

  --// init user custom nano fxs
  for faction,fx in pairs(Lups.Config or {}) do
    if (fx and (type(fx)=='table')) then
	    for fxname, fxparams in pairs(fx) do
	    	if fxparams.fxtype then
		      local fxType = fxparams.fxtype 
		      local fxSettings = fxparams

		      if (fxType)and
		         ((fxType:lower()=="nanolasers")or
		          (fxType:lower()=="nanoparticles"))and
		         (fxSupported(fxType))and
		         (fxSettings)
		      then
		        factionsNanoFx[faction][fxname] = fxSettings
		      end
		    end
	    end
    end
  end
	
  for faction,fx in pairs(factionsNanoFx) do
    --if (not fxSupported(fx.fxtype or "noneNANO")) then
    --  factionsNanoFx[faction] = factionsNanoFx.default
    --end

    local factionNanoFx = factionsNanoFx[faction]
    for fxname, fxparams in pairs(factionNanoFx) do
	    factionNanoFx[fxname].delaySpread = 20
	    factionNanoFx[fxname].fxtype = factionNanoFx[fxname].fxtype:lower()
	    if ((Lups.Config["quality"] or 2)>=2)and((factionNanoFx[fxname].fxtype=="nanolasers")or(factionNanoFx[fxname].fxtype=="nanolasersshader")) then
	      factionNanoFx[fxname].flare = true
	    end
		end
    --// parse lua code in the table, so we can execute it later
    ParseLuaCode(factionNanoFx)
  end

end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local registeredBuilders = {}

function gadget:UnitFinished(uid, udid)
	if (UnitDefs[udid].isBuilder) and not registeredBuilders[uid] then
		BuilderFinished(uid)
		registeredBuilders[uid] = nil
	end
end

function gadget:UnitDestroyed(uid, udid)
	if (UnitDefs[udid].isBuilder) and registeredBuilders[uid] then
		BuilderDestroyed(uid)
		registeredBuilders[uid] = nil
	end
end

function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end
	
function gadget:Initialize()

	-- extract date from infolog
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = lines(infolog)
		for i, line in ipairs(fileLines) do
			if string.find(line, 'Recording demo to:') then
				currentDate = string.match(line, '([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])')
				break
			end
			if i == 500 then break end
		end
	end
	SetParticleDefinitions()
	
	for _,unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitFinished(unitID, unitDefID)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
end