local SplineLib = VFS.Include("common/lib_spline.lua")

---@class RegionEditorFile the editor's save: every region of every type, in elmos, with the anchors it was drawn with. A curved region keeps its control ring (kind "spline") because the outline is derived from it and cannot be recovered from the outline
local EditorFile = {}

---@class RegionEditorEntry one region as the file holds it
---@field type RegionTypeKey
---@field id string
---@field kind "polygon"|"box"|"spline"|"point"
---@field anchors { x: number, z: number, strength: number|nil }[] the control ring for a spline, the vertices otherwise
---@field tags string[]|nil
---@field [string] any the type's fields

---@param region Region an editor region: vertices, and controls plus kind "spline" when curved
---@param byKey table<string, RegionType>
---@return RegionEditorEntry|nil nil when the registry does not know the type
local function entryOf(region, byKey)
	local kind = byKey[region.type]
	if not kind then
		return nil
	end
	local anchors = region.kind == "spline" and region.controls or region.vertices or {}
	local entry = { type = region.type, id = region.id, kind = region.kind or "polygon", anchors = {} }
	for _, field in ipairs(kind.fields) do
		local value = region[field.key]
		if value ~= nil and value ~= "" then
			entry[field.key] = value
		end
	end
	if region.tags and #region.tags > 0 then
		entry.tags = {}
		for i, tag in ipairs(region.tags) do
			entry.tags[i] = tag
		end
	end
	for i, a in ipairs(anchors) do
		local anchor = { x = math.floor(a.x), z = math.floor(a.z) }
		if a.strength and a.strength > 0 then
			anchor.strength = a.strength
		end
		entry.anchors[i] = anchor
	end
	return entry
end

---@param value any
---@return string
local function literal(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

---@param regions Region[]
---@param byKey table<string, RegionType>
---@param mapName string
---@return string lua source that returns { regions = RegionEditorEntry[] }
function EditorFile.Serialize(regions, byKey, mapName)
	local lines = {
		"-- Regions",
		"-- Map: " .. mapName,
		"-- Written by the regions tool; anchors in elmos",
		"",
		"return {",
		"  regions = {",
	}
	for _, region in ipairs(regions) do
		local entry = entryOf(region, byKey)
		if entry then
			lines[#lines + 1] = "    {"
			lines[#lines + 1] = "      type = " .. literal(entry.type) .. ","
			lines[#lines + 1] = "      id = " .. literal(entry.id) .. ","
			for _, field in ipairs(byKey[entry.type].fields) do
				if entry[field.key] ~= nil then
					lines[#lines + 1] = "      " .. field.key .. " = " .. literal(entry[field.key]) .. ","
				end
			end
			if entry.tags then
				local quoted = {}
				for i, tag in ipairs(entry.tags) do
					quoted[i] = literal(tag)
				end
				lines[#lines + 1] = "      tags = { " .. table.concat(quoted, ", ") .. " },"
			end
			lines[#lines + 1] = "      kind = " .. literal(entry.kind) .. ","
			lines[#lines + 1] = "      anchors = {"
			for _, a in ipairs(entry.anchors) do
				lines[#lines + 1] = a.strength
						and string.format("        { x = %d, z = %d, strength = %.3f },", a.x, a.z, a.strength)
					or string.format("        { x = %d, z = %d },", a.x, a.z)
			end
			lines[#lines + 1] = "      },"
			lines[#lines + 1] = "    },"
		end
	end
	lines[#lines + 1] = "  },"
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

---@param controls { x: number, z: number, strength: number|nil }[]
---@return { x: number, z: number }[] the outline
function EditorFile.Tessellate(controls)
	local ring = {}
	for i, a in ipairs(controls) do
		ring[i] = { a.x, a.z, a.strength or 0 }
	end
	local out = {}
	for i, p in ipairs(SplineLib.TessellateRing(ring)) do
		out[i] = { x = p[1], z = p[2] }
	end
	return out
end

---@param data table what the file returned
---@param byKey table<string, RegionType>
---@return Region[] regions with an id each (the file's, or a new one when a hand-edited file lost it), kind, and controls when curved
---@return string|nil reason when the file is not an editor file at all
function EditorFile.Read(data, byKey)
	local entries = type(data) == "table" and data.regions
	if type(entries) ~= "table" then
		return {}, "not an editor file: expected { regions = { ... } }"
	end
	local regions = {} ---@type Region[]
	for _, entry in ipairs(entries) do
		local kind = type(entry) == "table" and byKey[entry.type]
		local anchors = kind and entry.anchors
		if kind and type(anchors) == "table" and #anchors > 0 then
			local region = { type = entry.type, id = type(entry.id) == "string" and entry.id or nil, tags = {} }
			for _, field in ipairs(kind.fields) do
				local value = entry[field.key]
				if field.kind == "integer" then
					value = tonumber(value)
				elseif value ~= nil and type(value) ~= "string" then
					value = tostring(value)
				end
				region[field.key] = value
			end
			if type(entry.tags) == "table" then
				for i, tag in ipairs(entry.tags) do
					region.tags[i] = tostring(tag)
				end
			end
			if entry.kind == "spline" then
				region.kind = "spline"
				region.controls = {}
				for i, a in ipairs(anchors) do
					region.controls[i] = { x = a.x, z = a.z, strength = a.strength }
				end
				region.vertices = EditorFile.Tessellate(region.controls)
			else
				region.kind = #anchors == 1 and "point" or entry.kind or "polygon"
				region.vertices = {}
				for i, a in ipairs(anchors) do
					region.vertices[i] = { x = a.x, z = a.z }
				end
			end
			regions[#regions + 1] = region
		end
	end
	return regions, nil
end

return EditorFile
