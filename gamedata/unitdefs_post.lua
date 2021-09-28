-- see alldefs.lua for documentation
VFS.Include("gamedata/alldefs_post.lua")
VFS.Include("gamedata/post_save_to_customparams.lua")

local regularUnitDefs = {}
local scavengerUnitDefs = {}

for name, unitDef in pairs(UnitDefs) do
	regularUnitDefs[name] = unitDef
end

local function getFilePath(filename, path)
	local files = VFS.DirList(path, '*.lua')
	for i=1,#files do
		if path..filename == files[i] then
			return path
		end
	end
	local subdirs = VFS.SubDirs(path)
	for i=1,#subdirs do
		local result = getFilePath(filename, subdirs[i])
		if result then
			return result
		end
	end
	return false
end

-- Unbalanced (upgradeable) Commanders modoption
if Spring.GetModOptions().unba then
	VFS.Include("unbaconfigs/unbacom_post.lua")
	VFS.Include("unbaconfigs/stats.lua")
	VFS.Include("unbaconfigs/buildoptions.lua")
	UnbaCom_Post("armcom")
	UnbaCom_Post("corcom")
end

local function getDimensions(scale)
	if not scale then
		return false
	end
	local dimensionsStr = string.split(scale, " ")
	-- string conversion (required for MediaWiki export)
	local dimensions = {}
	for i,v in pairs(dimensionsStr) do
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
		if ud.acceleration and ud.acceleration > 0 and ud.canmove then
			scale = SEL_SCALE
		end
		if ud.customparams.selectionscalemult then
			scale = ud.customparams.selectionscalemult
		end

		if ud.collisionvolumescales or ud.selectionvolumescales then
			-- Do not override default colvol because it is hard to measure.

			if ud.selectionvolumescales then
				local dim = getDimensions(ud.selectionvolumescales)
				ud.selectionvolumescales  = math.ceil(dim[1]*scale) .. " " .. math.ceil(dim[2]*scale) .. " " .. math.ceil(dim[3]*scale)
			else
				local size = math.max(ud.footprintx or 0, ud.footprintz or 0)*15
				if size > 0 then
					local dimensions, largest = getDimensions(ud.collisionvolumescales)
					local x, y, z = size, size, size
					if size > largest then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or "0 0 0"
						ud.selectionvolumetype    = ud.selectionvolumetype or "ellipsoid"
					elseif string.lower(ud.collisionvolumetype) == "cylx" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = dimensions[1]*CYL_LENGTH
						y = math.max(dimensions[2], math.min(size, CYL_ADD + dimensions[2]*CYL_SCALE))
						z = math.max(dimensions[3], math.min(size, CYL_ADD + dimensions[3]*CYL_SCALE))
						ud.selectionvolumetype    = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "cyly" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = math.max(dimensions[1], math.min(size, CYL_ADD + dimensions[1]*CYL_SCALE))
						y = dimensions[2]*CYL_LENGTH
						z = math.max(dimensions[3], math.min(size, CYL_ADD + dimensions[3]*CYL_SCALE))
						ud.selectionvolumetype    = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "cylz" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or ud.collisionvolumeoffsets or "0 0 0"
						x = math.max(dimensions[1], math.min(size, CYL_ADD + dimensions[1]*CYL_SCALE))
						y = math.max(dimensions[2], math.min(size, CYL_ADD + dimensions[2]*CYL_SCALE))
						z = dimensions[3]*CYL_LENGTH
						ud.selectionvolumetype    = ud.selectionvolumetype or ud.collisionvolumetype
					elseif string.lower(ud.collisionvolumetype) == "box" then
						ud.selectionvolumeoffsets = ud.selectionvolumeoffsets or "0 0 0"
						x = dimensions[1]
						y = dimensions[2]
						z = dimensions[3]
						ud.selectionvolumetype    = ud.selectionvolumetype or ud.collisionvolumetype
					end
					ud.selectionvolumescales  = math.ceil(x*scale) .. " " .. math.ceil(y*scale) .. " " .. math.ceil(z*scale)
				end
			end
		else
			ud.customparams.lua_selection_scale = scale -- Scale default colVol units in lua, where we can read their model radius.
		end

		if VISUALIZE_SELECTION_VOLUME then
			if ud.selectionvolumescales then
				ud.collisionvolumeoffsets = ud.selectionvolumeoffsets
				ud.collisionvolumescales  = ud.selectionvolumescales
				ud.collisionvolumetype    = ud.selectionvolumetype
			end
		end

	end
end

local function preprocessUnitDefs()
	for _, unitDef in pairs(UnitDefs) do
		if not unitDef.customparams then
			unitDef.customparams = {}
		end
	end

	enlargeSelectionVolumes()
end

local function createScavengerUnitDefs()
	local customScavDefs = VFS.Include("gamedata/scavengers/unitdef_changes.lua")

	for name, unitDef in pairs(UnitDefs) do
		if not string.find(name, '_scav') and not string.find(name, 'critter')  and not string.find(name, 'chicken') then
			if customScavDefs[name] ~= nil then
				scavengerUnitDefs[name .. '_scav'] = table.merge(unitDef, customScavDefs[name])
			else
				scavengerUnitDefs[name .. '_scav'] = table.copy(unitDef)
			end
		end
	end

	for name, unitDef in pairs(scavengerUnitDefs) do
		UnitDefs[name] = unitDef
	end
end

local function postprocessAllUnitDefs()
	for name, unitDef in pairs(UnitDefs) do
		UnitDef_Post(name, unitDef)

		if unitDef.weapondefs then
			for weaponName, weaponDef in pairs(unitDef.weapondefs) do
				WeaponDef_Post(weaponName, weaponDef)
			end
		end
	end
end

local function postprocessRegularUnitDefs()
	for name, unitDef in pairs(regularUnitDefs) do
		-- usable when baking ... keeping subfolder structure
		if SaveDefsToCustomParams then
			local filepath = getFilePath(name..'.lua', 'units/')
			if filepath then
				unitDef.customparams.subfolder = string.sub(filepath, 7, #filepath-1)
			end

			SaveDefToCustomParams("UnitDefs", name, unitDef)
		end
	end
end

local function postprocessScavengerUnitDefs()
	VFS.Include("gamedata/scavengers/unitdef_post.lua")
	for name, unitDef in pairs(scavengerUnitDefs) do
		unitDef = scav_Udef_Post(name, unitDef)
	end
end

--------------------------------------------------------------
--------------------------------------------------------------

preprocessUnitDefs()
createScavengerUnitDefs()
postprocessAllUnitDefs()
postprocessRegularUnitDefs()
postprocessScavengerUnitDefs()