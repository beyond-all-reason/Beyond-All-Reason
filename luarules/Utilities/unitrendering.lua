-- $Id:$
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- exported functions:
-- Spring.UnitRendering.GetLODCount(unitID) -> int
-- Spring.UnitRendering.ActivateMaterial(unitID,lod) -> nil
-- Spring.UnitRendering.DeactivateMaterial(unitID,lod) -> nil
-- Spring.FeatureRendering.GetLODCount(featureID) -> int
-- Spring.FeatureRendering.ActivateMaterial(featureID,lod) -> nil
-- Spring.FeatureRendering.DeactivateMaterial(featureID,lod) -> nil
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (SendToUnsynced) then
	return ""
end

local unitRendering = {
	lods = {},
	curHighestLOD = 0,
	activeMats = {},
	spSetLODCount = Spring.UnitRendering.SetLODCount,
	spSetMaterialLastLOD = Spring.UnitRendering.SetMaterialLastLOD,
}

local featureRendering = {
	lods = {},
	curHighestLOD = 0,
	activeMats = {},
	spSetLODCount = Spring.FeatureRendering.SetLODCount,
	spSetMaterialLastLOD = Spring.FeatureRendering.SetMaterialLastLOD,
}

local function SetLODCount(rendering, objectID, lod_count)
	rendering.lods[objectID] = lod_count
	rendering.spSetLODCount(objectID, lod_count)
end

local function GetLODCount(rendering, objectID)
	return rendering.lods[objectID] or 0
end

local function ActivateMaterial(rendering, objectID, lod)
	local activeMats = rendering.activeMats[objectID]
	if not activeMats then
		activeMats = {current = math.huge}

		rendering.activeMats[objectID] = activeMats
	end

	local lod_count = GetLODCount(rendering, objectID)
	if lod_count < lod then
		SetLODCount(rendering, objectID, lod)
	end

	activeMats[lod] = true

	if lod > rendering.curHighestLOD then
		rendering.curHighestLOD = lod
	end

	if lod <= activeMats.current then
		activeMats.current = lod

		rendering.spSetMaterialLastLOD(objectID, "opaque", lod)
	end
	-- Spring.Echo('We left ActivateMaterial with activeMats:',to_string(activeMats))
end


local function DeactivateMaterial(rendering, objectID, lod)

	local activeMats = rendering.activeMats[objectID]
	-- Spring.Echo('lod=',lod,'activeMats',to_string(activeMats))
	if not activeMats then
		return
	end

	activeMats[lod] = nil

	if activeMats.current == lod then
		--// detect next available material
		for i = 1, rendering.curHighestLOD do

			if activeMats[i] then
				activeMats.current = i

				rendering.spSetMaterialLastLOD(objectID, "opaque", i)
				return
			end
		end

		--// none material active



		rendering.activeMats[objectID] = nil
		rendering.spSetMaterialLastLOD(objectID, "opaque", 0)
		SetLODCount(rendering, objectID, 0)
	end
end

function Spring.UnitRendering.SetLODCount(unitID, lod_count)
	SetLODCount(unitRendering, unitID, lod_count)
end

function Spring.UnitRendering.GetLODCount(unitID)
	return GetLODCount(unitRendering, unitID)
end

function Spring.UnitRendering.ActivateMaterial(unitID, lod)
	ActivateMaterial(unitRendering, unitID, lod)
end

function Spring.UnitRendering.DeactivateMaterial(unitID, lod)
	DeactivateMaterial(unitRendering, unitID, lod)
end

function Spring.FeatureRendering.SetLODCount(featureID, lod_count)
	SetLODCount(featureRendering, featureID, lod_count)
end

function Spring.FeatureRendering.GetLODCount(featureID)
	return GetLODCount(featureRendering, featureID)
end

function Spring.FeatureRendering.ActivateMaterial(featureID, lod)
	ActivateMaterial(featureRendering, featureID, lod)
end

function Spring.FeatureRendering.DeactivateMaterial(featureID, lod)
	DeactivateMaterial(featureRendering, featureID, lod)
end

function to_string(data, indent)
	local str = ""

	if(indent == nil) then
		indent = 0
	end

	-- Check the type
	if(type(data) == "string") then
		str = str .. ("    "):rep(indent) .. data .. "\n"
	elseif(type(data) == "number") then
		str = str .. ("    "):rep(indent) .. data .. "\n"
	elseif(type(data) == "boolean") then
		if(data == true) then
			str = str .. "true"
		else
			str = str .. "false"
		end
	elseif(type(data) == "table") then
		local i, v
		for i, v in pairs(data) do
			-- Check for a table in a table
			if(type(v) == "table") then
				str = str .. ("    "):rep(indent) .. i .. ":\n"
				str = str .. to_string(v, indent + 2)
			else
				str = str .. ("    "):rep(indent) .. i .. ": " .. to_string(v, 0)
			end
		end
	elseif (data ==nil) then
		str=str..'nil'
	else
		--print_debug(1, "Error: unknown data type: %s", type(data))
		str=str.. "Error: unknown data type:" .. type(data)
		Spring.Echo('X data type')
	end

	return str
end