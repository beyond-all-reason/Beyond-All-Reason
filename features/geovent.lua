-----------------------------------------------------------------------------
--  editor_geovent / editor_geocrack
-----------------------------------------------------------------------------
-- Game-side geothermal vents so map-editor sessions (generated blank canvases
-- and map projects) can place working geo spots: engine geo smoke, needGeo
-- build placement and the geo-circles widget all key off a live feature whose
-- def carries geothermal=true, and a canvas has no map archive to supply one.
--
-- The crack visual is Moose's geocrack (shipped on Eight Horses, Esker Creek,
-- High Noon Remake, Salmiakki, Special Creek, Sunderance, Otago and others;
-- offered by the author for the editor). It draws through the engine's
-- building ground decal path, so no model is needed for the crack itself.
-- Distinct def/texture names (editor_*, unittextures/editor_geovent_crack.dds)
-- so maps that ship their own "geovent"/"geocrack"/geo.dds are never shadowed.

-- Mesh-marker variant: selectable rock body + smoke, deliberately NO crack
-- decal — this is the def for geo outputs with actual geometry (e.g. an
-- industrial vent structure on a non-flat spot). The rock model is a
-- stand-in until a dedicated vent asset lands; the flat-crack look lives in
-- editor_geocrack below.
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
		-- Reuse the map-feature strings already in language/en/features.json:
		-- these defs are editor plumbing and have no business adding new
		-- entries for translators to carry.
		i18nfrom = "geovent",
	},
}

-- Moose's pure-crack vent: modelless, the black crack decal IS the feature.
-- Kept faithful to his geocrack def (noSelect for gameplay clicks; the
-- Feature Placer picks features through GetFeaturesInCylinder, so it can
-- still be selected and moved in the editor).
local crack = {
	name = "editor_geocrack",
	description = "Geothermal Crack",
	alwaysvisible = true,
	blocking = false,
	burnable = false,
	flammable = false,
	geothermal = true,
	indestructible = true,
	noselect = true,
	reclaimable = false,
	autoreclaimable = false,
	energy = 0,
	metal = 0,
	damage = 10000,
	footprintX = 0,
	footprintZ = 0,
	height = 8,
	upright = false,
	hitdensity = 0,
	useBuildingGroundDecal = true,
	buildingGroundDecalDecaySpeed = 2.0,
	buildingGroundDecalType = "editor_geovent_crack.dds",
	buildingGroundDecalSizeX = 4,
	buildingGroundDecalSizeY = 4,
	customparams = {
		author = "Moose",
		category = "geo",
		i18nfrom = "geocrack",
		randomrotate = "true",
	},
}

return {
	editor_geovent = vent,
	editor_geocrack = crack,
}
