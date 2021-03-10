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
    
    Patrol = "cmd-fight", -- no patrol sound yet so i'm using fight
}

UnitSoundEffects = {
    armpw = {
        BaseSound = "cmd-defaultbaselayer",
    },
    corak = {
        BaseSound = "cmd-defaultbaselayer",
    },
}


-- Command IDs
Move = CMD.MOVE
Fight = CMD.FIGHT
Patrol = CMD.PATROL

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
                Spring.Echo(unitName)
                UsedFrame = CurrentFrame

                if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].BaseSound then
                    Spring.Echo(unitName.." base sound")
                    Spring.PlaySoundFile(UnitSoundEffects[unitName].BaseSound, 0.75, 2)
                else
                    Spring.Echo("Generic base sound") 
                    Spring.PlaySoundFile(DefaultSoundEffects.BaseSound, 0.75, 2)
                end





                if cmdID == Move then
                    if UnitSoundEffects[unitName] and UnitSoundEffects[unitName].Move then
                        Spring.PlaySoundFile(UnitSoundEffects[unitName].Move, 1, 2)
                    else
                        Spring.PlaySoundFile(DefaultSoundEffects.Move, 1, 2)
                    end
                elseif cmdID == Fight then
                    Spring.PlaySoundFile(DefaultSoundEffects.Fight, 1, 2)
                elseif cmdID == Patrol then
                    Spring.PlaySoundFile(DefaultSoundEffects.Patrol, 1, 2)
                end
            end
        end
    end













end