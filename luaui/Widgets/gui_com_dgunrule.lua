function widget:GetInfo()
	return {
		name = "Dgun Rule Reminder2",	-- renamed with 2 so its now default disabled
		desc = ".",
		author = "Floris",
		date = "June 2022",
		license = "GNU GPL, v2 or later",
		layer = -2,
		enabled = false,
	}
end

local maxOccurrenceCount = 4	-- removing widget when it has displayed the tooltip this many times

local vsx, vsy = Spring.GetViewGeometry()

local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitVisible = Spring.IsUnitVisible
local spIsUnitIcon = Spring.IsUnitIcon
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

local spGetUnitsInSphere = Spring.GetUnitsInSphere
local CMD_MANUALFIRE = CMD.MANUALFIRE

local spec = Spring.GetSpectatingState()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local nearbyEnemyComs = {}
local prevNearbyEnemyComs = {}

local occurrenceCount = 0
local occurred = false

local allyComs = 0
local enemyComs = 0 -- if we are counting ourselves because we are a spec
local enemyComCount = 0 -- if we are receiving a count from the gadget part (needs modoption on)
local prevEnemyComCount = 0

local isCommander = {}
local isDgun = {}
for unitDefID, defs in pairs(UnitDefs) do
	if defs.customParams.iscommander then
		isCommander[unitDefID] = defs.height
		for _, weapon in ipairs(defs.weapons) do
			if weapon.weaponDef then
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if weaponDef.type == "DGun" then
					isDgun[weapon.weaponDef] = true
				end
			end
		end
	end
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.4 then
		sec = 0

		nearbyEnemyComs = {}

		local _, cmd, _ = Spring.GetActiveCommand()
		if cmd == CMD_MANUALFIRE and allyComs == 1 then
			-- get all selected commanders
			local selComsCount = 0
			local selComs = {}
			local selUnits = Spring.GetSelectedUnitsSorted()
			for unitDefID, units in pairs(selUnits) do
				if isCommander[unitDefID] then
					for i, unitID in pairs(units) do
						local ux, uy, uz = spGetUnitPosition(units[1])
						selComs[unitID] = {ux, uy, uz}
						selComsCount = selComsCount + 1
					end
				end
			end

			if selComsCount > 0 then
				-- see if there are commanders near mouse cursor position
				local mx, my = Spring.GetMouseState()
				local mouseTargetType, mouseTarget = Spring.TraceScreenRay(mx, my)
				if mouseTargetType then
					local x,y,z
					if mouseTargetType == 'unit' then
						x,y,z = spGetUnitPosition(mouseTarget)
					elseif mouseTargetType == 'feature' then
						x,y,z = Spring.GetFeaturePosition(mouseTarget)
					else
						x,y,z = mouseTarget[1], mouseTarget[2], mouseTarget[3]
					end
					-- check for nearby enemy commanders
					local units = spGetUnitsInSphere(x,y,z, 270)
					local nearbySelectedCom = false
					for i, unitID in pairs(units) do
						if isCommander[spGetUnitDefID(unitID)] then
							if spGetUnitAllyTeam(unitID) == myAllyTeamID then
								nearbySelectedCom = true
							else
								nearbyEnemyComs[unitID] = true
							end
						end
					end

					if not nearbySelectedCom then
						nearbyEnemyComs = {}
					elseif not occurred then
						occurred = true
						occurrenceCount = occurrenceCount + 1
					end
				end
			end
		end

	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
end


function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	prevNearbyEnemyComs = nearbyEnemyComs
	for unitID, _ in pairs(prevNearbyEnemyComs) do
		if not nearbyEnemyComs[unitID] then
			WG['tooltip'].RemoveTooltip('dgunrule'..unitID)
		end
	end
	if WG['tooltip'] then
		for unitID, _ in pairs(nearbyEnemyComs) do
			if spIsUnitVisible(unitID) and not spIsUnitIcon(unitID) then
				local ux, uy, uz = spGetUnitPosition(unitID)
				local camX, camY, camZ = Spring.GetCameraPosition()
				local camDistance = math.diag(camX - ux, camY - uy, camZ - uz)
				if camDistance < 3000 then
					local x, y = Spring.WorldToScreenCoords(ux, uy+140, uz)
					WG['tooltip'].ShowTooltip('dgunrule'..unitID, Spring.I18N('ui.dgunrule.enemycom'), x, y)
				end
			end
		end
	end
end


local function countComs()
	-- recount my own ally team coms
	local prevAllyComs = allyComs
	local prevEnemyComs = enemyComs
	allyComs = 0
	for _, teamID in ipairs(myAllyTeamList) do
		for unitDefID,_ in pairs(isCommander) do
			allyComs = allyComs + Spring.GetTeamUnitDefCount(teamID, unitDefID)
		end
	end

	local newEnemyComCount = Spring.GetTeamRulesParam(myTeamID, "enemyComCount")
	if type(newEnemyComCount) == 'number' then
		enemyComCount = newEnemyComCount
		if enemyComCount ~= prevEnemyComCount then
			--comcountChanged = true
			prevEnemyComCount = enemyComCount
		end
	end
end

function widget:Initialize()
	if Spring.GetModOptions().deathmode ~= "com" and Spring.GetModOptions().deathmode ~= "own_com" then
		widgetHandler:RemoveWidget()
		return
	end
	countComs()
end

function widget:Shutdown()
	for unitID, _ in pairs(nearbyEnemyComs) do
		WG['tooltip'].RemoveTooltip('dgunrule'..unitID)
	end
end

function widget:PlayerChanged(playerID)
	local prevSpec = spec
	spec = Spring.GetSpectatingState()
	--if spec and prevSpec ~= spec then
	--	CheckTeamColors()
	--	RemoveLists()
	--end
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
	countComs()
end


function widget:UnitEnteredLos(unitID, unitTeam)

end

function widget:UnitLeftLos(unitID, unitTeam)
	if nearbyEnemyComs[unitID] then
		nearbyEnemyComs[unitID] = nil
		if WG['tooltip'] then
			WG['tooltip'].RemoveTooltip('dgunrule'..unitID)
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		countComs()
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		if nearbyEnemyComs[unitID] then
			nearbyEnemyComs[unitID] = nil
			if WG['tooltip'] then
				WG['tooltip'].RemoveTooltip('dgunrule'..unitID)
			end
		end
		countComs()
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if isCommander[unitDefID] then
		countComs()
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if isCommander[unitDefID] then
		countComs()
	end
end

function widget:GetConfigData()
	return {
		occurrenceCount = occurrenceCount,
		occurred = occurred,
	}
end

function widget:SetConfigData(data)
	if data.occurrenceCount ~= nil then
		occurrenceCount = data.occurrenceCount
		if occurrenceCount > maxOccurrenceCount then
			Spring.Echo("Dgun Rule Reminder: shutting down.... displayed tooltip enough ("..maxOccurrenceCount.." times)")
			widgetHandler:RemoveWidget()
			return
		end
	end
	if Spring.GetGameFrame() > 0 then
		if data.occurred ~= nil then
			occurred = data.occurred
		end
	end
end
