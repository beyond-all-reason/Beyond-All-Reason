-- $Id: lups_nano_spray.lua 3171 2008-11-06 09:06:29Z det $
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "LupsNanoLasers",
    desc      = "Wraps the nano spray to LUPS",
    author    = "jK",
    date      = "2008-2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

local builderWorkTime = {}
local min, max = 5000,0
for uDefID, uDef in pairs(UnitDefs) do
  if uDef.isBuilder then
    local buildSpeed = uDef.buildSpeed or 220
    if buildSpeed > max then max = buildSpeed end
    if buildSpeed < min then max = buildSpeed end

    local OldMax, OldMin, NewMax, NewMin = 220,5000,0.2,2.2
    local OldRange = (OldMax - OldMin)
    local NewRange = (NewMax - NewMin)
    buildSpeed = (((buildSpeed - OldMin) * NewRange) / OldRange) + NewMin
    --Spring.Echo(uDef.name, uDef.buildSpeed,value)
    builderWorkTime[uDefID] = buildSpeed
  end
end

local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitCurrentCommand    = Spring.GetUnitCurrentCommand

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
        local tag = select(3, spGetUnitCurrentCommand(unitID))
        if tag then
            cmdTag = tag
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

    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

    --// Speed-ups
    local GetUnitRadius        = Spring.GetUnitRadius
    local GetFeatureRadius     = Spring.GetFeatureRadius
    local spGetFeatureDefID    = Spring.GetFeatureDefID
    local spGetGameFrame       = Spring.GetGameFrame
    local spIsUnitInView       = Spring.IsUnitInView

    local type  = type
    local pairs = pairs

    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

    local hideIfIcon = Spring.GetConfigInt("NanoLaserIcon", 0)
    if hideIfIcon == 1 then
        hideIfIcon = false
    else
        hideIfIcon = true
    end

    local myPlayerID = Spring.GetMyPlayerID()
    function gadget:GotChatMsg(msg, playerID)
        if playerID == myPlayerID and string.sub(msg,1,15) == "uniticonlasers " then
            local value = string.sub(msg,16)
            if value == '1' then
                hideIfIcon = false
                Spring.SetConfigInt("NanoLaserIcon", 1)
            else
                hideIfIcon = true
                Spring.SetConfigInt("NanoLaserIcon", 0)
            end
        end
    end

    if (not GetFeatureRadius) then
      GetFeatureRadius = function(featureID)
        local fDefID = spGetFeatureDefID(featureID)
        return (FeatureDefs[fDefID].radius or 0)
      end
    end



    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --
    --   some basic functions
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
    --   handling
    --

    local currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
    local maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 6) or 6)    -- limit for performance reasons

    local nanoParticles = {}
    --local maxEngineParticles = Spring.GetConfigInt("MaxNanoParticles", 10000)

    local NanoFxNone = 2

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

    -- update (position) more frequently for air builders
    local airBuilders = {}
    for udid, unitDef in pairs(UnitDefs) do
        if unitDef.canFly then
            airBuilders[udid] = true
        end
    end


    local nanoParams = {
        fxtype          = 'nanolasers',
        corealpha       = 0.33,
        priority        = 1,

        alpha           = 0.002,
        corethickness   = 0.003,
        streamSpeed     = 0.1,
    }

    function gadget:GameFrame(frame)
        if currentNanoEffect == NanoFxNone then return end

        local updateFramerate = math.min(30, 2 + math.floor(#builders/35)) -- update fast at gamestart and gradually slower
        local totalNanoEmitters = 0
        local myTeamID = Spring.GetMyTeamID()
        local _, myFullview = Spring.GetSpectatingState()
        for i=1,#builders do
            if totalNanoEmitters > maxNewNanoEmitters then
                break
            end
            local unitID = builders[i]
            if ((not hideIfIcon and (myFullview or Spring.GetMyAllyTeamID() == Spring.GetUnitAllyTeam(unitID))) or (not Spring.IsUnitIcon(unitID)) and CallAsTeam(myTeamID, spIsUnitInView, unitID))  then
                local UnitDefID = Spring.GetUnitDefID(unitID)
                local buildpower = builderWorkTime[UnitDefID] or 1
                if ((unitID + frame) % updateFramerate < 1) then
                    local strength = ((Spring.GetUnitCurrentBuildPower(unitID)or 1)*buildpower) or 1	-- * 16
                    --Spring.Echo(strength,Spring.GetUnitCurrentBuildPower(unitID)*builderWorkTime[UnitDefID])
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

                            --local terraform = false
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
                            local teamColor = {Spring.GetTeamColor(teamID)}
                            local nanoPieces = Spring.GetUnitNanoPieces(unitID) or {}
                            totalNanoEmitters = totalNanoEmitters + #nanoPieces
                            if totalNanoEmitters > maxNewNanoEmitters then
                                break
                            end
                            local nanoPieceID
                            for j=1,#nanoPieces do
                                nanoPieceID = nanoPieces[j]
                                --local nanoPieceIDAlt = Spring.GetUnitScriptPiece(unitID, nanoPieceID)
                                --if (unitID+frame)%60 == 0 then
                                --	Spring.Echo("Nanopiece nums (output)", j, UnitDefs[unitDefID].name, nanoPieceID, nanoPieceIDAlt)
                                --end
                                nanoParams.targetID     = target
                                nanoParams.isFeature    = isFeature
                                nanoParams.unitpiece    = nanoPieceID
                                nanoParams.unitID       = unitID
                                nanoParams.unitDefID    = unitDefID
                                nanoParams.teamID       = teamID
                                nanoParams.allyID       = allyID
                                nanoParams.nanopiece    = nanoPieceID
                                nanoParams.targetpos    = endpos
                                nanoParams.count        = strength*30
                                nanoParams.streamThickness = 2.9 + strength * 0.25
                                nanoParams.color        = teamColor
                                nanoParams.type         = type
                                nanoParams.targetradius = radius
                                nanoParams.cmdTag       = cmdTag --//used to end the fx when the command is finished
                                nanoParams.quickupdates = airBuilders[UnitDefID] and true or false
                                nanoParams.inversed     = inversed

                                if (not nanoParticles[unitID]) then nanoParticles[unitID] = {} end
                                if Lups then
                                    nanoParticles[#nanoParticles[unitID]+1] = Lups.AddParticles(nanoParams.fxtype,nanoParams)
                                end
                            end
                        end
                    end
                end
            end
        end --//for
        --Spring.Echo(frame..'  '..totalNanoEmitters)
    end


    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

    function init()
        if currentNanoEffect == NanoFxNone then
            registeredBuilders = {}
            return
        end

        for _,unitID in ipairs(Spring.GetAllUnits()) do
            local unitDefID = Spring.GetUnitDefID(unitID)
            gadget:UnitFinished(unitID, unitDefID)
        end
    end

    function gadget:Update()
      if (spGetGameFrame()<1) then
        return
      end

        if initialized then
            --// enable particle effect?
            maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 6) or 6)
            if currentNanoEffect ~= (Spring.GetConfigInt("NanoEffect",1) or 1) then
                currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
                init()
            end
            return
        end
      --gadgetHandler:RemoveCallIn("Update")

      Lups = GG['Lups']
      if (Lups) then
          maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 6) or 6)
          currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
          init()
        initialized=true
      end

    end

    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

    local registeredBuilders = {}

    function gadget:UnitFinished(uid, udid)
        if currentNanoEffect == NanoFxNone then return end
        if (UnitDefs[udid].isBuilder) and not registeredBuilders[uid] then
            BuilderFinished(uid)
            registeredBuilders[uid] = nil
        end
    end

    function gadget:UnitDestroyed(uid, udid)
        if currentNanoEffect == NanoFxNone then return end
        if (UnitDefs[udid].isBuilder) and registeredBuilders[uid] then
            BuilderDestroyed(uid)
            registeredBuilders[uid] = nil
        end
    end

end
