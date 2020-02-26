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
    local spGetGameFrame             = Spring.GetGameFrame
    local spIsUnitInView             = Spring.IsUnitInView
    local spGetUnitIsBuilding        = Spring.GetUnitIsBuilding
    local spGetUnitDefID             = Spring.GetUnitDefID
    local spGetUnitCurrentCommand    = Spring.GetUnitCurrentCommand
    local spValidFeatureID           = Spring.ValidFeatureID
    local spValidUnitID              = Spring.ValidUnitID
    local spGetUnitSeparation        = Spring.GetUnitSeparation
    local spGetGroundHeight          = Spring.GetGroundHeight
    local spGetUnitAllyTeam          = Spring.GetUnitAllyTeam
    local spIsUnitIcon               = Spring.IsUnitIcon
    local spGetUnitCurrentBuildPower = Spring.GetUnitCurrentBuildPower
    local spGetUnitNanoPieces        = Spring.GetUnitNanoPieces
    local spGetUnitPosition          = Spring.GetUnitPosition
    local spGetFeaturePosition       = Spring.GetFeaturePosition
    local spGetFactoryCommands       = Spring.GetFactoryCommands

    local type  = type
    local pairs = pairs

    local myAllyTeamID = Spring.GetMyAllyTeamID()
    local myTeamID = Spring.GetMyTeamID()
    local _, fullview = Spring.GetSpectatingState()

    local gameMaxUnits = Game.maxUnits

    local CMD_REPAIR    = CMD.REPAIR
    local CMD_RECLAIM   = CMD.RECLAIM
    local CMD_RESTORE   = CMD.RESTORE
    local CMD_RESURRECT = CMD.RESURRECT
    local CMD_CAPTURE   = CMD.CAPTURE

    local resurrectedUnits = {}

    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

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
            builderWorkTime[uDefID] = {buildSpeed, uDef.buildDistance}
        end
    end

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
    
    function gadget:PlayerChanged(playerID)
        myAllyTeamID = Spring.GetMyAllyTeamID()
        myTeamID = Spring.GetMyTeamID()
        _, fullview = Spring.GetSpectatingState()
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

    function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
        if Spring.GetUnitRulesParam(unitID, "resurrected") ~= nil then
            resurrectedUnits[unitID] = true
        end
    end
    function gadget:UnitDestroyed(unitID, unitDefID, teamID)
        resurrectedUnits[unitID] = nil
    end

    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --
    --   handling
    --

    local currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
    local maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 10) or 10)    -- limit for performance reasons

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

    local lupsParticleType = 'nanolasers'
    local nanoParams = {
        layer           = 0,
        corealpha       = 0.33,
        alpha           = 0.002,
        corethickness   = 0.003,
        streamSpeed     = 0.1,
        life            = 30
    }
    local knownNanoParams = {}
    for key, value in pairs(nanoParams) do
        knownNanoParams[key] = value
    end


    local function IsFeatureInRange(unitID, featureID, range)
        range = range + 35 -- fudge factor
        local x,y,z = spGetFeaturePosition(featureID)
        local ux,uy,uz = spGetUnitPosition(unitID)
        return ((ux - x)*(ux - x) + (uz - z)*(uz - z)) <= range*range
    end

    local function IsGroundPosInRange(unitID, x, z, range)
        local ux,uy,uz = spGetUnitPosition(unitID)
        return ((ux - x)*(ux - x) + (uz - z)*(uz - z)) <= range*range
    end

    function getUnitNanoTarget(unitID)
        local targetType = ""
        local target
        local isFeature = false
        local inRange

        local cmdID, _, _, cmdParam1, cmdParam2, cmdParam3, cmdParam4, cmdParam5 = spGetUnitCurrentCommand(unitID, 1)
        local buildID = spGetUnitIsBuilding(unitID)

        -- after unit is resurrected the following cmd is 'build' instead of 'repair', the nanolaser doesnt show up and the (beam) lighting is off position and flickering as well
        -- while the code below doesnt make showing the laser yet, it does prevent the beam lighting off position glitch
        if buildID and cmdParam1 and resurrectedUnits[cmdParam1] then
            --buildID = false
            --cmdID = CMD_REPAIR
            return
        end

        if buildID then
            target = buildID
            targetType   = "building"
            inRange = true
        else
            local uDefID = spGetUnitDefID(unitID)
            local buildRange = builderWorkTime[uDefID] and builderWorkTime[uDefID][2] or 0
            if cmdID then

                if cmdID == CMD_RECLAIM then
                    --// anything except "#cmdParams = 1 or 5" is either invalid or discribes an area reclaim
                    if not cmdParam2 or cmdParam5 then
                        local id = cmdParam1
                        local unitID_ = id
                        local featureID = id - gameMaxUnits

                        if (featureID >= 0) then
                            if spValidFeatureID(featureID) then
                                target    = featureID
                                isFeature = true
                                targetType      = "reclaim"
                                inRange	= IsFeatureInRange(unitID, featureID, buildRange)
                            end
                        else
                            if spValidUnitID(unitID_) then
                                target = unitID_
                                targetType   = "reclaim"
                                inRange = spGetUnitSeparation(unitID, unitID_, true) <= buildRange+35
                            end
                        end
                    end

                elseif cmdID == CMD_REPAIR  then
                    local repairID = cmdParam1
                    if spValidUnitID(repairID) then
                        target = repairID
                        targetType   = "repair"
                        inRange = spGetUnitSeparation(unitID, repairID, true) <= buildRange+35
                    end

                elseif cmdID == CMD_RESTORE then
                    local x = cmdParam1
                    local z = cmdParam3
                    targetType   = "restore"
                    target = {x, spGetGroundHeight(x,z)+5, z, cmdParam4}
                    inRange = IsGroundPosInRange(unitID, x, z, buildRange)

                elseif cmdID == CMD_CAPTURE then
                    if (not cmdParam2)or(cmdParam5) then
                        local captureID = cmdParam1
                        if spValidUnitID(captureID) then
                            target = captureID
                            targetType   = "capture"
                            inRange = spGetUnitSeparation(unitID, captureID, true) <= buildRange+35
                        end
                    end

                elseif cmdID == CMD_RESURRECT then
                    local rezzID = cmdParam1 - gameMaxUnits
                    if spValidFeatureID(rezzID) then
                        target    = rezzID
                        isFeature = true
                        targetType      = "resurrect"
                        inRange	= IsFeatureInRange(unitID, rezzID, buildRange)
                    end

                end
            end
        end

        if inRange then
            return targetType, target, isFeature
        else
            return
        end
    end


    local updateFrameCount = 0
    local prevUpdateGameFrame = 0
    function gadget:Update()

        if spGetGameFrame() < 1 then
            return
        end

        if initialized then
            --// enable particle effect?
            maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 10) or 10)
            if currentNanoEffect ~= (Spring.GetConfigInt("NanoEffect",1) or 1) then
                currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
                init()
            end
            --return
        end
        --gadgetHandler:RemoveCallIn("Update")
        if not initialized then
            Lups = GG['Lups']
            if Lups then
                maxNewNanoEmitters = (Spring.GetConfigInt("NanoBeamAmount", 10) or 10)
                currentNanoEffect = (Spring.GetConfigInt("NanoEffect",1) or 1)
                init()
                initialized=true
            end
        end

        local frame = Spring.GetGameFrame()
        if frame == prevUpdateGameFrame then
            return
        end
        prevUpdateGameFrame = frame
        updateFrameCount = updateFrameCount + 1

        if currentNanoEffect == NanoFxNone then
            return
        end

        local updateFramerate = math.min(15, 2 + math.floor(#builders/50)) -- update fast at gamestart and gradually slower
        local totalNanoEmitters = 0
        for i=1,#builders do
            if totalNanoEmitters > maxNewNanoEmitters then
                break
            end
            local unitID = builders[i]
            if ((not hideIfIcon and (fullview or myAllyTeamID == spGetUnitAllyTeam(unitID))) or (not spIsUnitIcon(unitID)) and CallAsTeam(myTeamID, spIsUnitInView, unitID))  then
                local UnitDefID = spGetUnitDefID(unitID)
                local buildpower = builderWorkTime[UnitDefID] and builderWorkTime[UnitDefID][1] or 1
                if ((unitID + updateFrameCount) % updateFramerate < 1) then
                    local strength = ((spGetUnitCurrentBuildPower(unitID)or 1)*buildpower) or 1	-- * 16
                    --Spring.Echo(strength,spGetUnitCurrentBuildPower(unitID)*builderWorkTime[UnitDefID][1])
                    if (strength > 0) then
                        local targetType, target, isFeature = getUnitNanoTarget(unitID)
                        
                        if (target) then
                            local endpos
                            if type(target) == 'table' then
                                endpos = target
                                target = -1
                            end

                            --local terraform = false
                            --if (targetType=="restore") then
                            --    terraform = true
                            --end

                            --[[
                            if (targetType=="reclaim") and (strength > 0) then
                                --// reclaim is done always at full speed
                                strength = 1
                            end
                            ]]--

                            local cmdTag = GetCmdTag(unitID)
                            local nanoPieces = spGetUnitNanoPieces(unitID) or {}
                            totalNanoEmitters = totalNanoEmitters + #nanoPieces
                            if totalNanoEmitters > maxNewNanoEmitters then
                                break
                            end
                            local nanoPieceID
                            for j=1,#nanoPieces do
                                nanoPieceID = nanoPieces[j]
                                nanoParams.unitID       = unitID
                                nanoParams.nanopiece    = nanoPieceID
                                nanoParams.unitpiece    = nanoPieceID
                                nanoParams.cmdTag       = cmdTag --//used to end the fx when the command is finished

                                nanoParams.targetID     = target
                                nanoParams.isFeature    = isFeature
                                nanoParams.targetpos    = endpos
                                nanoParams.count        = strength*30
                                nanoParams.streamThickness = 2.9 + strength * 0.25
                                nanoParams.type         = targetType
                                nanoParams.inversed     = (targetType == "reclaim" and true or false)
                                if Lups then
                                    Lups.AddParticles(lupsParticleType,nanoParams)
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
            local unitDefID = spGetUnitDefID(unitID)
            gadget:UnitFinished(unitID, unitDefID)
        end
    end

    -------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------

    local registeredBuilders = {}

    function gadget:UnitFinished(uid, udid)
        if currentNanoEffect == NanoFxNone then return end
        if builderWorkTime[udid] and not registeredBuilders[uid] then
            BuilderFinished(uid)
            registeredBuilders[uid] = nil
        end
    end

    function gadget:UnitDestroyed(uid, udid)
        if currentNanoEffect == NanoFxNone then return end
        if builderWorkTime[udid] and registeredBuilders[uid] then
            BuilderDestroyed(uid)
            registeredBuilders[uid] = nil
        end
    end

end
