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
local minesweeperRanges = {}
local mineIDs = {}

--Spring.Echo('hornet ms loaded')

local teamList = Spring.GetTeamList()
local teamIDs = {}

local revealedMines = {}
--Spring.Debug.TableEcho(teamList)
for i = 1, #teamList do
    teamIDs[teamList[i]] = teamList[i]
	revealedMines[teamList[i]] = {}
end
--Spring.Debug.TableEcho(teamIDs)
--Spring.Echo('hornet revealedMines')
--Spring.Debug.TableEcho(revealedMines)




for udid, ud in pairs(UnitDefs) do
	if ud.customParams and ud.customParams.minesweeper then
		minesweeperIDs[udid] = udid
		minesweeperRanges[udid] = ud.customParams.minesweeper
	end
end


for udid, ud in pairs(UnitDefs) do
	if ud.customParams and ud.customParams.mine then
		mineIDs[udid] = udid
	end
end

--Spring.Echo('hornet poi minesweeperIDs')
--Spring.Debug.TableEcho(minesweeperIDs)

--Spring.Echo('hornet mineIDs')
--Spring.Debug.TableEcho(mineIDs)


function gadget:Initialize()
	if table.count(minesweeperIDs) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end
	if table.count(mineIDs) <= 0 then
		gadgetHandler:RemoveGadget(self)
	end
end



function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	--Spring.Echo('hornet poi 79 minesweeperIDs[unitDefID], unitDefID, unitID', minesweeperIDs[unitDefID], unitDefID, unitID)
	if minesweeperIDs[unitDefID] then
		minesweepers[unitID] = unitDefID
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
			for miner, minerdef in pairs(minesweepers) do

				--Spring.Echo('hornet miner', miner)
				--Spring.Echo('hornet minerdef', minerdef)

				
				local minerTeam = Spring.GetUnitTeam(miner)--this sometimes seems to be 0, should it be? is 0 gaia or 'team 1' ? try with built minelayers rather than spawned? try to give units to team 2 and see if they;re blue or gaia?
				local x, y, z = Spring.GetUnitPosition(miner)
				local nearUnits = Spring.GetUnitsInCylinder(x, z, minesweeperRanges[minerdef])

				--Spring.Echo('hornet minerTeam', minerTeam)
				--Spring.Echo('hornet minerdef minesweeperRanges[minerdef]', minerdef, minesweeperRanges[minerdef])

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