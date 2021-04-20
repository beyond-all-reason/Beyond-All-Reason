function gadget:GetInfo()
	return {
		name    = "Unit Scaler",
		desc    = "",
		author  = "Floris",
		date    = "March 2019",
		license = "GNU LGPL, v2.1 or later",
		layer   = 0,
		enabled = true
	}
end

if (not gadgetHandler:IsSyncedCode()) then

	local unitScalesUnaffected = true		-- exclude units defined in unitScales from additional scalings
	local unitScales = {
		--[UnitDefNames['armcom'].id] = 0.9,
		--[UnitDefNames['corcom'].id] = 0.9,
		--[UnitDefNames['armpw'].id] = 0.9,
		--[UnitDefNames['armjeth'].id] = 0.95,
		--[UnitDefNames['armrectr'].id] = 0.95,
		--[UnitDefNames['armck'].id] = 0.97,
		--[UnitDefNames['armham'].id] = 0.97,
		--[UnitDefNames['armwar'].id] = 1.02,
		--[UnitDefNames['armrock'].id] = 1.04,
		[UnitDefNames['coresupp'].id] = 0.7,
		--[UnitDefNames['corsub'].id] = 1.35,
		[UnitDefNames['corpt'].id] = 1.3,
		--[UnitDefNames['corpship'].id] = 1.2,
	}
	local scales = {
		--global = 1,
		--mobile = 1,
		--building = 1,
		--t1 = 0.95,
		--t2 = 1.1,
		--t3 = 1.4,
		--bot = 0.9,
		--vehicle = 1,
		--ship = 1,
		--air = 1,
		--hover = 1,
	}

	--local modCategoryScale = {
		--weapon = 0.5
	--}



	local spurSetUnitLuaDraw  = Spring.UnitRendering.SetUnitLuaDraw
	local spGetUnitDefID      = Spring.GetUnitDefID
	local spGetUnitTeam       = Spring.GetUnitTeam
	local glScale             = gl.Scale

	local udefScale ={}

	local function init()
		for udID, ud in pairs(UnitDefs) do
			-- only ARM and COR
			if string.sub(ud.name, 1, 3) == 'arm' or string.sub(ud.name, 1, 3) == 'cor' then
				if not unitScales[udID] or not unitScalesUnaffected then
					local scale = scales.global or 1
					if scales.building and ud.isBuilding then
						scale = scale * scales.building
					end
					if scales.mobile and not ud.isBuilding then
						scale = scale * scales.mobile
					end
					if ud.customParams and ud.customParams.techlevel then
						if scales.t3 and ud.customParams.techlevel == '3' then
							scale = scale * scales.t3
						end
						if scales.t2 and ud.customParams.techlevel == '2' then
							scale = scale * scales.t2
						end
					elseif scales.t1 then
						scale = scale * scales.t1
					end
					if scales.bot and ud.modCategories.bot then
						scale = scale * scales.bot
					end
					if scales.vehicle and ud.modCategories.tank then
						scale = scale * scales.vehicle
					end
					if scales.ship and ud.modCategories.ship then
						scale = scale * scales.ship
					end
					if scales.hover and ud.modCategories.hover then
						scale = scale * scales.hover
					end
					if scales.air and ud.modCategories.vtol then
						scale = scale * scales.air
					end
					if modCategoryScale then
						for cat1, cat in pairs(ud.modCategories) do
							if modCategoryScale[cat1] then
								scale = scale * modCategoryScale[cat1]
							end
						end
					end
					if scale ~= 1 then
						udefScale[udID] = scale * (unitScales[udID] and unitScales[udID] or 1)
					end
				else
					udefScale[udID] = unitScales[udID]
				end
			end
		end
	end
	init()


	local separator = ';'
	local function import()

	end


	local function export()

	end


	function gadget:UnitCreated(unitID, unitDefID, team)
		if udefScale[unitDefID] then
			spurSetUnitLuaDraw(unitID, true)
		end
	end

	function gadget:Initialize()

		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local udID = spGetUnitDefID(unitID)
			local team = spGetUnitTeam(unitID)
			if not udefScale[udID] then
				udefScale[udID] = 1
			end
			gadget:UnitCreated(unitID, udID, team)
		end
	end

	function gadget:DrawUnit(unitID, drawMode)
		local udefID = Spring.GetUnitDefID(unitID)
		if udefScale[udefID] then
			glScale( udefScale[udefID],  udefScale[udefID],  udefScale[udefID] )
			return false
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction('scale', scalercmd, "")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction('scale')
	end

	function scalercmd(_,line, words, playerID)
		if not Spring.IsCheatingEnabled() or playerID ~= Spring.GetMyPlayerID() then return end

	end

end
