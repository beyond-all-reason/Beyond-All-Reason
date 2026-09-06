-- see alldefs.lua for documentation
local system = VFS.Include("gamedata/system.lua")
local savedefs = VFS.Include("gamedata/post_save_to_customparams.lua")

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Defs = VFS.Include("modules/defs/api.lua") ---@type DefsApi
local saveDefToCustomParams = savedefs.SaveDefToCustomParams

local scavengersEnabled = false
if Spring.GetTeamList then
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if luaAI and luaAI:find("Scavengers") then
			scavengersEnabled = true
		end
	end
end

local modOptions = Spring.GetModOptions()
if
	modOptions.ruins == "enabled"
	or modOptions.forceallunits == true
	or modOptions.zombies ~= "disabled"
	or (GG and GG.Zombies and GG.Zombies.IdleMode == true)
then
	scavengersEnabled = true
end

local regularUnitDefs = {}
local scavengerUnitDefs = {}

local function normalizeUnitDef(unitDef)
	system.lowerkeys(unitDef)
	table.ensureTable(unitDef, "customparams")
	table.ensureTable(unitDef, "buildoptions")
	table.ensureTable(unitDef, "weapondefs")
	table.ensureTable(unitDef, "weapons")
end

for name, unitDef in pairs(UnitDefs) do
	regularUnitDefs[name] = unitDef
	normalizeUnitDef(unitDef)
end

local function getFilePath(filename, path)
	local files = VFS.DirList(path, "*.lua")
	for i = 1, #files do
		if path .. filename == files[i] then
			return path
		end
	end
	local subdirs = VFS.SubDirs(path)
	for i = 1, #subdirs do
		local result = getFilePath(filename, subdirs[i])
		if result then
			return result
		end
	end
	return false
end

local function bakeUnitDefs()
	for name, unitDef in pairs(regularUnitDefs) do
		-- usable when baking ... keeping subfolder structure
		local filepath = getFilePath(name .. ".lua", "units/")
		if filepath then
			if
				not unitDef.customparams.subfolder
				or string.sub(filepath, 7, #filepath - 1) ~= string.lower(unitDef.customparams.subfolder)
			then
				unitDef.customparams.subfolder = string.sub(filepath, 7, #filepath - 1) -- not that this always gets to be lowercase despite whatever it is in the repo
			end
		end
		saveDefToCustomParams("UnitDefs", name, unitDef)
	end
end

-- Special variant of table.merge:
-- Since nil values are ignored when iterating with keys, here the string 'nil' gets converted to nil
-- Normally an empty table as value will be ignored when merging, but here, it will overwrite with the empty table
local function tableMergeSpecial(t1, t2)
	local newTable = table.copy(t1)

	for k, v in pairs(t2) do
		if type(v) == "table" then
			if next(v) == nil then
				newTable[k] = v
			else
				if type(newTable[k] or false) == "table" then
					newTable[k] = tableMergeSpecial(newTable[k] or {}, t2[k] or {})
				else
					newTable[k] = v
				end
			end
		else
			if v == "nil" then
				newTable[k] = nil
			else
				newTable[k] = v
			end
		end
	end

	return newTable
end

local function getDimensions(scale)
	if not scale then
		return false
	end
	local dimensionsStr = string.split(scale, " ")
	-- string conversion (required for MediaWiki export)
	local dimensions = {}
	for i, v in pairs(dimensionsStr) do
		dimensions[i] = tonumber(v)
	end
	local largest = (dimensions and dimensions[1] and tonumber(dimensions[1])) or 0
	for i = 2, 3 do
		largest = math.max(largest, (dimensions and dimensions[i] and tonumber(dimensions[i])) or 0)
	end
	return dimensions, largest
end

local function enlargeSelectionVolumes()
	local VISUALIZE_SELECTION_VOLUME = false
	local CYL_SCALE = 1.1
	local CYL_LENGTH = 0.85
	local CYL_ADD = 4
	local SEL_SCALE = 1.22
	local STATIC_SEL_SCALE = 1.15

	for name, ud in pairs(UnitDefs) do
		local scale = STATIC_SEL_SCALE
		if ud.maxacc and ud.maxacc > 0 and ud.canmove then
			scale = SEL_SCALE
		end
		if ud.customparams.selectionscalemult then
			scale = ud.customparams.selectionscalemult
		end

		if ud.collisionvolumescales or ud.selectionvolumescales then
			-- Do not override default colvol because it is hard to measure.

			if ud.selectionvolumescales then
				local dim = getDimensions(ud.selectionvolumescales)
				ud.selectionvolumescales = math.ceil(dim[1] * scale)
					.. " "
					.. math.ceil(dim[2] * scale)
					.. " "
					.. math.ceil(dim[3] * scale)
			else
				local size = math.max(ud.footprintx or 0, ud.footprintz or 0) * 15
				if size > 0 then
					local dimensions, largest = getDimensions(ud.collisionvolumescales)
					local x, y, z = size, size, size
					if size > largest then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or "0 0 0"
						ud.selectionvolumetype = ud.selectionvolumetype or "ellipsoid"
					elseif string.lower(ud.collisionvolumetype) == "cylx" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = dimensions[1] * CYL_LENGTH
						y = math.max(dimensions[2], math.min(size, CYL_ADD + dimensions[2] * CYL_SCALE))
						z = math.max(dimensions[3], math.min(size, CYL_ADD + dimensions[3] * CYL_SCALE))
						ud.selectionvolumetype = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "cyly" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = math.max(dimensions[1], math.min(size, CYL_ADD + dimensions[1] * CYL_SCALE))
						y = dimensions[2] * CYL_LENGTH
						z = math.max(dimensions[3], math.min(size, CYL_ADD + dimensions[3] * CYL_SCALE))
						ud.selectionvolumetype = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "cylz" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = math.max(dimensions[1], math.min(size, CYL_ADD + dimensions[1] * CYL_SCALE))
						y = math.max(dimensions[2], math.min(size, CYL_ADD + dimensions[2] * CYL_SCALE))
						z = dimensions[3] * CYL_LENGTH
						ud.selectionvolumetype = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "box" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or "0 0 0"
						x = dimensions[1]
						y = dimensions[2]
						z = dimensions[3]
						ud.selectionvolumetype = ud.selectionvolumetype or ud.collisionvolumetype
					end
					ud.selectionvolumescales = math.ceil(x * scale)
						.. " "
						.. math.ceil(y * scale)
						.. " "
						.. math.ceil(z * scale)
				end
			end
		else
			ud.customparams.lua_selection_scale = scale -- Scale default colVol units in lua, where we can read their model radius.
		end

		if VISUALIZE_SELECTION_VOLUME then
			if ud.selectionvolumescales then
				ud.collisionvolumeoffsets = ud.selectionvolumeoffsets
				ud.collisionvolumescales = ud.selectionvolumescales
				ud.collisionvolumetype = ud.selectionvolumetype
			end
		end
	end
end

local function preProcessUnitDefs()
	enlargeSelectionVolumes()
end

local function createScavengerUnitDefs()
	local customScavDefs = VFS.Include("gamedata/scavengers/unitdef_changes.lua")

	for name, unitDef in pairs(UnitDefs) do
		if not string.find(name, "_scav") and not string.find(name, "critter") and not string.find(name, "raptor") then
			local scavName = name .. "_scav"
			if customScavDefs[name] ~= nil then
				scavengerUnitDefs[scavName] = tableMergeSpecial(unitDef, customScavDefs[name])
			else
				scavengerUnitDefs[scavName] = table.copy(unitDef)
			end

			scavengerUnitDefs[scavName].customparams.fromunit = name
		end
	end

	for name, unitDef in pairs(scavengerUnitDefs) do
		UnitDefs[name] = unitDef
	end
end

-- A tweak that fails is only reported here, in the defs environment, which has no way to
-- reach LuaUI except through the defs it produces. Each failure is stashed on the
-- commander defs - the ones present in every game - so the game info panel can say a tweak
-- was not applied rather than listing it as a setting that took effect.
local tweakFailures = {}
local tweakErrorCarriers = { "armcom", "corcom", "legcom" }

local function recordTweakFailure(name, message)
	-- Tab between the option and its message, newline between records: a Lua error message
	-- carries neither, so the panel can split them apart again.
	tweakFailures[#tweakFailures + 1] = name .. "\t" .. (string.gsub(tostring(message), "%s+", " "))
end

local function publishTweakFailures()
	if #tweakFailures == 0 then
		return
	end

	local text = table.concat(tweakFailures, "\n")
	for _, name in ipairs(tweakErrorCarriers) do
		local unitDef = UnitDefs[name]
		if unitDef then
			unitDef.customparams = unitDef.customparams or {}
			unitDef.customparams.tweak_errors = text
		end
	end
end

-- What a tweakunits overwrote, so the game info panel can say what a value used to be
-- rather than only what it is now. This is the one case where the before is knowable
-- cheaply: the tweak is a table, so the paths it sets are the paths to read first.
--
-- It rides on the unit's own customparams because that is where per-unit data belongs and
-- because the defs are the only thing this environment can hand to LuaUI at all.
local function recordOverwritten(unitDef, tweak, path, out)
	for key, value in pairs(tweak) do
		local here = path == "" and tostring(key) or (path .. "." .. tostring(key))
		local current = unitDef and unitDef[key]
		if type(value) == "table" then
			-- A path that opens a sub-table is not a value anyone set; its leaves are.
			recordOverwritten(type(current) == "table" and current or nil, value, here, out)
		elseif type(current) ~= "table" then
			-- Empty means there was nothing there before, which the panel reads as new.
			out[#out + 1] = here .. "\t" .. (current == nil and "" or tostring(current))
		end
	end
end

local function preProcessTweakOptions()
	local modOptions = {}
	if BAR.GetModOptionsCopy then
		modOptions = BAR.GetModOptionsCopy()
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Balance Testing
	--

	local tweaks = {}
	for name, value in pairs(modOptions) do
		local tweakType = name:match("^tweak([a-z]+)%d*$")
		local index = tonumber(name:match("^tweak[a-z]+(%d*)$")) or 0
		if (tweakType == "defs" or tweakType == "units") and index then
			table.insert(tweaks, { name = name, type = tweakType, index = index, value = value })
		end
	end

	table.sort(tweaks, function(a, b)
		-- Ensure that tweakunits are processed before tweakdefs
		-- This allows fine-tuning of tweaks using extended capabilities of tweakdefs
		if a.type == "defs" and b.type == "units" then
			return false
		elseif a.type == "units" and b.type == "defs" then
			return true
		end
		return a.index < b.index
	end)

	local shouldNormalizeUnitDefs = false

	for i = 1, #tweaks do
		local tweak = tweaks[i]
		local name = tweak.name
		if tweak.type == "defs" then
			local decodeSuccess, postsFuncStr = pcall(string.base64Decode, modOptions[name])
			if decodeSuccess then
				local postfunc, err = loadstring(postsFuncStr)
				if err then
					Spring.Echo("Error parsing modoption", name, "from string", postsFuncStr, "Error: " .. err)
					recordTweakFailure(name, err)
				else
					Spring.Echo("Loading " .. name .. " modoption")
					Spring.Echo(postsFuncStr)
					if postfunc then
						local success, result = pcall(postfunc)
						if success then
							shouldNormalizeUnitDefs = true -- tweakdefs can add or denormalize units
						else
							Spring.Echo("Error executing tweakdef", name, postsFuncStr, "Error :" .. result)
							recordTweakFailure(name, result)
						end
					end
				end
			else
				Spring.Echo("Error parsing and decoding tweakdef", name, modOptions[name], "Error :" .. postsFuncStr)
				recordTweakFailure(name, postsFuncStr)
			end
		else
			local success, tweakunits = pcall(BAR.Utilities.CustomKeyToUsefulTable, modOptions[name])
			if success then
				if type(tweakunits) == "table" then
					Spring.Echo("Loading " .. name .. " modoption")
					for unitName, ud in pairs(UnitDefs) do
						if tweakunits[unitName] then
							Spring.Echo("Loading tweakunits for " .. unitName)
							local lowered = system.lowerkeys(tweakunits[unitName])
							local overwritten = {}
							recordOverwritten(ud, lowered, "", overwritten)
							table.mergeInPlace(ud, lowered, true)
							normalizeUnitDef(ud) -- tweakunits can set required tables to nil
							if #overwritten > 0 then
								-- Appended, not replaced: a later slot can set a path an earlier one
								-- already did, and the first record is the one that predates them all.
								local was = ud.customparams.tweaked_from
								ud.customparams.tweaked_from = (was and was .. "\n" or "")
									.. table.concat(overwritten, "\n")
							end
						end
					end
				end
			else
				Spring.Echo("Failed to parse modoption", name, "with value", modOptions[name])
				recordTweakFailure(name, tweakunits)
			end
		end
	end

	if shouldNormalizeUnitDefs then
		for _, unitDef in pairs(UnitDefs) do
			normalizeUnitDef(unitDef)
		end
	end
end

local function postProcessAllUnitDefs()
	local pipeline = ModuleHandler.LoadPolicies(Modules.Defs).unit_def ---@type AssembledPipeline<DefContext, DefContext>
	for name, unitDef in pairs(UnitDefs) do
		ModuleHandler.Evaluate(pipeline, { name = name, def = unitDef, modOptions = modOptions })
	end
end

local function postProcessRegularUnitDefs()
	-- nothing to do here yet :-)
end

local function postProcessScavengerUnitDefs()
	local scavPostProcessor = VFS.Include("gamedata/scavengers/unitdef_post.lua")
	for name, unitDef in pairs(scavengerUnitDefs) do
		unitDef = scavPostProcessor.ScavUnitDef_Post(name, unitDef)
	end
end

local function exportYardmaps()
	for _, unitDef in pairs(UnitDefs) do
		if unitDef.yardmap then
			unitDef.customparams.buildsquare_yardmap = unitDef.yardmap
		end
	end
end

--------------------------------------------------------------
-- UnitDef processing
--------------------------------------------------------------

Defs.PrebakeUnitDefs()
if SaveDefsToCustomParams then
	bakeUnitDefs()
end

preProcessTweakOptions()
preProcessUnitDefs()
if scavengersEnabled then
	createScavengerUnitDefs()
end
postProcessAllUnitDefs()
postProcessRegularUnitDefs()
postProcessScavengerUnitDefs()
exportYardmaps()
publishTweakFailures()
