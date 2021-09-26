-- see alldefs.lua for documentation
-- load the games _Post functions for defs, and find out if saving to custom params is wanted
VFS.Include("gamedata/alldefs_post.lua")
-- load functionality for saving to custom params
VFS.Include("gamedata/post_save_to_customparams.lua")

-- special tablemerge:
-- normally an empty table as value will be ignored when merging, but not here, it will overwrite what it had with an empty table
local function tableMergeSpecial(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if next(v) == nil then
				t1[k] = v
			else
				if type(t1[k] or false) == "table" then
					tableMergeSpecial(t1[k] or {}, t2[k] or {})
				else
					t1[k] = v
				end
			end
		else
			t1[k] = v
		end
	end
	return t1
end


-- handle unba modoption
if Spring.GetModOptions().unba then
	VFS.Include("unbaconfigs/unbacom_post.lua")
	VFS.Include("unbaconfigs/stats.lua")
	VFS.Include("unbaconfigs/buildoptions.lua")
	UnbaCom_Post("armcom")
	UnbaCom_Post("corcom")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Automatically generate some big selection volumes.
--

local function Explode(div, str)
	if div == '' then
		return false
	end
	local pos, arr = 0, {}
	-- for each divider found
	for st, sp in function() return string.find(str, div, pos, true) end do
		table.insert(arr, string.sub(str, pos, st - 1)) -- Attach chars left of current divider
		pos = sp + 1 -- Jump past current divider
	end
	table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
	return arr
end

local function GetDimensions(scale)
	if not scale then
		return false
	end
	local dimensionsStr = Explode(" ", scale)
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
			local dim = GetDimensions(ud.selectionvolumescales)
			ud.selectionvolumescales  = math.ceil(dim[1]*scale) .. " " .. math.ceil(dim[2]*scale) .. " " .. math.ceil(dim[3]*scale)
		else
			local size = math.max(ud.footprintx or 0, ud.footprintz or 0)*15
			if size > 0 then
				local dimensions, largest = GetDimensions(ud.collisionvolumescales)
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

	--Spring.Echo("VISUALIZE_SELECTION_VOLUME", ud.name, ud.collisionvolumescales, ud.selectionvolumescales)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- create scavenger units
VFS.Include("gamedata/scavengers/unitdef_changes.lua")
local scavengerUnitDefs = {}

for name, uDef in pairs(UnitDefs) do
	--local faction = string.sub(name, 1, 3)
	if not string.find(name, '_scav') and not string.find(name, 'critter')  and not string.find(name, 'chicken') then
		if customDefs[name] ~= nil then
			scavengerUnitDefs[name .. '_scav'] = tableMergeSpecial(table.copy(uDef), table.copy(customDefs[name]))
		else
			scavengerUnitDefs[name .. '_scav'] = table.copy(uDef)
		end
	end
end
for name, ud in pairs(scavengerUnitDefs) do
	UnitDefs[name] = ud
end


-- handle unitdefs and the weapons they contain
for name, ud in pairs(UnitDefs) do
	UnitDef_Post(name, ud)
	if ud.weapondefs then
		for wname, wd in pairs(ud.weapondefs) do
			WeaponDef_Post(wname, wd)
		end
	end

	--ud.acceleration = 0.75
	--ud.turnrate = 800

	if SaveDefsToCustomParams then
		SaveDefToCustomParams("UnitDefs", name, ud)
	end
end


