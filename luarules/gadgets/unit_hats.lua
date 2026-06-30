
if Spring.GetModOptions().teamcolors_anonymous_mode ~= "disabled" then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Hats",
		desc = "Handles cosmetic-only hat behaviour",
		author = "Beherith",
		date = "2020",
		license   = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

-- We need to keep track of all hats unitdefs, and watch what happens to them
-- hats, can be equipped by capturing them -- or by being given one?
--    if a commando captures a hat, it is destroyed
--    if a hat is already present on a commander, then it is destroyed
-- if the wearer dies, detach the hat
-- decoys?
--  if decoys cant wear hats, then it becomes obvious
--  so decoys will be able to wear hats
-- giving:
-- wearer loses hat if given comm with hat
-- hats should not prevent game end! as they arent real units
-- attachunit somehow does not pass the direction, and passes the position of the piece attached to it about 1 frame late
-- consider manually repositioning hats then? could start to get expensive
-- You cant pick up allied hats
-- Hats should not prevent game ending if they are the only unit left.
-- e.g. dying comms should give hats to gaia

-- Notes:
-- hat wearing units must have unitdef holdsteady = true to give the piece orientations
-- hats have nonzero mass and can stop commanders from being able to use T1 transports (see 5c4b8a3)
-- hat pos is 1 frame off :/

if not gadgetHandler:IsSyncedCode() then
	return
end

local DEBUG = false

local unitsWearingHats = {} -- key unitID of wearer, value unitID of hat

local Hats = {}  -- key of unitID of hat, value of wearer unitID

local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitArmored = Spring.SetUnitArmored
local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spCreateUnit = Spring.CreateUnit
local function spGetUnitScriptEnv(unitID)
	local unitScript = Spring.UnitScript
	if unitScript and unitScript.GetScriptEnv then
		return unitScript.GetScriptEnv(unitID)
	end
	return nil
end
local spCallAsUnit = Spring.UnitScript.CallAsUnit
local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local stringSub = string.sub

local hatDefHalloween = UnitDefNames.cor_hat_hw and UnitDefNames.cor_hat_hw.id
local hatDefLegChamp = UnitDefNames.cor_hat_legfn and UnitDefNames.cor_hat_legfn.id
local hatDefFightNight = UnitDefNames.cor_hat_fightnight and UnitDefNames.cor_hat_fightnight.id
local hatDefViking = UnitDefNames.cor_hat_viking and UnitDefNames.cor_hat_viking.id

local unitDefHat = {}
for udid, ud in pairs(UnitDefs) do
	--almost all raptors have dying anims
	if ud.customParams.subfolder and ud.customParams.subfolder == "other/hats" then
		unitDefHat[udid] = true
	end
end

local unitDefCanWearHats = {
	[UnitDefNames.corcom.id] = true,
	[UnitDefNames.cordecom.id] = true,
	[UnitDefNames.armcom.id] = true,
	[UnitDefNames.armdecom.id] = true,
}

 if Spring.GetModOptions().experimentallegionfaction then
	unitDefCanWearHats[UnitDefNames.legcom.id] = true
	unitDefCanWearHats[UnitDefNames.legcomlvl2.id] = true
	unitDefCanWearHats[UnitDefNames.legcomlvl3.id] = true
	unitDefCanWearHats[UnitDefNames.legcomlvl4.id] = true
 end
 local halloween = {
 }
 local legchamps = { -- Legion Fight Night winner(s)
	[144092] = true, -- [DmE]Wraxell
	[42178] = true,  -- [pretor]
	[119539] = true, -- [Stud]Lovish
	[641] = true, -- ZLO
}
local champion = { --   Fight Night 1v1 and Master's League winners
	[139738] = true, -- [DmE]FlyingDuck
	[82263] = true, -- TM_autopilot
	[975] = true, -- StarDoM
	[2377] = true, -- Therxyy
	[439] = true, -- Goopy
	[70311] = true, -- PRO_BTCV
}
 local vikings = { -- Omega Series 4: Winners
	[59916] = true,	 -- Kuchy
	[151863] = true,  -- Blodir
	[3913] = true,	 -- [teh]Teddy
	[1172] = true,	 -- PtaQ
	[694] = true,	 -- Raghna
	[5467] = true,  -- HelsHound
	[50820] = true,   -- Emre
}
local kings = {
	[82263] = true,  -- TM_autopilot
}

local goldMedals = { -- last season top1 finishers
	[50820] = true,  -- Emre

	-- BAR Pro League
	[151863] = true,  -- Blodir
}
local silverMedals = { -- last season top2 finishers
	[151863] = true,  -- Blodir
	[1332] = true,  -- Flash
	[915] = true,  -- PRO_rANDY

	-- BAR Pro League
	[915] = true,  -- PRO_rANDY
}
local bronzeMedals = { -- last season top3 finishers
	[82263] = true, -- TM_autopilot
	[70311] = true, -- PRO_BTCV
	[142011] = true, -- [BAC]OutlawElite
	[53682] = true, -- PROt_Fiddler112

}
local uniques = {--playername, hat ident, CaSe MaTtErS
}

local function MatchPlayer(awardees, name, accountID)
	if awardees[name] or (accountID and awardees[accountID]) then
		return true
	end
	return false
end

local spawnWarpInFrame = Game.spawnWarpInFrame
local spawnAwardsProcessed = false

local function UpdateGameFrameCallIn()
	if spawnAwardsProcessed and next(unitsWearingHats) == nil then
		gadgetHandler:RemoveCallIn("GameFrame")
	else
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function CreateAndGiveHat(hatDefID, unitPosX, unitPosY, unitPosZ, teamID)
	local createdHatID = spCreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
	if createdHatID then
		gadget:UnitGiven(createdHatID, hatDefID, teamID)
	end
end

function gadget:GameFrame(gf)
	if gf == spawnWarpInFrame then
		for _, playerID in ipairs(spGetPlayerList() or {}) do

			local accountID = nil
			local playerName, _, spec, teamID, _, _, _, _, _, _, accountInfo = spGetPlayerInfo(playerID)
			if accountInfo and accountInfo.accountid then
				accountID = tonumber(accountInfo.accountid)
			end

			if not spec then
				local shouldGiveHalloweenHat = (hatDefHalloween ~= nil) and MatchPlayer(halloween, playerName, accountID)
				local shouldGiveLegHat = (hatDefLegChamp ~= nil) and MatchPlayer(legchamps, playerName, accountID)
				local shouldGiveFightNightHat = (hatDefFightNight ~= nil) and MatchPlayer(champion, playerName, accountID)
				local shouldGiveVikingHat = (hatDefViking ~= nil) and MatchPlayer(vikings, playerName, accountID)
				local hasUniqueHat = (uniques[playerName] ~= nil) and (UnitDefNames['cor_hat_' .. uniques[playerName]] ~= nil)
				local shouldShowCrown = MatchPlayer(kings, playerName, accountID)
				local shouldShowGold = MatchPlayer(goldMedals, playerName, accountID)
				local shouldShowSilver = MatchPlayer(silverMedals, playerName, accountID)
				local shouldShowBronze = MatchPlayer(bronzeMedals, playerName, accountID)

				if shouldGiveHalloweenHat or shouldGiveLegHat or shouldGiveFightNightHat or shouldGiveVikingHat or hasUniqueHat or shouldShowCrown or shouldShowGold or shouldShowSilver or shouldShowBronze then
					local units = spGetTeamUnits(teamID) or {}
					for k = 1, #units do
						local unitID = units[k]
						local unitDefID = spGetUnitDefID(unitID)

						if unitDefCanWearHats[unitDefID] then
							local needHatSpawn = shouldGiveHalloweenHat or shouldGiveLegHat or shouldGiveFightNightHat or shouldGiveVikingHat or hasUniqueHat
							local unitPosX, unitPosY, unitPosZ
							if needHatSpawn then
								unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
							end

							if shouldGiveHalloweenHat then
								CreateAndGiveHat(hatDefHalloween, unitPosX, unitPosY, unitPosZ, teamID)
							end

							if shouldGiveLegHat then
								CreateAndGiveHat(hatDefLegChamp, unitPosX, unitPosY, unitPosZ, teamID)
							end

							if shouldGiveFightNightHat then
								CreateAndGiveHat(hatDefFightNight, unitPosX, unitPosY, unitPosZ, teamID)
							end

							if shouldGiveVikingHat then
								CreateAndGiveHat(hatDefViking, unitPosX, unitPosY, unitPosZ, teamID)
							end

							if hasUniqueHat then
								local uniqueHatDefID = UnitDefNames['cor_hat_' .. uniques[playerName]].id
								CreateAndGiveHat(uniqueHatDefID, unitPosX, unitPosY, unitPosZ, teamID)
							end

							if stringSub(UnitDefs[unitDefID].name, 1, 3) == 'arm' then
								local scriptEnv = spGetUnitScriptEnv(unitID)
								if scriptEnv then
									if shouldShowCrown and scriptEnv['ShowCrown'] then
										spCallAsUnit(unitID, scriptEnv['ShowCrown'], true)
									end
									if shouldShowGold and scriptEnv['ShowMedalGold'] then
										spCallAsUnit(unitID, scriptEnv['ShowMedalGold'], true)
									end
									if shouldShowSilver and scriptEnv['ShowMedalSilver'] then
										spCallAsUnit(unitID, scriptEnv['ShowMedalSilver'], true)
									end
									if shouldShowBronze and scriptEnv['ShowMedalBronze'] then
										spCallAsUnit(unitID, scriptEnv['ShowMedalBronze'], true)
									end
								end
							else
								if shouldShowCrown and spGetCOBScriptID(unitID, 'ShowCrown') then
									spCallCOBScript(unitID, "ShowCrown", 0)
								end
								if shouldShowGold and spGetCOBScriptID(unitID, 'ShowMedalGold') then
									spCallCOBScript(unitID, "ShowMedalGold", 0)
								end
								if shouldShowSilver and spGetCOBScriptID(unitID, 'ShowMedalSilver') then
									spCallCOBScript(unitID, "ShowMedalSilver", 0)
								end
								if shouldShowBronze and spGetCOBScriptID(unitID, 'ShowMedalBronze') then
									spCallCOBScript(unitID, "ShowMedalBronze", 0)
								end
							end
						end
					end
				end
			end
		end
		spawnAwardsProcessed = true
		UpdateGameFrameCallIn()
	end

	-- periodically update hat health	(damage gets applied instantly at gadget:UnitDamaged anyway)
	if gf % 61 == 1 and next(unitsWearingHats) ~= nil then
		for unitID, hatUnitID in pairs(unitsWearingHats) do
			local health, maxHealth = spGetUnitHealth(unitID)
			local hatHealth, hatMaxHealth = spGetUnitHealth(hatUnitID)
			if health and maxHealth and hatMaxHealth then
				Spring.SetUnitHealth(hatUnitID, (health / maxHealth) * hatMaxHealth)
			else
				unitsWearingHats[unitID] = nil
			end
		end
		UpdateGameFrameCallIn()
	end
end

--Spring.GetUnitPiecePosDir

--( number unitID, number pieceNum ) -> nil | number posX, number posY, number posZ,
-- number dirX, number dirZ, number dirY

--Returns piece position and direction in world space. The direction (dirX, dirY, dirZ) is not necessarily normalized. The position is defined as the position of the first vertex of the piece and it defines direction as the direction in which the line --from the first vertex to the second vertex points. -> e.g. hats need two null vertices


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	-- for unitID reuse, just in case
	if unitDefHat[unitDefID] then

		if DEBUG then
			Spring.Echo("hat created", unitID, unitDefID, unitTeam, builderID)
		end
		Hats[unitID] = -1
		Spring.SetUnitNeutral(unitID, true)
		spSetUnitArmored(unitID, true, 0)
		Spring.SetUnitBlocking(unitID, false, false, false, false) -- non blocking while dying
		Spring.SetUnitNoMinimap(unitID, true)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if Hats[unitID] ~= nil then
		if DEBUG then
			Spring.Echo("A hat was destroyed", unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		end
		Hats[unitID] = nil
	end
	if unitsWearingHats[unitID] ~= nil then
		local hatID = unitsWearingHats[unitID]
		if DEBUG then
			Spring.Echo("A hat wearing unit was destroyed, freeing hat", unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		end
		Spring.UnitDetachFromAir(hatID)
		Spring.UnitDetach(hatID)
		unitsWearingHats[unitID] = nil
		Hats[hatID] = -1
		Spring.SetUnitNoSelect(hatID, false)
		Spring.TransferUnit(hatID, spGetGaiaTeamID()) -- ( number unitID,  numer newTeamID [, boolean given = true ] ) -> nil if given=false, the unit is captured
		local px, py, pz = Spring.GetUnitPosition(unitID)
		if px and pz then
			Spring.SetUnitPosition(hatID, px + 32, pz + 32)
		end
		UpdateGameFrameCallIn()
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		if DEBUG then
			Spring.Echo("A hat wearing unit was given, destroying hat", unitID, unitDefID, unitTeam, unitsWearingHats[unitID])
		end
		Spring.DestroyUnit(unitsWearingHats[unitID])
		unitsWearingHats[unitID] = nil
	end
	if Hats[unitID] then

		local hatID = unitID
		if unitTeam == spGetGaiaTeamID() then
			if DEBUG then
				Spring.Echo("A hat was given back to gaia", hatID, unitDefID, unitTeam, spGetGaiaTeamID())
			end
			return
		end

		if DEBUG then
			Spring.Echo("A hat was given, finding a wearer", hatID, unitDefID, unitTeam)
		end
		-- find nearest commander and attach hat onto him?
		local hx, hy, hz = Spring.GetUnitPosition(hatID)
		if hx then
			for ct, nearunitID in pairs(Spring.GetUnitsInCylinder(hx, hz, 200, unitTeam)) do
				local neardefID = Spring.GetUnitDefID(nearunitID)
				if unitDefCanWearHats[neardefID] then

					if DEBUG then
						Spring.Echo("Found a wearer", nearunitID, hatID, unitDefID, unitTeam)
					end

					local pieceMap = Spring.GetUnitPieceMap(nearunitID)
					local hatPoint = nil
					for pieceName, pieceNum in pairs(pieceMap) do
						if pieceName:find("hatpoint", nil, true) then
							hatPoint = pieceNum
							break
						end
					end

					if DEBUG then
						Spring.Echo("Found a point", nearunitID, hatPoint)
					end

					--Spring.MoveCtrl.Enable(unitID)
					Spring.UnitAttach(nearunitID, hatID, hatPoint)
					Spring.SetUnitNoDraw(hatID, false)
					Spring.SetUnitNoSelect(hatID, true)
					--Spring.MoveCtrl.Disable(unitID)
					--Spring.SetUnitLoadingTransport(unitID, nearunitID)
					unitsWearingHats[nearunitID] = hatID
					Hats[hatID] = nearunitID
					UpdateGameFrameCallIn()
					return
				end
			end
		end
		if DEBUG then
			Spring.Echo("Hat was given, but found noone to put it onto, destroying", hatID)
		end
		Spring.DestroyUnit(hatID)
	end
end

-- also damage the hat
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitsWearingHats[unitID] then
		local health, maxHealth = spGetUnitHealth(unitID)
		local hatHealth, hatMaxHealth = spGetUnitHealth(unitsWearingHats[unitID])
		if hatHealth and health and maxHealth and hatMaxHealth then
			Spring.SetUnitHealth(unitsWearingHats[unitID], (health / maxHealth) * hatMaxHealth)
		end
	end
end

-- also cloak hat
function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		Spring.SetUnitCloak(unitsWearingHats[unitID], 1)
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		Spring.SetUnitCloak(unitsWearingHats[unitID], 0)
	end
end
