local UsedFrame = 0
local MouseButtonPressed = {
    [1] = false,
    [2] = false,
    [3] = false,
}
local PreviouslySelectedUnits = {}

function gadget:GetInfo()
	return {
		name 	= "GUI Sound Effects player",
		desc	= "Custom sound effects for your units!",
		author	= "Damgam",
		date	= "2021",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

CommandSoundEffects = {
    Move = "cmd-move-supershort",
    LineMove = "cmd-move-swoosh", -- not working yet
    Fight = "cmd-fight",
    LineFight = "cmd-fight", -- not working yet
    Build = "cmd-build",
    Guard = "cmd-guard",
    Reclaim = "cmd-reclaim",
    Resurrect = "cmd-rez3",
    Repair = "cmd-repair",
    Groupselect = "cmd-reclaim", -- not working yet
    Dgun = "cmd-dgun",
    Patrol = "cmd-fightxs",
    Repeat = "cmd-onoff",
    SetTarget = "cmd-settarget", -- not working yet
    Attack = "cmd-attack",
    SelfD = "cmd-selfd"
    --OnOff = "cmd-onoff",
}

DefaultSoundEffects = {
    BaseSoundSelectType   = "cmd-none", 
    BaseSoundMovementType = "cmd-none",
    BaseSoundWeaponType   = "cmd-none", 
}

UnitSoundEffects = {
    -- ARMADA COMMANDER
    armcom = {
    BaseSoundSelectType   = "arm-com-sel",
    BaseSoundMovementType = {"arm-com-ok-1","arm-com-ok-2","arm-com-ok-3","arm-com-ok-4",},
    BaseSoundWeaponType   = "laser-tiny",
    },

    -- ARMADA BUILDINGS
    armrad = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "laser-tiny",
    BaseSoundWeaponType   = "arm-bld-radar",
    },

    armllt = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "laser-tiny",
    BaseSoundWeaponType   = "arm-bld-radar",
    },

    -- ARMADA HOVERCRAFT
    armsh = {
    BaseSoundSelectType   = "arm-hov-small-sel",
    BaseSoundMovementType = "arm-hov-small-ok",
    BaseSoundWeaponType   = "laser-tiny",
    },
    armmh = {
    BaseSoundSelectType   = "arm-hov-small-sel",
    BaseSoundMovementType = "arm-hov-small-ok",
    BaseSoundWeaponType   = "rocket-small",
    },
    armch = {
    BaseSoundSelectType   = "arm-hov-small-sel",
    BaseSoundMovementType = "arm-hov-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armah = {
    BaseSoundSelectType   = "arm-hov-small-sel",
    BaseSoundMovementType = "arm-hov-small-ok",
    BaseSoundWeaponType   = "aarocket-small",
    },
    armanac = {
    BaseSoundSelectType   = "arm-hov-small-sel",
    BaseSoundMovementType = "arm-hov-small-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    armthovr = {
    BaseSoundSelectType   = "arm-hov-large-sel",
    BaseSoundMovementType = "arm-hov-large-ok",
    BaseSoundWeaponType   = "transport-large",
    },
    armlun = {
    BaseSoundSelectType   = "arm-hov-large-sel",
    BaseSoundMovementType = "arm-hov-large-ok",
    BaseSoundWeaponType   = "laser-large",
    },


    -- ARMADA T1 BOTS
    armflea = {
    BaseSoundSelectType   = "arm-bot-tiny-ok",
    BaseSoundMovementType = "arm-bot-tiny-ok",
    BaseSoundWeaponType   = "laser-tiny",
    },
    armpw = {
    BaseSoundSelectType   = "arm-bot-tiny-ok",
    BaseSoundMovementType = "arm-bot-tiny-ok",
    BaseSoundWeaponType   = "fastemgalt-small",
    },
    armham = {
    BaseSoundSelectType   = "arm-bot-small-ok",
    BaseSoundMovementType = "arm-bot-small-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    armrock = {
    BaseSoundSelectType   = "arm-bot-small-ok",
    BaseSoundMovementType = "arm-bot-small-ok",
    BaseSoundWeaponType   = "rocketalt-small",
    },
    armjeth = {
    BaseSoundSelectType   = "arm-bot-small-ok",
    BaseSoundMovementType = "arm-bot-small-ok",
    BaseSoundWeaponType   = "aarocket-small",
    },
    armwar = {
    BaseSoundSelectType   = "arm-bot-small-ok",
    BaseSoundMovementType = "arm-bot-medium-ok",
    BaseSoundWeaponType   = "laser-medium",
    },
    armck = {
    BaseSoundSelectType   = "arm-bot-small-ok",
    BaseSoundMovementType = "arm-bot-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armrectr = {
    BaseSoundSelectType   = "arm-bot-tiny-ok",
    BaseSoundMovementType = "arm-bot-tiny-ok",
    BaseSoundWeaponType   = "rez-small",
    },

    -- CORTEX T1 BOTS
    corak = {
    BaseSoundSelectType   = "cor-bot-tiny-sel",
    BaseSoundMovementType = "cor-bot-tiny-ok",
    BaseSoundWeaponType   = "laser-small",
    },
    corthud = {
    BaseSoundSelectType   = "cor-bot-small-sel",
    BaseSoundMovementType = "cor-bot-small-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    corstorm = {
    BaseSoundSelectType   = "cor-bot-small-sel",
    BaseSoundMovementType = "cor-bot-small-ok",
    BaseSoundWeaponType   = "rocketalt-small",
    },
    corcrash = {
    BaseSoundSelectType   = "cor-bot-small-sel",
    BaseSoundMovementType = "cor-bot-small-ok",
    BaseSoundWeaponType   = "aarocket-small",
    },
    corck = {
    BaseSoundSelectType   = "cor-bot-small-sel",
    BaseSoundMovementType = "cor-bot-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    cornecro = {
    BaseSoundSelectType   = "cor-bot-tiny-sel",
    BaseSoundMovementType = "cor-bot-tiny-ok",
    BaseSoundWeaponType   = "rez-small",
    },

    -- ARMADA T1 VEHICLES
    armfav = {
    BaseSoundSelectType   = "arm-veh-tiny-sel",
    BaseSoundMovementType = "arm-veh-tiny-ok",
    BaseSoundWeaponType   = "laser-tiny",
    },
    armflash = {
    BaseSoundSelectType   = "arm-veh-small-sel",
    BaseSoundMovementType = "arm-veh-small-ok",
    BaseSoundWeaponType   = "fastemg-small",
    },
    armart = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "arty-small",
    },
    armsam = {
    BaseSoundSelectType   = "arm-veh-small-sel",
    BaseSoundMovementType = "arm-veh-small-ok",
    BaseSoundWeaponType   = "aarocket-small",
    },
    armpincer = {
    BaseSoundSelectType   = "arm-tnk-small-amph-sel",
    BaseSoundMovementType = "arm-tnk-small-amph-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    armstump = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    armjanus = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "rocket-medium",
    },
    armcv = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armbeaver = {
    BaseSoundSelectType   = "arm-tnk-small-amph-sel",
    BaseSoundMovementType = "arm-tnk-small-amph-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armmlv = {
    BaseSoundSelectType   = "arm-veh-tiny-sel",
    BaseSoundMovementType = "arm-veh-tiny-ok",
    BaseSoundWeaponType   = "mine-small",
    },

    -- ARMADA T2 VEHICLES
    armjam = {
    BaseSoundSelectType   = "arm-veh-small-sel",
    BaseSoundMovementType = "arm-veh-small-ok",
    BaseSoundWeaponType   = "jammer",
    },
    armseer = {
    BaseSoundSelectType   = "arm-veh-small-sel",
    BaseSoundMovementType = "arm-veh-small-ok",
    BaseSoundWeaponType   = "radar",
    },
    armgremlin = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "cloak",
    },
    armconsul = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "con-small",
    },
    armmart = {
    BaseSoundSelectType   = "arm-tnk-medium-sel",
    BaseSoundMovementType = "arm-tnk-medium-ok",
    BaseSoundWeaponType   = "arty-medium",
    },
    armlatnk = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "lightning",
    },
    armyork = {
    BaseSoundSelectType   = "arm-tnk-medium-sel",
    BaseSoundMovementType = "arm-tnk-medium-ok",
    BaseSoundWeaponType   = "flak",
    },
    armcroc = {
    BaseSoundSelectType   = "arm-tnk-medium-sel",
    BaseSoundMovementType = "arm-tnk-medium-ok",
    BaseSoundWeaponType   = "plasma-medium",
    },
    armacv = {
    BaseSoundSelectType   = "arm-tnk-small-sel",
    BaseSoundMovementType = "arm-tnk-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armmerl = {
    BaseSoundSelectType   = "arm-tnk-medium-sel",
    BaseSoundMovementType = "arm-tnk-medium-ok",
    BaseSoundWeaponType   = "rocketalt-large",
    },
    armbull = {
    BaseSoundSelectType   = "arm-tnk-large-sel",
    BaseSoundMovementType = "arm-tnk-large-ok",
    BaseSoundWeaponType   = "plasma-medium",
    },
    armmanni = {
    BaseSoundSelectType   = "arm-tnk-large-sel",
    BaseSoundMovementType = "arm-tnk-largealt-ok",
    BaseSoundWeaponType   = "laser-large",
    },

    -- ARMADA T1 SHIPS-SUBS
    armdecade = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "arm-shp-small-ok",
    BaseSoundWeaponType   = "fastemg-small",
    },
    armpt = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "arm-shp-small-ok",
    BaseSoundWeaponType   = "aarocket-small",
    },
    armcs = {
    BaseSoundSelectType   = "arm-shp-medium-sel",
    BaseSoundMovementType = "arm-shp-medium-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armrecl = {
    BaseSoundSelectType   = "arm-sub-small-sel",
    BaseSoundMovementType = "arm-sub-small-ok",
    BaseSoundWeaponType   = "rez-small",
    },
    armtship = {
    BaseSoundSelectType   = "arm-shp-medium-sel",
    BaseSoundMovementType = "arm-shp-medium-ok",
    BaseSoundWeaponType   = "transport-large",
    },
    armpship = {
    BaseSoundSelectType   = "arm-shp-medium-sel",
    BaseSoundMovementType = "arm-shp-medium-ok",
    BaseSoundWeaponType   = "plasma-small",
    },
    armsub = {
    BaseSoundSelectType   = "arm-sub-small-sel",
    BaseSoundMovementType = "arm-sub-small-ok",
    BaseSoundWeaponType   = "torpedo-small",
    },
    armroy = {
    BaseSoundSelectType   = "arm-shp-medium-sel",
    BaseSoundMovementType = "arm-shp-medium-ok",
    BaseSoundWeaponType   = "plasma-medium-torpedo",
    },
    armsjam = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "arm-shp-small-ok",
    BaseSoundWeaponType   = "jammer",
    },
    armmls = {
    BaseSoundSelectType   = "arm-shp-small-sel",
    BaseSoundMovementType = "arm-shp-small-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armacsub = {
    BaseSoundSelectType   = "arm-sub-medium-sel",
    BaseSoundMovementType = "arm-sub-medium-ok",
    BaseSoundWeaponType   = "conalt-small",
    },
    armsubk = {
    BaseSoundSelectType   = "arm-sub-medium-sel",
    BaseSoundMovementType = "arm-sub-medium-ok",
    BaseSoundWeaponType   = "torpedo-medium",
    },
    armaas = {
    BaseSoundSelectType   = "arm-shp-medium-sel",
    BaseSoundMovementType = "arm-shp-medium-ok",
    BaseSoundWeaponType   = "flak",
    },
    armcrus = {
    BaseSoundSelectType   = "arm-shp-large-sel",
    BaseSoundMovementType = "arm-shp-large-ok",
    BaseSoundWeaponType   = "plasma-medium-torpedo",
    },
    armcarry = {
    BaseSoundSelectType   = "arm-shp-large-sel",
    BaseSoundMovementType = "arm-shp-large-ok",
    BaseSoundWeaponType   = "radar-support",
    },
    armserp = {
    BaseSoundSelectType   = "arm-sub-medium-sel",
    BaseSoundMovementType = "arm-sub-medium-ok",
    BaseSoundWeaponType   = "torpedo-medium",
    },
    armmship = {
    BaseSoundSelectType   = "arm-shp-large-sel",
    BaseSoundMovementType = "arm-shp-large-ok",
    BaseSoundWeaponType   = "rocketalt-large",
    },
    armbats = {
    BaseSoundSelectType   = "arm-shp-large-sel",
    BaseSoundMovementType = "arm-shp-large-ok",
    BaseSoundWeaponType   = "plasma-large",
    },
    armepoch = {
    BaseSoundSelectType   = "arm-shp-huge-sel",
    BaseSoundMovementType = "arm-shp-huge-ok",
    BaseSoundWeaponType   = "plasma-huge",
    },
    
}


-- Command IDs
Move = CMD.MOVE
Fight = CMD.FIGHT
Patrol = CMD.PATROL
Guard = CMD.GUARD
Groupselect = CMD.GROUPSELECT
Repair = CMD.REPAIR
Reclaim = CMD.RECLAIM
Dgun = CMD.DGUN
Resurrect = CMD.RESURRECT
OnOff = CMD.ONOFF
Repeat = CMD.REPEAT
Attack = CMD.ATTACK
SelfD = CMD.SELFD
SetTarget = 34923

-- create table with all unit sounds



if gadgetHandler:IsSyncedCode() then -- Synced part
    


else -- Unsynced part

    function PlaySelectSound(unitID)
        Spring.Echo("hello world")
        Spring.Echo(unitID)
        local unitDefID = Spring.GetUnitDefID(unitID)
        local posx, posy, posz = Spring.GetUnitPosition(unitID)
        local unitName = UnitDefs[unitDefID].name

        -- DEACTIVATE BELOW FOR NORMAL SOUNDS

        -- if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSoundSelectType then
        --     --Spring.Echo(unitName.." select sound")
        --     local sound = UnitSoundEffects[unitName].BaseSoundSelectType
        --     if sound[2] then
        --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'unitreply')
        --     else
        --         Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'unitreply')
        --     end
        -- else
        --     --Spring.Echo("Generic select sound") 
        --     local sound = DefaultSoundEffects.BaseSoundSelectType
        --     if sound[2] then
        --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'unitreply')
        --     else
        --         Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'unitreply')
        --     end
        -- end
    --     if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSoundWeaponType then
    --                 --Spring.Echo(unitName.." base sound")
    --                 local sound = UnitSoundEffects[unitName].BaseSoundWeaponType
    --                 if sound[2] then
    --                     Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.7, posx, posy, posz, 'unitreply')
    --                 else
    --                     Spring.PlaySoundFile(sound, 0.7, posx, posy, posz, 'unitreply')
    --                 end
    --                 --Spring.PlaySoundFile(UnitSoundEffects[unitName].BaseSoundWeaponType, 0.5, posx, posy, posz, 'sfx')
    --             else
    --                 --Spring.Echo("Generic base sound") 
    --                 local sound = DefaultSoundEffects.BaseSoundWeaponType
    --                 if sound[2] then
    --                     Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.7, posx, posy, posz, 'unitreply')
    --                 else
    --                     Spring.PlaySoundFile(sound, 0.7, posx, posy, posz, 'unitreply')
    --                 end
    --                 --Spring.PlaySoundFile(DefaultSoundEffects.BaseSoundWeaponType, 0.6, posx, posy, posz, 'sfx')
    --             end
    --     selectionChanged = false
    -- end

    function gadget:GameFrame(n)
        if not selectionChanged then
            local units = Spring.GetSelectedUnits()
            NewSelectedUnits = units
            for i = 1,#NewSelectedUnits do
                if PreviouslySelectedUnits[i] == nil then
                    selectionChanged = true
                elseif NewSelectedUnits[i] ~= PreviouslySelectedUnits[i] then
                    selectionChanged = true
                end
            end
            PreviouslySelectedUnits = units
        end
        
        if selectionChanged then
            Spring.Echo("1")
            local _,_,LMBPress,_,_,offscreen = Spring.GetMouseState()
            if (not LMBPress) and (not offscreen) then
                Spring.Echo("2")
                local units = Spring.GetSelectedUnits()
                local unitcount = #units
                if unitcount > 1 then
                    Spring.Echo("3")
                    local unitID = units[math.random(1,unitcount)]
                    PlaySelectSound(unitID)
                elseif unitcount == 1 then
                    Spring.Echo("4")
                    local unitID = units[1]
                    PlaySelectSound(unitID)
                end
            end
        end
    end

    function gadget:SelectionChanged(sel)
        selectionChanged = true
    end

    function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
        CurrentFrame = Spring.GetGameFrame()
        if CurrentFrame ~= UsedFrame then
            local selectedUnitCount = Spring.GetSelectedUnitsCount()
            if Spring.IsUnitSelected(unitID) then
                if selectedUnitCount > 1 then
                   local selUnits = Spring.GetSelectedUnits()
                   unitDefID = Spring.GetUnitDefID(selUnits[math.random(1,#selUnits)])
                end
                unitName = UnitDefs[unitDefID].name
                --Spring.Echo(unitName)
                UsedFrame = CurrentFrame



                local posx, posy, posz = Spring.GetUnitPosition(unitID)

                -- DEACTIVATE below to disable command-sounds

                -- if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSoundMovementType then
                --     --Spring.Echo(unitName.." base sound")
                --     local sound = UnitSoundEffects[unitName].BaseSoundMovementType
                --     if sound[2] then
                --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.8, posx, posy, posz, 'ui')
                --     else
                --         Spring.PlaySoundFile(sound, 0.8, posx, posy, posz, 'ui')
                --     end
                --     --Spring.PlaySoundFile(UnitSoundEffects[unitName].BaseSoundMovementType, 0.8, posx, posy, posz, 'unitreply')
                -- else
                --     --Spring.Echo("Generic base sound") 
                --     local sound = DefaultSoundEffects.BaseSoundMovementType
                --     if sound[2] then
                --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.8, posx, posy, posz, 'ui')
                --     else
                --         Spring.PlaySoundFile(sound, 0.8, posx, posy, posz, 'ui')
                --     end
                --     --Spring.PlaySoundFile(DefaultSoundEffects.BaseSoundMovementType, 0.8, posx, posy, posz, 'unitreply')
                -- end


                -- if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSoundWeaponType then
                --     --Spring.Echo(unitName.." base sound")
                --     local sound = UnitSoundEffects[unitName].BaseSoundWeaponType
                --     if sound[2] then
                --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                --     else
                --         Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                --     end
                --     --Spring.PlaySoundFile(UnitSoundEffects[unitName].BaseSoundWeaponType, 0.8, posx, posy, posz, 'sfx')
                -- else
                --     --Spring.Echo("Generic base sound") 
                --     local sound = DefaultSoundEffects.BaseSoundWeaponType
                --     if sound[2] then
                --         Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                --     else
                --         Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                --     end
                --     --Spring.PlaySoundFile(DefaultSoundEffects.BaseSoundWeaponType, 0.8, posx, posy, posz, 'sfx')
                -- end
                




                if cmdID == Move then
                    --local posx1, posy1, posz1 = cmdParams[1], cmdParams[2], cmdParams[3]
                    if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].Move then
                        Spring.PlaySoundFile(UnitSoundEffects[unitName].Move, 0.4, 2)
                        -- for cmd sounds in 3D use Spring.PlaySoundFile(UnitSoundEffects[unitName].Move, 0.75, posx1, posy1, posz1, 'sfx')
                    else
                        Spring.PlaySoundFile(CommandSoundEffects.Move, 0.4, 2)
                    end
                elseif cmdID == Fight then
                    Spring.PlaySoundFile(CommandSoundEffects.Fight, 0.8, 2)
                elseif cmdID == Patrol then
                    Spring.PlaySoundFile(CommandSoundEffects.Patrol, 0.8, 2)
                elseif cmdID == Guard then
                    Spring.PlaySoundFile(CommandSoundEffects.Guard, 0.8, 2)
                elseif cmdID == Groupselect then
                    Spring.PlaySoundFile(CommandSoundEffects.Groupselect, 0.8, 2)
                elseif cmdID == Repair then
                    Spring.PlaySoundFile(CommandSoundEffects.Repair, 0.6, 2)
                elseif cmdID == Reclaim then
                    Spring.PlaySoundFile(CommandSoundEffects.Reclaim, 0.3, 2)
                elseif cmdID == Dgun then
                    Spring.PlaySoundFile(CommandSoundEffects.Dgun, 0.8, 2)
                elseif cmdID == Resurrect then
                    Spring.PlaySoundFile(CommandSoundEffects.Resurrect, 0.7, 2)
                elseif cmdID == Repeat then
                    Spring.PlaySoundFile(CommandSoundEffects.Repeat, 0.8, 2)
                elseif cmdID == Attack then
                    Spring.PlaySoundFile(CommandSoundEffects.Attack, 0.8, 2)   
                elseif cmdID == SelfD then
                    Spring.PlaySoundFile(CommandSoundEffects.SelfD, 0.8, 2)
                -- elseif cmdID == 34923 then
                --     Spring.PlaySoundFile(CommandSoundEffects.SetTarget, 0.8, 2)
                --elseif cmdID < 0 then
                --    Spring.PlaySoundFile(CommandSoundEffects.Build, 0.5, 2) 
                end
            end
        end
    end
end