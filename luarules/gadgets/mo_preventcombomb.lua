local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "preventcombomb",
		desc      = "Commanders survive commander blast",
		author    = "TheFatController",
		date      = "Aug 31, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local GetTeamInfo = Spring.GetTeamInfo
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitHealth = Spring.GetUnitHealth
local GetGroundHeight = Spring.GetGroundHeight
local GetTeamUnitDefCount = Spring.GetTeamUnitDefCount
local GetTeamList = Spring.GetTeamList
local MoveCtrlEnable = Spring.MoveCtrl.Enable
local MoveCtrlDisable = Spring.MoveCtrl.Disable
local MoveCtrlSetPosition = Spring.MoveCtrl.SetPosition
local GetGameFrame = Spring.GetGameFrame
local DestroyUnit = Spring.DestroyUnit
local GetUnitTeam = Spring.GetUnitTeam
local math_random = math.random

local immuneDgunList = {}
local ctrlCom = {}
local cantFall = {}

-- Cache for commander counts per team per frame
local commCountCache = {}
local commCountCacheFrame = -1

local COM_BLAST = WeaponDefNames['commanderexplosion'].id

local isCommander = {}
local commanderDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
		commanderDefIDs[#commanderDefIDs + 1] = unitDefID
	end
end

local function CommCount(unitTeam)
	local currentFrame = GetGameFrame()
	
	-- Use cached result if available for this frame
	if commCountCacheFrame == currentFrame and commCountCache[unitTeam] then
		return commCountCache[unitTeam]
	end
	
	-- Clear cache if this is a new frame
	if commCountCacheFrame ~= currentFrame then
		commCountCache = {}
		commCountCacheFrame = currentFrame
	end
	
	local allyTeamID = select(6, GetTeamInfo(unitTeam, false))
	local teamsInAlly = GetTeamList(allyTeamID)
	
	local count = 0
	if teamsInAlly then
		for i = 1, #teamsInAlly do
			local teamID = teamsInAlly[i]
			for j = 1, #commanderDefIDs do
				count = count + GetTeamUnitDefCount(teamID, commanderDefIDs[j])
			end
		end
	end
	
	-- Cache the result
	commCountCache[unitTeam] = count
	return count
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	--falling & debris damage
	if weaponID < 0 and cantFall[unitID] then
		return 0, 0
	end

	if weaponID == COM_BLAST then
		local hp = GetUnitHealth(unitID)
		if not hp then
			return damage
		end
		
		local combombDamage = hp - 200 - math_random(1, 10)
		if combombDamage < 0 then
			combombDamage = 0
		elseif combombDamage > hp * 0.33 then
			combombDamage = hp * 0.33
		end
		if combombDamage > damage then
			combombDamage = damage
		end

		if weaponID == COM_BLAST and isCommander[unitDefID] and attackerID then
			local unitTeamID = GetUnitTeam(unitID)
			local attackerTeamID = GetUnitTeam(attackerID)
			
			if unitTeamID and attackerTeamID and CommCount(unitTeamID) <= 1 and CommCount(attackerTeamID) <= 1 then
				if unitID ~= attackerID then
					-- make unitID immune to DGun
					local currentFrame = GetGameFrame()
					immuneDgunList[unitID] = currentFrame + 45
					--prevent falling damage to the unitID, and lock position
					MoveCtrlEnable(unitID)
					ctrlCom[unitID] = currentFrame + 30
					cantFall[unitID] = currentFrame + 30
					return combombDamage, 0
				else
					--com blast hurts the attackerID
					return damage
				end
			end
		end
	end
	return damage
end

function gadget:GameFrame(currentFrame)
	-- Process all expired entries in a single pass
	for unitID, expirationTime in pairs(immuneDgunList) do
		if currentFrame > expirationTime then
			immuneDgunList[unitID] = nil
		end
	end
	
	for unitID, expirationTime in pairs(ctrlCom) do
		if currentFrame > expirationTime then
			local x, _, z = GetUnitPosition(unitID)
			if x then
				local y = GetGroundHeight(x, z)
				MoveCtrlSetPosition(unitID, x, y, z)
				MoveCtrlDisable(unitID)
				cantFall[unitID] = currentFrame + 220
			else
				cantFall[unitID] = nil
			end
			ctrlCom[unitID] = nil
		end
	end
	
	for unitID, expirationTime in pairs(cantFall) do
		if currentFrame > expirationTime then
			cantFall[unitID] = nil
		end
	end
end
