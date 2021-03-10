local UsedFrame = 0

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

DefaultSoundEffects = {
    BaseSound = "cmd-defaultbaselayer",
    Move = "cmd-move",
    LineMove = "cmd-move",   
    Fight = "cmd-fight",
    LineFight = "cmd-fight",
    Build = "cmd-build",
    Guard = "cmd-guard",
    Reclaim = "cmd-reclaim",
    Resurrect = "cmd-rez2",
    Repair = "cmd-repair",
    Groupselect = "cmd-reclaim",
    Dgun = "cmd-dgun",
    Patrol = "cmd-fightxs", -- no patrol sound yet so i'm using fight
}

UnitSoundEffects = {
    armpw = {BaseSound = "cmd-defaultbaselayer",},
    armstump = {BaseSound = "tnkt1canok",},
    corak = {BaseSound = "cmd-defaultbaselayer",},
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

if gadgetHandler:IsSyncedCode() then -- Synced part
    


else -- Unsynced part
    
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

                -- posx, posy, posz = Spring.GetUnitPosition(unitID)
                -- if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSound then
                --     --Spring.Echo(unitName.." base sound")
                --     Spring.PlaySoundFile(UnitSoundEffects[unitName].BaseSound, 0.8, posx, posy, posz, 'unitreply')
                -- else
                --     --Spring.Echo("Generic base sound") 
                --     Spring.PlaySoundFile(DefaultSoundEffects.BaseSound, 0.8, posx, posy, posz, 'unitreply')
                -- end





                if cmdID == Move then
                    --local posx1, posy1, posz1 = cmdParams[1], cmdParams[2], cmdParams[3]
                    if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].Move then
                        Spring.PlaySoundFile(UnitSoundEffects[unitName].Move, 0.5, 2)
                        -- for cmd sounds in 3D use Spring.PlaySoundFile(UnitSoundEffects[unitName].Move, 0.75, posx1, posy1, posz1, 'sfx')
                    else
                        Spring.PlaySoundFile(DefaultSoundEffects.Move, 0.5, 2)
                    end
                elseif cmdID == Fight then
                    Spring.PlaySoundFile(DefaultSoundEffects.Fight, 0.8, 2)
                elseif cmdID == Patrol then
                    Spring.PlaySoundFile(DefaultSoundEffects.Patrol, 0.8, 2)
                elseif cmdID == Guard then
                    Spring.PlaySoundFile(DefaultSoundEffects.Guard, 0.8, 2)
                elseif cmdID == Groupselect then
                    Spring.PlaySoundFile(DefaultSoundEffects.Groupselect, 0.8, 2)
                elseif cmdID == Repair then
                    Spring.PlaySoundFile(DefaultSoundEffects.Repair, 0.6, 2)
                elseif cmdID == Reclaim then
                    Spring.PlaySoundFile(DefaultSoundEffects.Reclaim, 0.8, 2)
                elseif cmdID == Dgun then
                    Spring.PlaySoundFile(DefaultSoundEffects.Dgun, 0.8, 2)
                elseif cmdID == Resurrect then
                    Spring.PlaySoundFile(DefaultSoundEffects.Resurrect, 1, 2)
                elseif cmdID < 0 then
                    Spring.PlaySoundFile(DefaultSoundEffects.Build, 0.5, 2) 
                end
            end
        end
    end
end