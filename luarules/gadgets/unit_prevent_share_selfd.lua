function gadget:GetInfo()
  return {
    name      = "No Self-D",
    desc      = "Prevents self-destruction when a unit changes hands or a player leaves.",
    author    = "quantum, Bluestone",
    date      = "July 13, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


if (not gadgetHandler:IsSyncedCode()) then
 
function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  if (Spring.GetUnitSelfDTime(unitID) > 0) then
    Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
  end
end

function gadget:PlayerChanged(playerID) --necessary wtfness, probably can remove in 97.0+
end

else

function gadget:PlayerChanged(playerID)
	local _,active,spec,teamID = Spring.GetPlayerInfo(playerID)
	if active and not spec then return end
	local units = Spring.GetTeamUnits(teamID)
	for _,unitID in pairs(units) do
		  if (Spring.GetUnitSelfDTime(unitID) > 0) then
			Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
		end
	end
end


end