local RealUnitDefs = require("spec/support/real_unit_defs")
local S3O = VFS.Include("spec/support/s3o.lua")

local HOLIDAY_MODELS_PATH = "unitbasedefs/holiday_models.lua"

---@return table<string, string?>
local function indexFiles(root)
	local index = {} ---@type table<string, string?>
	---@diagnostic disable-next-line: unresolved-require
	for _, path in ipairs(require("pl.dir").getallfiles(root)) do
		local p = path:gsub("\\", "/")
		index[p:lower()] = p
	end
	return index
end

local function stripLuaComments(text)
	text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
	return (text:gsub("%-%-[^\n]*", ""))
end

local function stripBosComments(text)
	text = text:gsub("/%*.-%*/", "")
	return (text:gsub("//[^\n]*", ""))
end

local function luaPieceNames(text)
	local names = {}
	for args in stripLuaComments(text):gmatch("%f[%w_]piece%s*(%b())") do
		for name in args:gmatch('"([^"]+)"') do
			names[#names + 1] = name
		end
	end
	return names
end

local function bosPieceNames(text)
	local names = {}
	for declaration in stripBosComments(text):gmatch("%f[%w_]piece%s+([^;]+);") do
		for name in declaration:gmatch("[%w_]+") do
			names[#names + 1] = name
		end
	end
	return names
end

-- It's always the hats
local function hatPieces(model)
	local count = 0
	while model.pieces["h" .. (count + 1)] do
		count = count + 1
	end
	return count
end

describe("holiday models", function()
	local holidayModels, unitDefs ---@type table, table
	local models, scripts, textures ---@type table<string, string?>, table<string, string?>, table<string, string?>

	local entries = {}

	setup(function()
		holidayModels = VFS.Include(HOLIDAY_MODELS_PATH)
		unitDefs = RealUnitDefs.byName()
		models = indexFiles("objects3d")
		scripts = indexFiles("scripts")
		textures = indexFiles("unittextures")

		for event, byUnit in pairs(holidayModels) do
			for unitName, entry in pairs(byUnit) do
				entries[#entries + 1] = { event = event, unitName = unitName, entry = entry }
			end
		end
		table.sort(entries, function(a, b)
			return a.event .. a.unitName < b.event .. b.unitName
		end)
	end)

	local function eventModel(item)
		return models[("objects3d/" .. item.entry.model):lower()]
	end

	local function label(item)
		return item.event .. " " .. item.unitName
	end

	it("names real units", function()
		local bad = {}
		for _, item in ipairs(entries) do
			if not unitDefs[item.unitName] then
				bad[#bad + 1] = label(item)
			end
		end
		assert.same({}, bad)
	end)

	it("points at model files that exist", function()
		local bad = {}
		for _, item in ipairs(entries) do
			if not eventModel(item) then
				bad[#bad + 1] = label(item) .. ": " .. tostring(item.entry.model)
			end
		end
		assert.same({}, bad)
	end)

	it("uses textures that exist", function()
		local bad = {}
		for _, item in ipairs(entries) do
			local path = eventModel(item)
			if path then
				for _, texture in ipairs(S3O.Load(path).textures) do
					if texture ~= "" and not textures[("unittextures/" .. texture):lower()] then
						bad[#bad + 1] = label(item) .. ": " .. texture
					end
				end
			end
		end
		assert.same({}, bad)
	end)

	-- unit_intergrated_hats shows one of h1..hN per unit; any it does not know about _always show_
	it("counts the baked-in hats the model has", function()
		local bad = {}
		for _, item in ipairs(entries) do
			local path = eventModel(item)
			if path then
				local model = S3O.Load(path)
				local declared = item.entry.hats or 0
				local found = hatPieces(model)
				if declared ~= found then
					bad[#bad + 1] =
						string.format("%s: hats = %s, model has h1..h%d", label(item), tostring(item.entry.hats), found)
				end
				for i = 1, found do
					if model.pieces["h" .. i].vertexCount == 0 then
						bad[#bad + 1] = string.format("%s: h%d is empty", label(item), i)
					end
				end
			end
		end
		assert.same({}, bad)
	end)

	it("has every piece the unit's script asks for", function()
		local bad = {}
		for _, item in ipairs(entries) do
			local def = unitDefs[item.unitName]
			local path = eventModel(item)
			if def and path then
				local model = S3O.Load(path)
				local scriptName = def.script or (item.unitName .. ".cob")
				local scriptPath = scripts[("scripts/" .. scriptName):lower()]

				local names, caseless
				if scriptName:lower():match("%.lua$") then
					local file = assert(io.open(assert(scriptPath, "no script " .. scriptName), "r"))
					names = luaPieceNames(file:read("*a"))
					file:close()
				else
					local bosPath = scripts[("scripts/" .. scriptName):lower():gsub("%.cob$", ".bos")]
					local file = assert(io.open(assert(bosPath, "no source for " .. scriptName), "r"))
					names, caseless = bosPieceNames(file:read("*a")), true
					file:close()
				end

				local have = {}
				for name in pairs(model.pieces) do
					have[caseless and name:lower() or name] = true
				end
				for _, name in ipairs(names) do
					if not have[caseless and name:lower() or name] then
						bad[#bad + 1] = label(item) .. ": " .. name
					end
				end
			end
		end
		assert.same({}, bad)
	end)

	it("has each of the regular model's pieces as many times as the regular model", function()
		local bad = {}
		for _, item in ipairs(entries) do
			local def = unitDefs[item.unitName]
			local path = eventModel(item)
			local regularPath = def and def.objectname and models[("objects3d/" .. def.objectname):lower()]
			if path and regularPath then
				local counts = {}
				for _, name in ipairs(S3O.Load(path).order) do
					counts[name] = (counts[name] or 0) + 1
				end
				local regularCounts = {}
				for _, name in ipairs(S3O.Load(regularPath).order) do
					regularCounts[name] = (regularCounts[name] or 0) + 1
				end
				for name, count in pairs(regularCounts) do
					if (counts[name] or 0) ~= count then
						bad[#bad + 1] = string.format(
							"%s: %s appears %d times, %d in the regular model",
							label(item),
							name,
							counts[name] or 0,
							count
						)
					end
				end
			end
		end
		table.sort(bad)
		assert.same({}, bad)
	end)
end)
