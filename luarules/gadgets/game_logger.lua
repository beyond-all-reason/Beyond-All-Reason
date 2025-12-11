
if Spring.Utilities.Gametype.IsSinglePlayer() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Logger",
        desc      = "log certain events of interest",
        author    = "Floris",
        date      = "April 2023",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then

	local mathRandom = math.random
	local stringChar = string.char
	local tableInsert = table.insert

	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do tableInsert(charset, stringChar(c)) end
		for c = 65, 90  do tableInsert(charset, stringChar(c)) end
		for c = 97, 122 do tableInsert(charset, stringChar(c)) end
	end
	local function randomString(length)
		if not length or length <= 0 then return '' end
		return randomString(length - 1) .. charset[mathRandom(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationLog = validation

else

	local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local validation = SYNCED.validationLog

	local isCommander = {}
	local isEcoUnit = {}
	for udefID, def in ipairs(UnitDefs) do
		if def.customParams.iscommander then
			isCommander[udefID] = true
		end
		if not def.canMove then
			if def.metalMake > 0.5 or def.energyMake > 5 or def.energyUpkeep < 0 or def.windGenerator > 0 or def.tidalGenerator > 0 or def.customParams.solar or def.customParams.energyconv_capacity then
				isEcoUnit[udefID] = true
			end
		end
	end

	local isDgun = {}
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.type == 'DGun' and weaponDef.damages  then -- to filter out decoy comm -- and weaponDef.damage.default > 5000
			for _, v in pairs(weaponDef.damages) do
				if v > 99000 then
					isDgun[weaponDefID] = true
				end
			end
		end
	end

	local myTeamID = Spring.GetMyTeamID()
	local myPlayerID = Spring.GetMyPlayerID()
	local mySpec, fullview = Spring.GetSpectatingState()

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myTeamID = Spring.GetMyTeamID()
			mySpec, fullview = Spring.GetSpectatingState()
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		--Spring.Echo("gadget:UnitDestroyed", unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		-- Only send a message from the attacker, when attacking a different team
		if (not mySpec and attackerTeam == myTeamID) and (unitTeam ~= attackerTeam) then 
			-- Check if its a commander doing shenanigan to others eco units
			if (isEcoUnit[unitDefID] or isCommander[unitDefID]) and spAreTeamsAllied(unitTeam, attackerTeam) and isCommander[attackerDefID] then
				-- This is an 'only attack friendlies with commander' type thing
				local msg = string.format("l0g%s:friendlyfire:%d:%s:%d:%d:%d", validation,
					Spring.GetGameFrame(), 'ud',
					unitTeam, attackerTeam, unitDefID)
				--Spring.Echo(msg)
				spSendLuaRulesMsg(msg)
			end
		end
	end
	
	function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
		if not mySpec and transportTeam == myTeamID and unitTeam ~= transportTeam and isCommander[unitDefID] then 
			local _, _, _, isAiTeam = Spring.GetTeamInfo(unitTeam, false)
			if isAiTeam then return end
			local msg = string.format("l0g%s:allycommloaded:%d:%s:%d:%d:%d", validation,
			Spring.GetGameFrame(), 'ud',
			unitTeam, transportTeam, unitDefID)
			spSendLuaRulesMsg(msg)
		end
	end
end
