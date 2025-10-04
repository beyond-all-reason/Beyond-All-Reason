-- see alldefs.lua for documentation
VFS.Include("gamedata/unitdefrenames.lua")
VFS.Include("gamedata/alldefs_post.lua")
VFS.Include("gamedata/post_save_to_customparams.lua")
local system = VFS.Include("gamedata/system.lua")

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
if modOptions.ruins == "enabled" or modOptions.forceallunits == true or modOptions.zombies ~= "disabled" or modOptions.seasonal_surprise == true then
	scavengersEnabled = true
end

local regularUnitDefs = {}
local scavengerUnitDefs = {}

for name, unitDef in pairs(UnitDefs) do
	regularUnitDefs[name] = unitDef
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
			if not unitDef.customparams.subfolder or string.sub(filepath, 7, #filepath - 1) ~= string.lower(unitDef.customparams.subfolder) then
				unitDef.customparams.subfolder = string.sub(filepath, 7, #filepath - 1)		-- not that this always gets to be lowercase despite whatever it is in the repo
			end
		end
		SaveDefToCustomParams("UnitDefs", name, unitDef)
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

local function preProcessTweakOptions()
	local modOptions = {}
	if Spring.GetModOptionsCopy then
		modOptions = Spring.GetModOptionsCopy()
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- Balance Testing
	--

	local tweaks = {}
	for name, value in pairs(modOptions) do
		local tweakType = name:match("^tweak([a-z]+)%d*$")
		local index = tonumber(name:match("^tweak[a-z]+(%d*)$")) or 0
		if (tweakType == 'defs' or tweakType == 'units') and index then
			table.insert(tweaks, {name = name, type = tweakType, index = index, value = value})
		end
	end

	table.sort(tweaks, function(a, b)
		if a.type == 'defs' and b.type == 'units' then
			return true
		elseif a.type == 'units' and b.type == 'defs' then
			return false
		end
		return a.index < b.index
	end)

	for i = 1, #tweaks do
		local tweak = tweaks[i]
		local name = tweak.name
		if tweak.type == 'defs' then
			local decodeSuccess, postsFuncStr = pcall(string.base64Decode, modOptions[name])
			if decodeSuccess then
				local postfunc, err = loadstring(postsFuncStr)
				if err then
					Spring.Echo("Error parsing modoption", name, "from string", postsFuncStr, "Error: " .. err)
				else
					Spring.Echo("Loading ".. name .. " modoption")
					Spring.Echo(postsFuncStr)
					if postfunc then
						local success, result = pcall(postfunc)
						if not success then
							Spring.Echo("Error executing tweakdef", name, postsFuncStr, "Error :" .. result)
						end
					end
				end
			else
				Spring.Echo("Error parsing and decoding tweakdef", name, modOptions[name], "Error :" .. postsFuncStr)
			end
		else
			local success, tweakunits = pcall(Spring.Utilities.CustomKeyToUsefulTable, modOptions[name])
			if success then
				if type(tweakunits) == "table" then
					Spring.Echo("Loading ".. name .. " modoption")
					for unitName, ud in pairs(UnitDefs) do
						if tweakunits[unitName] then
							Spring.Echo("Loading tweakunits for " .. unitName)
							table.mergeInPlace(ud, system.lowerkeys(tweakunits[unitName]), true)
						end
					end
				end
			else
				Spring.Echo("Failed to parse modoption", name, "with value", modOptions[name])
			end
		end
	end
end

local function postProcessAllUnitDefs()
	for name, unitDef in pairs(UnitDefs) do
		UnitDef_Post(name, unitDef)
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

--------------------------------------------------------------
-- UnitDef processing
--------------------------------------------------------------

PrebakeUnitDefs()
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
