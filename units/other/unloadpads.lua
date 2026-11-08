-- Footprints the tractor beam gadget and unload preview test drop spots with; never spawned or drawn.
if Spring.GetModOptions().beta_tractorbeam == "disabled" then
	return {}
end

local PAD_FOOTPRINTS = { [1] = 2, [2] = 3, [4] = 4, [6] = 6, [8] = 8, [10] = 10, [12] = 12 }

local function padDef(footprint, amphib)
	local rows = {}
	for i = 1, footprint do
		rows[i] = string.rep("o", footprint)
	end
	return {
		buildpic = "ARMFUS.DDS",
		buildtime = 1,
		energycost = 0,
		metalcost = 0,
		health = 1,
		footprintx = footprint,
		footprintz = footprint,
		yardmap = table.concat(rows, " "),
		maxacc = 0,
		maxdec = 0,
		maxslope = 15,
		maxwaterdepth = amphib and 10000 or 12,
		floater = amphib or nil,
		objectname = "dbg_sphere.s3o",
		seismicsignature = 0,
		customparams = {
			subfolder = "other",
		},
	}
end

local defs = {}
for size, footprint in pairs(PAD_FOOTPRINTS) do
	defs["unloadsize" .. size] = padDef(footprint, false)
	defs["unloadsize" .. size .. "_amphib"] = padDef(footprint, true)
end
return defs
