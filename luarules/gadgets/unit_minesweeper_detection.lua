--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Minesweeper Detection",
		desc = "Shows mines around minesweepers",
		author = "Hornet",
		date = "May 25th, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spMoveCtrlSetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData

local minesweeperIDs = {}
local minesweepers = {}
local mineIDs = {}

--Spring.Echo('hornet ms loaded')

local teamList = Spring.GetTeamList()
local teamIDs = {}

local revealedMines = {}=
--Spring.Debug.TableEcho(teamList)
for i = 1, #teamList do
    teamIDs[teamList[i]] = teamList[i]
	revealedMines[teamList[i]] = {}
end
--Spring.Debug.TableEcho(teamIDs)
--Spring.Echo('hornet revealedMines')
--Spring.Debug.TableEcho(revealedMines)




local detectionRange = 300

--anything that should detect mines
if UnitDefNames.armmlv then
    minesweeperIDs[UnitDefNames.armmlv.id] = true
end
if UnitDefNames.cormlv then
    minesweeperIDs[UnitDefNames.cormlv.id] = true
end
if UnitDefNames.legmlv then
    minesweeperIDs[UnitDefNames.legmlv.id] = true
end

if UnitDefNames.armmls then
    minesweeperIDs[UnitDefNames.armmls.id] = true
end
if UnitDefNames.cormls then
    minesweeperIDs[UnitDefNames.cormls.id] = true
end
if UnitDefNames.legmls then
    minesweeperIDs[UnitDefNames.legmls.id] = true
end

if UnitDefNames.armmls then
    minesweeperIDs[UnitDefNames.armmls.id] = true
end
if UnitDefNames.cormls then
    minesweeperIDs[UnitDefNames.cormls.id] = true
end
if UnitDefNames.legmls then
    minesweeperIDs[UnitDefNames.legmls.id] = true
end
----Spring.Echo('hornet minesweeperIDs')
----Spring.Debug.TableEcho(minesweeperIDs)



if UnitDefNames.armmine1 then
    mineIDs[UnitDefNames.armmine1.id] = true
end
if UnitDefNames.armmine2 then
    mineIDs[UnitDefNames.armmine2.id] = true
end
if UnitDefNames.armmine3 then
    mineIDs[UnitDefNames.armmine3.id] = true
end
if UnitDefNames.cormine1 then
    mineIDs[UnitDefNames.cormine1.id] = true
end
if UnitDefNames.cormine2 then
    mineIDs[UnitDefNames.cormine2.id] = true
end
if UnitDefNames.cormine3 then
    mineIDs[UnitDefNames.cormine3.id] = true
end
if UnitDefNames.cormine4 then
    mineIDs[UnitDefNames.cormine4.id] = true
end
if UnitDefNames.armfmine3 then
    mineIDs[UnitDefNames.armfmine3.id] = true
end
if UnitDefNames.corfmine3 then
    mineIDs[UnitDefNames.corfmine3.id] = true
end
--will need leg later

----Spring.Echo('hornet mineIDs')
----Spring.Debug.TableEcho(mineIDs)


function gadget:Initialize()
	if table.count(minesweeperIDs) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end
	if table.count(mineIDs) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end

end



function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if minesweeperIDs[unitDefID] then
		minesweepers[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID)
	if minesweepers[unitID] then
		minesweepers[unitID] = nil
	end
end

function gadget:GameFrame(f)
	local minesToReveal = {}
	--generate list of active teams. this is list of mines that team can see

	for team in pairs(teamIDs) do
		minesToReveal[team] = {}
	end

	if f % 50 == 1 then
		--Spring.Echo('hornet minesweepers')
		--Spring.Debug.TableEcho(minesweepers)
    	--find all minesweepers
		if table.count(minesweepers)>0 then
			--Spring.Echo('hornet in minesweepers>0')
			for miner in pairs(minesweepers) do

				--Spring.Echo('hornet miner', miner)

				
				local minerTeam = Spring.GetUnitTeam(miner)--this sometimes seems to be 0, should it be? is 0 gaia or 'team 1' ? try with built minelayers rather than spawned? try to give units to team 2 and see if they;re blue or gaia?
				local x, y, z = Spring.GetUnitPosition(miner)
				local nearUnits = Spring.GetUnitsInCylinder(x, z, detectionRange)

				--Spring.Echo('hornet minerTeam', minerTeam)


				--Spring.Echo('hornet nearUnits')
				--Spring.Debug.TableEcho(nearUnits)
				for _, nearUnit in ipairs(nearUnits) do
					--Spring.Echo('hornet poi Spring.GetUnitTeam(nearUnit)', Spring.GetUnitTeam(nearUnit))
					--local mineTeam = Spring.GetUnitTeam(nearUnit)
					if minerTeam ~= Spring.GetUnitTeam(nearUnit) then
						local nearUnitDefID = Spring.GetUnitDefID(nearUnit)
					
						if mineIDs[nearUnitDefID] then
							--Spring.Echo('hornet adding  minesToReveal[minerTeam][nearUnit] = nearUnit', minerTeam, nearUnit)
							minesToReveal[minerTeam][nearUnit] = nearUnit
						end
						
					end

				end
			end
		end

		for team in pairs(teamIDs) do

			--Spring.Echo('hornet minesToReveal (team)' , team)
			--Spring.Debug.TableEcho(minesToReveal)
			if table.count(minesToReveal[team]) > 0 then
				--Spring.Echo('hornet poi2 minesToReveal loop starting, team: ' , team)
				for mineToReveal in pairs(minesToReveal[team]) do
					--Spring.Echo('mineToReveal loop,', mineToReveal)
					if revealedMines[team][mineToReveal] == nil then
						--show 
						--Spring.Echo('revealedMines[team][mineToReveal] = mineToReveal', team, mineToReveal)
						revealedMines[team][mineToReveal] = mineToReveal
						Spring.SetUnitLosState(mineToReveal, team, 3) --show in vision and radar
						Spring.SetUnitLosMask(mineToReveal, team, 3) -- prevent engine from immediately resetting that state

					end
				end
			end
				

			--Spring.Echo('hornet revealedMines (team)' , team)
			--Spring.Debug.TableEcho(revealedMines)
			if table.count(revealedMines[team]) > 0 then

				--Spring.Echo('hornet minesToReveal (team)' , team)
				--Spring.Debug.TableEcho(minesToReveal)
	
				--if any mines -are- uncloaked that no longer should be, recloak
				if table.count(minesToReveal[team]) > 0 then

					for revealedMine in pairs(revealedMines[team]) do
						if minesToReveal[team][revealedMine] == nil then
							--reset this team mask
							Spring.SetUnitLosMask(revealedMine, team, 0)
							revealedMines[team][revealedMine] = nil
						end
					end
				else
					--if empty and previously decloaked not empty, reset all mines
					for revealedMine in pairs(revealedMines[team]) do
						Spring.SetUnitLosMask(revealedMine, team, 0)
						revealedMines[team][revealedMine] = nil
					end
				end

			end

		end


	end


end
---Spring.SetUnitLosState(unitID, allyTeamID, 2) to force a unit to be in radar of that allyteam
---Spring.SetUnitLosMask(unitID, allyTeamID, 2) to prevent engine from immediately resetting that state
---don't forget to set mask to 0 when out of sensor range (don't set state though, maybe the target is in actual radar. engine will take care of it) 


		-- add those mines to the decloaked list


		----Spring.Debug.TableEcho(unitSlowed)
