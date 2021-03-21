-- Settings
local DelayRandomization = 1 -- frames

local CommandUISoundDelayFrames = 1 
local CommandUnitSoundDelayFrames = 25 -- don't make it smaller than CommandUISoundDelayFrames
local SelectSoundDelayFrames = 10
local UnitFinishedSoundDelayFrames = 1
local UnitBuildOrderSoundDelayFrames = 10


-- InitValues
local PreviouslySelectedUnits = {}
local selectionChanged = false

local CommandUISoundDelayLastFrame = 0
local CommandUnitSoundDelayLastFrame = 0
local SelectSoundDelayLastFrame = 0
local UnitFinishedSoundDelayLastFrame = 0
local UnitBuildOrderSoundDelayLastFrame = 0






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

VFS.Include('luarules/configs/gui_soundeffects.lua')

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
        local unitDefID = Spring.GetUnitDefID(unitID)
        local posx, posy, posz = Spring.GetUnitPosition(unitID)
        local unitName = UnitDefs[unitDefID].name

        -- DEACTIVATE BELOW FOR NORMAL SOUNDS
        if CurrentGameFrame >= SelectSoundDelayLastFrame + SelectSoundDelayFrames then
            SelectSoundDelayLastFrame = CurrentGameFrame + (math.random(-DelayRandomization,DelayRandomization))
            if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
                local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
                if sound[2] then
                    Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                else
                    Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                end
            end
            if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
                local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
                if sound[2] then
                    Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.7, posx, posy, posz, 'ui')
                else
                    Spring.PlaySoundFile(sound, 0.7, posx, posy, posz, 'ui')
                end
            end
        end
        selectionChanged = false
    end

    function gadget:GameFrame(n)
        CurrentGameFrame = Spring.GetGameFrame()
        if not selectionChanged then
            selectionChanged = false
            local selectedUnits = Spring.GetSelectedUnits()
            local selectedUnitsCount = #selectedUnits
            if selectedUnitsCount == 0 then
                selectionChanged = false
                previouslySelectedUnits = nil
            elseif selectedUnitsCount > 0 then
                table.sort(selectedUnits)
                if not previouslySelectedUnits then
                    selectionChanged = true
                    previouslySelectedUnits = selectedUnits
                else
                    for i = 1,selectedUnitsCount do
                        if not previouslySelectedUnits[i] then
                            selectionChanged = true
                            previouslySelectedUnits = selectedUnits
                        elseif selectedUnits[i] ~= previouslySelectedUnits[i] or #selectedUnits ~= #previouslySelectedUnits then
                            selectionChanged = true
                            previouslySelectedUnits = selectedUnits
                            break
                        else
                            selectionChanged = false
                            previouslySelectedUnits = selectedUnits
                        end
                    end
                end
            end
        elseif selectionChanged then
            local _,_,LMBPress,_,_,offscreen = Spring.GetMouseState()
            if (not LMBPress) and (not offscreen) then
                selectionChanged = false
                local units = Spring.GetSelectedUnits()
                table.sort(units)
                previouslySelectedUnits = units
                local unitcount = #units
                if unitcount > 1 then
                    local unitID = units[math.random(1,unitcount)]
                    PlaySelectSound(unitID)
                elseif unitcount == 1 then
                    local unitID = units[1]
                    PlaySelectSound(unitID)
                end
            end
        end
    end

    function gadget:UnitFinished(unitID, unitDefID, unitTeam)
        local myTeamID = Spring.GetMyTeamID()
        if myTeamID == unitTeam then
            local unitName = UnitDefs[unitDefID].name
            local posx, posy, posz = Spring.GetUnitPosition(unitID)
            if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + UnitFinishedSoundDelayFrames then
                UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math.random(-DelayRandomization,DelayRandomization))
                if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundMovementType then
                    local sound = GUIUnitSoundEffects[unitName].BaseSoundMovementType
                    if sound[2] then
                        Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.8, posx, posy, posz, 'ui')
                    else
                        Spring.PlaySoundFile(sound, 0.8, posx, posy, posz, 'ui')
                    end
                end
                if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
                    local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
                    if sound[2] then
                        Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                    else
                        Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                    end
                end
            end
        end
    end


    function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
        if CurrentGameFrame ~= UsedFrame then
            local selectedUnitCount = Spring.GetSelectedUnitsCount()
            if Spring.IsUnitSelected(unitID) then
                if selectedUnitCount > 1 then
                   local selUnits = Spring.GetSelectedUnits()
                   unitDefID = Spring.GetUnitDefID(selUnits[math.random(1,#selUnits)])
                end
                unitName = UnitDefs[unitDefID].name
                UsedFrame = CurrentGameFrame

                local posx, posy, posz = Spring.GetUnitPosition(unitID)

                ValidCommandSound = false
                if CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames then
                    CommandUISoundDelayLastFrame = CurrentGameFrame + (math.random(-DelayRandomization,DelayRandomization))
                    if cmdID == Move then
                        if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].Move then
                            Spring.PlaySoundFile(GUIUnitSoundEffects[unitName].Move, 0.4, "ui")
                        else
                            Spring.PlaySoundFile(CommandSoundEffects.Move, 0.4, "ui")
                        end
                        ValidCommandSound = true
                    elseif cmdID == Fight then
                        Spring.PlaySoundFile(CommandSoundEffects.Fight, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Patrol then
                        Spring.PlaySoundFile(CommandSoundEffects.Patrol, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Guard then
                        Spring.PlaySoundFile(CommandSoundEffects.Guard, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Groupselect then
                        Spring.PlaySoundFile(CommandSoundEffects.Groupselect, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Repair then
                        Spring.PlaySoundFile(CommandSoundEffects.Repair, 0.6, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Reclaim then
                        Spring.PlaySoundFile(CommandSoundEffects.Reclaim, 0.3, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Dgun then
                        Spring.PlaySoundFile(CommandSoundEffects.Dgun, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Resurrect then
                        Spring.PlaySoundFile(CommandSoundEffects.Resurrect, 0.7, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Repeat then
                        Spring.PlaySoundFile(CommandSoundEffects.Repeat, 0.8, "ui")
                        ValidCommandSound = true
                    elseif cmdID == Attack then
                        Spring.PlaySoundFile(CommandSoundEffects.Attack, 0.8, "ui")
                        ValidCommandSound = true   
                    elseif cmdID == SelfD then
                        Spring.PlaySoundFile(CommandSoundEffects.SelfD, 0.8, "ui")
                        ValidCommandSound = true
                    -- elseif cmdID == 34923 then
                    --    Spring.PlaySoundFile(CommandSoundEffects.SetTarget, 0.8, "ui")
                    --    ValidCommandSound = true
                    elseif cmdID < 0 then
                        local unitDefID = -(cmdID)
                        local unitName = UnitDefs[unitDefID].name
                        if CurrentGameFrame >= UnitBuildOrderSoundDelayLastFrame + UnitBuildOrderSoundDelayFrames then
                            UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + (math.random(-DelayRandomization,DelayRandomization))
                            if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
                                local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
                                if sound[2] then
                                    Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                                else
                                    Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                                end
                            end
                            if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
                                local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
                                if sound[2] then
                                    Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.35, posx, posy, posz, 'ui')
                                else
                                    Spring.PlaySoundFile(sound, 0.35, posx, posy, posz, 'ui')
                                end
                            end
                        end
                        --Spring.PlaySoundFile(CommandSoundEffects.Build, 0.5, 2)
                        --ValidCommandSound = false 
                    end
                end

                -- DEACTIVATE below to disable command-sounds
                if CurrentGameFrame >= CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
                    CommandUnitSoundDelayLastFrame = CurrentGameFrame + (math.random(-DelayRandomization,DelayRandomization))
                    if ValidCommandSound then
                        if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundMovementType then
                            local sound = GUIUnitSoundEffects[unitName].BaseSoundMovementType
                            if sound[2] then
                                Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.8, posx, posy, posz, 'ui')
                            else
                                Spring.PlaySoundFile(sound, 0.8, posx, posy, posz, 'ui')
                            end
                        end

                        if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
                            local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
                            if sound[2] then
                                Spring.PlaySoundFile(sound[math.random(1,#sound)], 0.2, posx, posy, posz, 'ui')
                            else
                                Spring.PlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
                            end
                        end
                    end
                end

            end
        end
    end
end