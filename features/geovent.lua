-----------------------------------------------------------------------------
--  editor_geovent
-----------------------------------------------------------------------------
-- Game-side geothermal vent so map-editor sessions (generated blank canvases
-- and map projects) can place working geo spots: engine geo smoke, needGeo
-- build placement and the geo-circles widget all key off a live feature whose
-- def carries geothermal=true, and a canvas has no map archive to supply one.
-- Real maps keep shipping their own "geovent" def; this one uses a distinct
-- name so it never shadows them.
--
-- The small rock is a stand-in model until a dedicated vent asset lands; the
-- engine's native geothermal smoke column is what actually marks the spot.

local vent = {
	name = "editor_geovent",
	description = "Geothermal Vent",
	object = "rocks30/rocks30_def_01.s3o",
	blocking = false,
	burnable = false,
	flammable = false,
	geothermal = true,
	indestructible = true,
	reclaimable = false,
	autoreclaimable = false,
	energy = 0,
	metal = 0,
	damage = 40000,
	footprintX = 4,
	footprintZ = 4,
	upright = false,
	hitdensity = 0,
	customparams = {
		category = "geo",
		-- Scorched patch under the vent via the feature ground-plate system
		-- (gui_ground_ao_plates_features_gl4). Only textures already in the
		-- featureaoplates atlas qualify, and the atlas has no crack art yet,
		-- so a dark AO blotch stands in: reads as a burnt vent mouth. Replace
		-- with a real crack texture once one lands in the atlas.
		decalinfo_texfile = "rocks30_def_01_aoplane.tga",
		decalinfo_sizex = "7",
		decalinfo_sizez = "7",
		decalinfo_alpha = "0.95",
	},
}

return { editor_geovent = vent }
