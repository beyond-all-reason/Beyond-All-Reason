
function gadget:GetInfo()
	return {
		name     = "Wind generators",
		desc     = "Adds extra wind energy income as defined in customparams.windgen, also implements modoption: windheightbonus",
		author   = "Floris",
		date     = "November, 2016",
		layer    = 0,
		enabled  = true -- loaded by default?
	}
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local heightBoost = false
local boostMaxFactor = 0.5
local boostMaxHeight = 500
if Spring.GetModOptions and Spring.GetModOptions().windheightbonus ~= nil and Spring.GetModOptions().windheightbonus then
	heightBoost = true
end

if gadgetHandler:IsSyncedCode() then
	-- searching for units with customparam: windgen
	local windDefs = {}
	for udefID, ud in pairs(UnitDefs) do
		if ud.customParams ~= nil and ud.customParams.windgen ~= nil then
			windDefs[udefID] = ud.customParams.windgen
		end
	end

	local windmills = {}

	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------

	local spGetWind              = Spring.GetWind
	local spGetUnitDefID         = Spring.GetUnitDefID
	local spGetUnitIsStunned     = Spring.GetUnitIsStunned
	local spAddUnitResource      = Spring.AddUnitResource
	local spGetUnitPosition      = Spring.GetUnitPosition

	-------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------



	function gadget:GameFrame(n)
		if (n % 30 == 0) then
			if (next(windmills)) then
				local _, _, _, windStrength, _, _, _ = spGetWind()
				local windEnergy = 0
				for unitID, entry in pairs(windmills) do
					windEnergy = windStrength * entry[1]
					if windEnergy > entry[2] then windEnergy = entry[2] end
					local paralyzed = spGetUnitIsStunned(unitID)
					if (not paralyzed) then
						spAddUnitResource(unitID, 'energy', windEnergy)
					end
				end
			end
		end
	end

	function addWindUnit(unitID, unitDefID)
		local boost = 0
		if heightBoost then
			local _,y,_ = spGetUnitPosition(unitID)
			boost = (y / boostMaxHeight) * boostMaxFactor
			if boost > boostMaxFactor then
				boost = boostMaxFactor
			elseif boost < 0 then
				boost = 0
			end
		end
		windmills[unitID] = {windDefs[unitDefID]+boost, (UnitDefs[unitDefID].windGenerator * windDefs[unitDefID])}
	end

	function gadget:Initialize()
		-- in case a /luarules reload has been executed
		local allUnits = Spring.GetAllUnits()
		for _, unitID in pairs(allUnits) do
			local unitDefID = spGetUnitDefID(unitID)
			if (unitDefID and windDefs[unitDefID]) then
			  addWindUnit(unitID, unitDefID)
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if (windDefs[unitDefID]) then
			addWindUnit(unitID, unitDefID)
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, unitTeam)
		if (windDefs[unitDefID]) then
			if windmills[unitID] then
				addWindUnit(unitID, unitDefID)
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if (windDefs[unitDefID]) then
			windmills[unitID] = nil
		end
	end

else  -- unsynced

	if heightBoost then
		local gameStarted = false
		if Spring.GetGameFrame() > 0 then
			gameStarted = true
		end
		local vsx,vsy = Spring.GetViewGeometry()
		local widgetScale = (1 + (vsx*vsy / 7500000))

		function gadget:ViewResize()
			vsx,vsy = Spring.GetViewGeometry()
			widgetScale = (1 + (vsx*vsy / 7500000))
		end

		function gadget:GameStart()
			gameStarted = true
		end

		function gadget:DrawScreen()
			if not gameStarted then
				gl.Color(1,1,1,1)
				gl.Text('Wind height bonus of up to '..math.floor(100/(1.5/boostMaxFactor))..'%  (when map height is '..boostMaxHeight..')', vsx/2, vsy/3.4, 17*widgetScale, 'co')
			end
		end
	end
end