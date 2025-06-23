
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
 local halloween = { -- Halloween Fight Night winner
 	[139750] = true, ---Sashkorin
 }
 local legchamps = { -- Legion Fight Night winner(s)
	[144092] = true, -- [DmE]Wraxell
	[42178] = true,  -- [pretor]
	[119539] = true, -- [Stud]Lovish
	[641] = true, -- ZLO
}
local champion = { --   Fight Night 1v1 and Master's League winners
	[139738] = true, -- [DmE]FlyingDuck
	[82263] = true, -- PRO_Autopilot
	[975] = true, -- StarDoM
	[2377] = true, -- Therxyy
	[439] = true, -- Goopy
}
 local vikings = { -- Omega Series 3: Winners
	[59340] = true,  -- Austin
	[1830] = true,   -- Zow
	[59916] = true,	 -- Kuchy
	[24665] = true,  -- Shoty
	[38971] = true,  -- Chisato
	[87571] = true,  -- Nezah
}
local kings = {
	[82263] = true,  -- PRO-autopilot
}
local goldMedals = { -- Nation Wars 1st place
	[64215] = true,  -- XFactorLive
	[116414] = true,  -- [SG]random_variable
	[3778] = true,  -- PRO_che
	[9361] = true, -- [DmE]ChickenDinner
	[1422] = true,  -- ZaRxT4
}
local silverMedals = { -- Nation Wars 2nd place
	-- [76221] = true, -- InDaClub
	-- [82263] = true, -- PRO-autopilot
}
local bronzeMedals = { -- Nation Wars 3rd place
	-- [151863] = true,  -- Blodir
	-- [38971] = true, -- Yanami
	-- [123900] = true, -- Narnuk
}
local uniques = {--playername, hat ident, CaSe MaTtErS
}

local function MatchPlayer(awardees, name, accountID)
	if awardees[name] or (accountID and awardees[accountID]) then
		return true
	end
	return false
end

function gadget:GameFrame(gf)
	if gf == 90 then
		for _, playerID in ipairs(Spring.GetPlayerList()) do

			local accountID = false
			local playerName, _, spec, teamID, _, _, _, _, _, _, accountInfo = Spring.GetPlayerInfo(playerID)
			if accountInfo and accountInfo.accountid then
				accountID = tonumber(accountInfo.accountid)
			end

			if not spec then
				local units = Spring.GetTeamUnits(teamID)
				for k = 1, #units do
					local unitID = units[k]
					local unitDefID = Spring.GetUnitDefID(unitID)
					local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(unitID)

					if unitDefCanWearHats[unitDefID] then

						if MatchPlayer(halloween, playerName, accountID) and UnitDefNames['cor_hat_hw'] then
							local hatDefID = UnitDefNames['cor_hat_hw'].id
							local unitID = Spring.CreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
							gadget:UnitGiven(unitID, hatDefID, teamID)
						end

						if MatchPlayer(legchamps, playerName, accountID) and UnitDefNames['cor_hat_legfn'] then
							local hatDefID = UnitDefNames['cor_hat_legfn'].id
							local unitID = Spring.CreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
							gadget:UnitGiven(unitID, hatDefID, teamID)
						end

						if MatchPlayer(champion, playerName, accountID) and UnitDefNames['cor_hat_fightnight'] then
							local hatDefID = UnitDefNames['cor_hat_fightnight'].id
							local unitID = Spring.CreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
							gadget:UnitGiven(unitID, hatDefID, teamID)
						end

						if MatchPlayer(vikings, playerName, accountID) and UnitDefNames['cor_hat_viking'] then
							local hatDefID = UnitDefNames['cor_hat_viking'].id
							local unitID = Spring.CreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
							gadget:UnitGiven(unitID, hatDefID, teamID)
						end

						if (uniques[playerName]~=nil) and (UnitDefNames['cor_hat_' .. uniques[playerName]] ~= nil) then
							local hatDefID = UnitDefNames['cor_hat_' .. uniques[playerName]].id
							local unitID = Spring.CreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
							gadget:UnitGiven(unitID, hatDefID, teamID)
						end

						if string.sub(UnitDefs[unitDefID].name, 1, 3) == 'arm' then
							local scriptEnv = Spring.UnitScript.GetScriptEnv(unitID)
							if scriptEnv then
								if MatchPlayer(kings, playerName, accountID) and scriptEnv['ShowCrown'] then
									Spring.UnitScript.CallAsUnit(unitID, scriptEnv['ShowCrown'], true)
								end
								if MatchPlayer(goldMedals, playerName, accountID) and scriptEnv['ShowMedalGold'] then
									Spring.UnitScript.CallAsUnit(unitID, scriptEnv['ShowMedalGold'], true)
								end
								if MatchPlayer(silverMedals, playerName, accountID) and scriptEnv['ShowMedalSilver'] then
									Spring.UnitScript.CallAsUnit(unitID, scriptEnv['ShowMedalSilver'], true)
								end
								if MatchPlayer(bronzeMedals, playerName, accountID) and scriptEnv['ShowMedalBronze'] then
									Spring.UnitScript.CallAsUnit(unitID, scriptEnv['ShowMedalBronze'], true)
								end
							end
						else
							if MatchPlayer(kings, playerName, accountID) and Spring.GetCOBScriptID(unitID, 'ShowCrown') then
								Spring.CallCOBScript(unitID, "ShowCrown", 0)
							end
							if MatchPlayer(goldMedals, playerName, accountID) and Spring.GetCOBScriptID(unitID, 'ShowMedalGold') then
								Spring.CallCOBScript(unitID, "ShowMedalGold", 0)
							end
							if MatchPlayer(silverMedals, playerName, accountID) and Spring.GetCOBScriptID(unitID, 'ShowMedalSilver') then
								Spring.CallCOBScript(unitID, "ShowMedalSilver", 0)
							end
							if MatchPlayer(bronzeMedals, playerName, accountID) and Spring.GetCOBScriptID(unitID, 'ShowMedalBronze') then
								Spring.CallCOBScript(unitID, "ShowMedalBronze", 0)
							end
						end
					end
				end
			end
		end
	end

	-- periodically update hat health	(damage gets applied instantly at gadget:UnitDamaged anyway)
	if gf % 61 == 1 then
		for unitID, hatUnitID in pairs(unitsWearingHats) do
			local health, maxHealth = Spring.GetUnitHealth(unitID)
			local hatHealth, hatMaxHealth = Spring.GetUnitHealth(hatUnitID)
			if hatMaxHealth then
				Spring.SetUnitHealth(hatUnitID, (health / maxHealth) * hatMaxHealth)
			else
				unitsWearingHats[hatUnitID] = nil
			end
		end
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
		Spring.TransferUnit(hatID, Spring.GetGaiaTeamID()) -- ( number unitID,  numer newTeamID [, boolean given = true ] ) -> nil if given=false, the unit is captured
		local px, py, pz = Spring.GetUnitPosition(unitID)
		Spring.SetUnitPosition(hatID, px + 32, pz + 32)
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
		if unitTeam == Spring.GetGaiaTeamID() then
			if DEBUG then
				Spring.Echo("A hat was given back to gaia", hatID, unitDefID, unitTeam, Spring.GetGaiaTeamID())
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

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	if Hats[unitID] then
		return 0, 0
	else
		return damage,1
	end
end

-- also damage the hat
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitsWearingHats[unitID] then
		local health, maxHealth = Spring.GetUnitHealth(unitID)
		local hatHealth, hatMaxHealth = Spring.GetUnitHealth(unitsWearingHats[unitID])
		if hatHealth then
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
