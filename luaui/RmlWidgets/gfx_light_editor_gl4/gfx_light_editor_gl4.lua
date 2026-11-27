if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Light Editor GL4",
		desc = "Edit the deferred GL4 lights of a unit in the game: move them with a gizmo, build presets, save into DeferredLightsGL4config.lua",
		author = "ix, PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 100,
		enabled = false,
	}
end

-- Listeners run by RmlUi have no globals: keep them as upvalues.
local WG, Spring, RmlUi, VFS, gl, GL = WG, Spring, RmlUi, VFS, gl, GL
local UnitDefs, UnitDefNames = UnitDefs, UnitDefNames

local IO = VFS.Include("luaui/Include/light_config_io.lua")
local Gizmo = VFS.Include("luaui/Include/gizmo3d_gl4.lua")
local CameraMath = VFS.Include("common/camera_math.lua")

local MODEL_NAME = "light_editor_model"
local RML_PATH = "luaui/RmlWidgets/gfx_light_editor_gl4/gfx_light_editor_gl4.rml"
local CONFIG_PATH = "luaui/configs/DeferredLightsGL4config.lua"
local PRESETS_PATH = "luaui/configs/DeferredLightsGL4Presets.lua"
local WEAPONS_PATH = "luaui/configs/DeferredLightsGL4WeaponsConfig.lua"
local FALLBACK_DIR = "LightEditor/"

local LIGHT_PARAM_SIZE = 29
local PIECE_SLOT = 25
local LIGHT_ROWS = 64
local PIECE_ROWS = 128
local PRESET_ROWS = 64
local SIZE_ROWS = 32
local COLOR_ROWS = 32
local LOOK_ROWS = 80
local function words(text)
	local list = {}
	for word in text:gmatch("%S+") do
		list[#list + 1] = word
	end
	return list
end

-- What makes two lights look the same, wherever they sit and however big they are.
local LOOK_TEXT =
	"r g b a color2r color2g color2b colortime modelfactor specular scattering lensflare lifetime sustain selfshadowing"
local LOOK_KEYS = words(LOOK_TEXT)
-- Sun colours the night view dims, and how far.
local SUN_KEYS = {
	{ "groundAmbientColor", "ambient" },
	{ "groundDiffuseColor", "diffuse" },
	{ "groundSpecularColor", "specular" },
	{ "unitAmbientColor", "ambient", "unit" },
	{ "unitDiffuseColor", "diffuse", "unit" },
	{ "unitSpecularColor", "specular", "unit" },
}
local NIGHT_FACTOR = 0.25
local UNDO_LIMIT = 80
local MARKER_PX = 8
local MARKER_GRAB_PX = 14
local RING_GRAB_PX = 9 -- how near the edge of a radius or cone circle grabs it
local MAX_THETA = 1.4
local NO_PIECE = "(unit base)"
local WEAPON_KINDS = { "muzzle", "projectile", "explosion" }
-- What a weapon light keeps: the renderer sets its position and direction on every shot.
local WEAPON_KEYS = words("radius " .. LOOK_TEXT)
-- Light table fields that are not free form extras.
local OWN_KEYS = { lightType = true, pieceName = true, pieceIndex = true, initComplete = true, _presetSource = true }

local sqrt, floor, abs, max, min = math.sqrt, math.floor, math.abs, math.max, math.min
local sin, cos, tan = math.sin, math.cos, math.tan

-- Orbit camera: glide seconds, radians a pixel, distance kept per wheel notch, limits in elmos.
local ORBIT = {
	glide = 0.12,
	rate = 0.006,
	zoom = 0.85,
	minDist = 20,
	maxDist = 4000,
	maxPitch = 1.5,
	minPan = 150,
	panPerRadius = 3,
}

-- Slider = value * scale, ranges in the RML; `field` = config key if it differs, `min` clamps typed values too.
local FIELDS = {
	{ key = "posx", scale = 10 },
	{ key = "posy", scale = 10 },
	{ key = "posz", scale = 10 },
	{ key = "radius", scale = 2 },
	{ key = "dirx", scale = 100 },
	{ key = "diry", scale = 100 },
	{ key = "dirz", scale = 100 },
	{ key = "theta", scale = 100 },
	{ key = "dist", field = "theta", scale = 10 },
	{ key = "pos2x", scale = 10 },
	{ key = "pos2y", scale = 10 },
	{ key = "pos2z", scale = 10 },
	{ key = "r", scale = 100 },
	{ key = "g", scale = 100 },
	{ key = "b", scale = 100 },
	{ key = "a", scale = 100 },
	{ key = "color2r", scale = 100 },
	{ key = "color2g", scale = 100 },
	{ key = "color2b", scale = 100 },
	{ key = "colortime", scale = 10 },
	{ key = "modelfactor", scale = 100 },
	{ key = "specular", scale = 100 },
	{ key = "scattering", scale = 100, min = 0 },
	{ key = "lensflare", scale = 100 },
	{ key = "lifetime", scale = 1 },
	{ key = "sustain", scale = 100 },
	{ key = "selfshadowing", scale = 1 },
}
---@type table<string, table>
local FIELD_BY_KEY = {}
for i = 1, #FIELDS do
	FIELDS[i].field = FIELDS[i].field or FIELDS[i].key
	FIELD_BY_KEY[FIELDS[i].key] = FIELDS[i]
end

local DEFAULTS = {
	point = { radius = 30, r = 1, g = 1, b = 1, a = 1, modelfactor = 0.5, specular = 0.5, scattering = 0.5 },
	cone = {
		radius = 120,
		dirz = 1,
		diry = -0.2,
		theta = 0.4,
		r = 1,
		g = 1,
		b = 0.9,
		a = 0.6,
		modelfactor = 0.5,
		specular = 0.5,
		scattering = 1,
	},
	beam = { radius = 20, pos2z = 40, r = 1, g = 1, b = 1, a = 1, modelfactor = 0.5, specular = 0.5, scattering = 0.5 },
}

local HINTS = {
	save = "Write the edited lights into DeferredLightsGL4config.lua. Only edited lights change in the file. Ctrl+S",
	reload = "Read the config file again. Edits that are not saved are lost.",
	undo = "Undo the last edit. Ctrl+Z",
	redo = "Redo. Ctrl+Y",
	copy = "Copy this unit's whole light block to the clipboard as config text.",
	addpoint = "Add a point light: shines all around from one spot.",
	addcone = "Add a cone light: a spotlight with a direction and an angle.",
	addbeam = "Add a beam light: a lit line between two points.",
	duplicate = "Copy the selected lights. Alt+drag on the gizmo does the same. Ctrl+D",
	delete = "Delete the selected lights. Delete key",
	lights = "Click a light to edit it. Ctrl or Shift+click adds to the selection; a slider then sets all selected lights.",
	name = "Light name, unique on this unit. Enter to rename. Names with headlight, searchlight or buildlight follow the player's light options.",
	type = "Point shines all around, cone is a spotlight, beam is a lit line between two points.",
	piece = "The model piece the light rides on. The light stays where it is when you change the piece. Point at a row to see the piece on the model. PICK: click the piece on the model instead.",
	piecepick = "PICK: click a piece of the model to put the selected lights on it. Click the same spot again for the piece behind. Esc, PICK or a click off the model ends it.",
	pivotpick = "PICK: click a piece of the model to pin the orbit to it. Click the same spot again for the piece behind. Esc, PICK or a click off the model ends it.",
	beampart = "Which part of the beam the gizmo moves: its start, its end or the whole beam.",
	preset = "Click a preset to give the selected lights its look. Position and direction never change.",
	presetname = "Name for a new preset. An existing name is replaced.",
	presetsave = "Save the look of this light as a preset under the name on the left, and link the light to it.",
	presetunlink = "Cut the link to the preset. The light keeps its values.",
	presetdelete = "Delete the preset named on the left. Refused while lights in the config use it.",
	presetsize = "ON: presets carry radius and cone angle too (S / M / L variants). OFF: presets leave the size alone.",
	looks = "Looks that several lights in the config share, most used first. Click one to give it to the selected lights, then SAVE AS PRESET to name it.",
	linksame = "Link every light in the config that looks exactly like this light's preset to that preset. All units; SAVE writes them, RELOAD takes it back.",
	size = "Named sizes from DeferredLightsGL4WeaponsConfig.lua. Click one to set the radius.",
	colorset = "Named colours from DeferredLightsGL4WeaponsConfig.lua. Click one to set red, green and blue. Team follows the team colour.",
	night = "Dim the sun to see the lights as at night. Only this view changes, nothing is saved.",
	keys = "Show the mouse and key controls of the editor.",
	pause = "Pause: give the mouse, camera and selection back to the game, to move units around. The lights keep their edits. Click play to go on with the selected unit.",
	focus = "Focus: hide the game interface (like F5). The editor stays: its windows, light markers, gizmo and labels. Click again or press F5 to bring the interface back.",
	flat = "FLAT: show this unit as plain grey clay, so lights and markers read clearly. Only this view changes.",
	canvas = "CANVAS: hide the world behind a dark grid. A ground disc under the unit stays and shows the light falling on it. Only this view changes.",
	colorpick = "Open the colour window: a colour square and hue strip, the config's colour sets, and the RGB sliders.",
	colorsquare = "Drag in the square for saturation and brightness, in the strip for the hue. Values above 1 are set with the sliders.",
	pivot = "What the orbit circles. AUTO: the selected light, else the unit. LIGHT: stay on the light selected now, whatever you pick later. PIECE: a piece of the model. A pinned pivot is followed as it moves. PICK: click a piece on the model to pin it.",
	mode = "UNIT: lights that sit on the model. WEAPON: muzzle flash, projectile and explosion lights of this unit's weapons, saved into DeferredLightsGL4WeaponsConfig.lua.",
	preview = "Show the selected weapon light now, without firing: a muzzle flash at the barrel, a projectile light flying out, an explosion on the ground ahead.",
	loop = "Repeat the preview at this pace while you change values. OFF stops it.",
	fire = "Order the unit to shoot at the ground ahead. The button turns into STOP FIRE: click it to end the shooting. Works on your own units.",
	weaponlights = "Weapon lights have no position: the game puts them on the shot. A weapon that shares its light with others gets its own once you edit it.",
	posx = "Position X in piece space. Negative is the unit's left.",
	posy = "Position Y: height above the piece origin.",
	posz = "Position Z: forward and back.",
	radius = "Reach of the light in elmos. Bigger lights cost more. The box takes values past the slider.",
	dirx = "Cone: where it points, X. Point: movement speed along X, see DISTANCE.",
	diry = "Cone: where it points, Y (-1 is straight down). Point: movement speed along Y, see DISTANCE.",
	dirz = "Cone: where it points, Z. Point: movement speed along Z, see DISTANCE.",
	theta = "Half angle of the cone in radians, small is a tight spot.",
	dist = "Movement in elmos, 0 is still. Negative loops: the light swings that far each way and SPEED X/Y/Z is loops per second on that axis (0.5 = one swing every 2 s). Positive drifts off at SPEED elmos per frame and never stops: use it with a LIFETIME.",
	pos2x = "Beam end X in piece space.",
	pos2y = "Beam end Y.",
	pos2z = "Beam end Z.",
	r = "Red. Above 1 is overbright and blooms.",
	g = "Green. Above 1 is overbright and blooms.",
	b = "Blue. Above 1 is overbright and blooms.",
	a = "Brightness. The box takes values past the slider.",
	color2r = "Fade target red. The light blends from its colour to this one and back.",
	color2g = "Fade target green.",
	color2b = "Fade target blue. Negative values push the dark half of the pulse to black.",
	colortime = "Fade time in frames, 0 is no fade. Negative follows the unit's texture pulse. The box takes values past the slider.",
	modelfactor = "How much the light shows on unit surfaces.",
	specular = "Strength of the shiny highlight.",
	scattering = "Glow in the air around the light, 0 is none.",
	lensflare = "Lens flare strength, 0 is none.",
	lifetime = "Frames the light lives, 0 is forever. Event lights use small values.",
	sustain = "Frames at full brightness before the fade out. Needs a lifetime.",
	selfshadowing = "Self shadow mode, 0 to 8.",
}

---@type table<string, any>
local S = {
	context = nil,
	model = nil,
	document = nil,
	unitID = nil,
	unitDefID = nil,
	unitName = nil,
	defLights = nil, -- the renderer's table for this unit type
	pieceMap = nil,
	work = {}, -- light name to its description
	mode = "unit", -- or "weapon": the muzzle, projectile and explosion lights of the unit's weapons
	weaponRef = {}, -- weapon mode: light name to { kind, weaponDefID, weaponName }
	weaponDirty = {}, -- edited weapon lights: name to its ref and light, what SAVE writes
	weaponBase = {}, -- weapon lights as the config holds them
	ownTables = setmetatable({}, { __mode = "k" }), -- renderer weapon lights no other weapon shares
	selected = {},
	primary = nil,
	beamPart = "both",
	dirty = {}, -- renderer table to { set, remove }: the lights SAVE writes
	baseline = {}, -- renderer table to its lights as the config holds them
	undo = {},
	redo = {},
	stepOpen = false,
	stepTime = 0,
	focusField = nil,
	nameText = "",
	presetText = "",
	sizeInPresets = false,
	sliderRange = {},
	sideShown = {},
	sideAt = {},
	diskPaths = {},
	hover = nil,
	hoverPart = nil,
	pieceHover = nil,
	pickMode = nil,
	pickHits = {},
	pickPool = {},
	pickCount = 0,
	pickIndex = 1,
	pickLast = nil,
	pieceInfo = {},
	gizmoHover = nil,
	drag = nil,
	windowDrag = nil,
	liveUnits = {},
	liveTime = -1,
	refresh = true,
	status = "",
	statusTime = 0,
	hint = "",
	lastByUnit = {},
	fold = {
		file = false,
		lights = false,
		light = false,
		piece = true,
		size = true,
		colorset = true,
		pivot = true,
		looks = true,
		preset = true,
		position = false,
		aim = false,
		beam = false,
		color = false,
		fade = true,
		surface = true,
		time = true,
	},
	panelLeft = nil,
	panelTop = nil,
	previews = {}, -- weapon light previews that this editor ends itself
	basisCache = {}, -- piece name (0 = unit base) to its basis table
	ringCache = {}, -- light name to its ring table
	focus = false, -- game interface hidden, editor left alive
	paused = false, -- the game has the mouse, camera and selection back
	flat = false, -- the unit drawn as grey clay
	canvas = false, -- the world replaced by a grid canvas and a ground disc
}

---@type table<string, function>
local F = {}

-- Shaders of the flat unit and canvas views, see F.drawBackdrop.
local BACKDROP = {
	vs = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec4 position; // xy -1..1, zw 0..1

out DataVS {
	vec4 v_position;
};

void main() {
	// the engine clips by these while it draws the world's particles
	gl_ClipDistance[0] = 1.0;
	gl_ClipDistance[1] = 1.0;
	gl_ClipDistance[2] = 1.0;
	gl_Position = vec4(position.xy, 0.0, 1.0);
	v_position = position;
}
]],
	fs = [[
#version 430 core
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

#line 30000
in DataVS {
	vec4 v_position;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform vec4 unitSphere; // the unit's middle and reach
uniform vec4 plane; // the ground disc: centre and radius
uniform vec4 look; // flat unit, canvas, brightness, ground drawn

out vec4 fragColor;

const vec3 CANVAS = vec3(0.055, 0.055, 0.078);
const vec3 GROUND = vec3(0.17, 0.175, 0.2);
const vec3 CLAY = vec3(0.6, 0.59, 0.57);
const float CELL_PX = 32.0;
const float CELL_ELMO = 16.0;

vec3 worldAt(vec2 uv, float depth) {
	vec4 p = cameraViewProjInv * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return p.xyz / p.w;
}

// 1.0 while the map is not drawn: its depth texture then holds an old frame
float groundDepth(vec2 uv) {
	return look.w > 0.5 ? textureLod(mapDepths, uv, 0.0).x : 1.0;
}

bool unitAt(vec2 uv) {
	float model = textureLod(modelDepths, uv, 0.0).x;
	if (model >= groundDepth(uv)) {
		return false;
	}
	return distance(worldAt(uv, model), unitSphere.xyz) < unitSphere.w;
}

// 1 on the lines of a grid, fading out where the cells get too small to read
float gridLine(float coord, float cell) {
	float d = abs(fract(coord / cell - 0.5) - 0.5) * cell;
	float w = fwidth(coord);
	return (1.0 - smoothstep(0.0, w * 1.2, d)) * (1.0 - smoothstep(0.15, 0.5, w / cell));
}

// The step from a model pixel to its neighbour along `side`, taken on the side nearer in depth
vec3 faceStep(vec2 uv, vec2 side, vec3 here, float depth) {
	float before = textureLod(modelDepths, uv - side, 0.0).x;
	float after = textureLod(modelDepths, uv + side, 0.0).x;
	if (abs(before - depth) < abs(after - depth)) {
		return here - worldAt(uv - side, before);
	}
	return worldAt(uv + side, after) - here;
}

void main() {
	vec2 uv = v_position.zw;
	vec2 px = 1.0 / viewGeometry.xy;
	bool unit = unitAt(uv);
	if (unit && look.x < 0.5 && look.y > 0.5) {
		// a textured unit on the canvas: its outermost pixel is blended with the world, drop it
		unit = unitAt(uv + vec2(px.x, 0.0)) && unitAt(uv - vec2(px.x, 0.0))
			&& unitAt(uv + vec2(0.0, px.y)) && unitAt(uv - vec2(0.0, px.y));
	}
	if (unit) {
		if (look.x < 0.5) {
			discard;
		}
		// the face's own normal, from the depth: the stored one carries the texture's detail
		float depth = textureLod(modelDepths, uv, 0.0).x;
		vec3 here = worldAt(uv, depth);
		vec3 n = cross(faceStep(uv, vec2(px.x, 0.0), here, depth), faceStep(uv, vec2(0.0, px.y), here, depth));
		n = normalize(dot(n, cameraViewInv[3].xyz - here) < 0.0 ? -n : n);
		float lit = 0.5 + 0.5 * dot(n, sunDir.xyz);
		fragColor = vec4(CLAY * (0.3 + 0.7 * lit * lit) * look.z, 1.0);
		return;
	}
	if (look.y < 0.5) {
		discard;
	}

	vec2 cell = mod(floor(gl_FragCoord.xy), CELL_PX);
	vec2 major = mod(floor(gl_FragCoord.xy), CELL_PX * 4.0);
	float line = (cell.x < 1.0 || cell.y < 1.0) ? 0.063 : 0.0;
	line = (major.x < 1.0 || major.y < 1.0) ? 0.118 : line;
	vec3 color = CANVAS + line;

	float mapDepth = groundDepth(uv);
	if (mapDepth < 1.0) {
		vec3 ground = worldAt(uv, mapDepth);
		float inside = 1.0 - smoothstep(0.8, 1.0, distance(ground.xz, plane.xz) / plane.w);
		vec3 disc = GROUND * look.z;
		float minor = max(gridLine(ground.x, CELL_ELMO), gridLine(ground.z, CELL_ELMO));
		float wide = max(gridLine(ground.x, CELL_ELMO * 4.0), gridLine(ground.z, CELL_ELMO * 4.0));
		disc += max(minor * 0.04, wide * 0.08);
		color = mix(color, disc, inside);
	}
	fragColor = vec4(color, 1.0);
}
]],
}

----------------------------------------------------------------
-- Renderer access
----------------------------------------------------------------

function F.api()
	local api = WG.lightsgl4
	if api and api.GetUnitDefLights and api.GetUnitLightVBOMap and api.GetUnitDefLights() then
		return api
	end
	return nil
end

-- A renderer getter's result, or the fallback while there is none.
function F.apiGet(name, fallback)
	local api = F.api()
	return api and api[name] and api[name]() or fallback
end

function F.presets()
	return F.apiGet("GetLightPresets", {})
end

function F.sizes()
	return F.apiGet("GetLightSizes", {})
end

function F.colorSets()
	return F.apiGet("GetLightColorSets", {})
end

-- Dims the sun for the night view and puts the day's values back.
function F.setNight(on)
	if on == S.night then
		return
	end
	if on then
		S.daySun = {}
		local night = {}
		for i = 1, #SUN_KEYS do
			local key = SUN_KEYS[i]
			local r, g, b = gl.GetSun(key[2], key[3])
			if r then
				S.daySun[key[1]] = { r, g, b }
				night[key[1]] = { r * NIGHT_FACTOR, g * NIGHT_FACTOR, b * NIGHT_FACTOR }
			end
		end
		Spring.SetSunLighting(night)
	elseif S.daySun then
		Spring.SetSunLighting(S.daySun)
		S.daySun = nil
	end
	S.night = on
	S.refresh = true
end

local T0 = Spring.GetTimer()

function F.now()
	return Spring.DiffTimers(Spring.GetTimer(), T0)
end

function F.setStatus(text)
	S.status = text or ""
	S.statusTime = F.now()
	S.refresh = true
end

-- Units on screen that draw this unit type's lights.
function F.refreshLiveUnits(force)
	local now = F.now()
	if not force and now - S.liveTime < 0.5 then
		return
	end
	S.liveTime = now
	local live = {}
	local api = F.api()
	local visible = api and api.GetVisibleUnits and api.GetVisibleUnits()
	local allLights = api and api.GetUnitDefLights()
	if visible and allLights and S.defLights then
		for unitID, unitDefID in pairs(visible) do
			if allLights[unitDefID] == S.defLights and not Spring.GetUnitIsBeingBuilt(unitID) then
				live[#live + 1] = unitID
			end
		end
	end
	if S.unitID and Spring.ValidUnitID(S.unitID) then
		local have = false
		for i = 1, #live do
			if live[i] == S.unitID then
				have = true
				break
			end
		end
		if not have then
			live[#live + 1] = S.unitID
		end
	end
	S.liveUnits = live
end

-- Finishes a light the renderer has not drawn yet.
function F.ensureInit(lt)
	if not lt.lightParamTable then
		local p = {}
		for i = 1, LIGHT_PARAM_SIZE do
			p[i] = 0
		end
		local config = lt.lightConfig or {}
		for key, slot in pairs(IO.SLOT) do
			p[slot] = config[key] or 0
		end
		local slotKeys = lt.lightType == "beam" and { "pos2x", "pos2y", "pos2z" } or { "dirx", "diry", "dirz", "theta" }
		for i = 1, #slotKeys do
			p[4 + i] = config[slotKeys[i]] or 0
		end
		p[18] = floor(p[18])
		lt.lightParamTable = p
		lt.lightConfig = nil
	end
	local pieceIndex = S.pieceMap and lt.pieceName and S.pieceMap[lt.pieceName]
	if pieceIndex then
		lt.pieceIndex = pieceIndex
		lt.lightParamTable[PIECE_SLOT] = pieceIndex
	end
	lt.initComplete = true
end

function F.weaponTables()
	return F.apiGet("GetWeaponLights", nil)
end

-- The unit's weapon lights as work lights, named "<weapon> <kind>".
function F.loadWeaponLights()
	S.work = {}
	S.weaponRef = {}
	local tables = F.weaponTables()
	local def = S.unitDefID and UnitDefs[S.unitDefID]
	if not (tables and def) then
		return
	end
	local seen = {}
	for _, weapon in ipairs(def.weapons or {}) do
		local weaponDefID = weapon.weaponDef
		local weaponDef = weaponDefID and WeaponDefs[weaponDefID]
		if weaponDef and not seen[weaponDefID] then
			seen[weaponDefID] = true
			for _, kind in ipairs(WEAPON_KINDS) do
				local lt = tables[kind] and tables[kind][weaponDefID]
				local p = type(lt) == "table" and lt.lightParamTable
				if p then
					local config = {}
					for i = 1, #WEAPON_KEYS do
						config[WEAPON_KEYS[i]] = p[IO.SLOT[WEAPON_KEYS[i]]] or 0
					end
					local name = weaponDef.name .. " " .. kind
					local edited = S.weaponDirty[name]
					S.work[name] = edited and F.copyLight(edited.light)
						or { lightType = lt.lightType or "point", config = config, extra = {} }
					S.weaponRef[name] = { kind = kind, weaponDefID = weaponDefID, weaponName = weaponDef.name }
					if not S.weaponBase[name] then
						S.weaponBase[name] = F.copyLight(S.work[name])
					end
				end
			end
		end
	end
end

-- Writes a weapon light to the renderer; an edited weapon gets its own copy of a shared table.
function F.pushWeaponLight(name)
	local ref = S.weaponRef[name]
	local light = S.work[name]
	local tables = F.weaponTables()
	local lt = ref and tables and tables[ref.kind] and tables[ref.kind][ref.weaponDefID]
	if not (light and type(lt) == "table" and lt.lightParamTable) then
		return
	end
	if not S.ownTables[lt] then
		local own = {}
		for key, value in pairs(lt) do
			own[key] = value
		end
		own.lightParamTable = {}
		for i = 1, #lt.lightParamTable do
			own.lightParamTable[i] = lt.lightParamTable[i]
		end
		tables[ref.kind][ref.weaponDefID] = own
		S.ownTables[own] = true
		lt = own
	end
	local p = lt.lightParamTable
	for i = 1, #WEAPON_KEYS do
		p[IO.SLOT[WEAPON_KEYS[i]]] = light.config[WEAPON_KEYS[i]] or 0
	end
	p[18] = floor(p[18])
end

function F.removeInstances(name, lightType)
	local api = F.api()
	if not api then
		return
	end
	local vbo = api.GetUnitLightVBOMap()[lightType]
	if not vbo then
		return
	end
	for i = 1, #S.liveUnits do
		local unitID = S.liveUnits[i]
		local id = tostring(unitID) .. name
		if vbo.instanceIDtoIndex[id] then
			api.RemoveLight(lightType, id, unitID)
		end
	end
end

-- Writes a description into the renderer's table and onto the units on screen.
function F.pushLight(name)
	if S.mode == "weapon" then
		F.pushWeaponLight(name)
		return
	end
	local api = F.api()
	local light = S.work[name]
	if not (api and light and S.defLights) then
		return
	end
	local lt = S.defLights[name]
	if type(lt) ~= "table" then
		lt = { lightParamTable = {}, initComplete = true }
		for i = 1, LIGHT_PARAM_SIZE do
			lt.lightParamTable[i] = 0
		end
		S.defLights[name] = lt
	elseif lt.lightType ~= light.lightType and lt.lightType then
		F.removeInstances(name, lt.lightType)
	end
	F.ensureInit(lt)

	local p = lt.lightParamTable
	local config = light.config
	for key, slot in pairs(IO.SLOT) do
		p[slot] = config[key] or 0
	end
	if light.lightType == "beam" then
		p[5], p[6], p[7], p[8] = config.pos2x or 0, config.pos2y or 0, config.pos2z or 0, 0
	else
		p[5], p[6], p[7], p[8] = config.dirx or 0, config.diry or 0, config.dirz or 0, config.theta or 0
	end
	p[18] = floor(p[18])

	lt.lightType = light.lightType
	lt.pieceName = light.pieceName
	lt.pieceIndex = light.pieceName and S.pieceMap and S.pieceMap[light.pieceName] or 0
	lt._presetSource = light.preset
	for key, value in pairs(lt) do
		if not OWN_KEYS[key] and type(value) ~= "table" and light.extra[key] == nil then
			lt[key] = nil
		end
	end
	for key, value in pairs(light.extra) do
		lt[key] = value
	end

	local vbo = api.GetUnitLightVBOMap()[light.lightType]
	if vbo then
		for i = 1, #S.liveUnits do
			local unitID = S.liveUnits[i]
			if Spring.ValidUnitID(unitID) then
				api.AddLight(tostring(unitID) .. name, unitID, lt.pieceIndex, vbo, p)
			end
		end
	end
end

----------------------------------------------------------------
-- Dirty state and undo
----------------------------------------------------------------

function F.isReadOnly()
	local name = S.unitName
	return name ~= nil and name:find("_scav$") ~= nil and UnitDefNames[name:gsub("_scav$", "")] ~= nil
end

function F.dirtyEntry()
	if not S.defLights or F.isReadOnly() then
		return nil
	end
	local entry = S.dirty[S.defLights]
	if not entry then
		entry = { unitName = S.unitName, unitDefID = S.unitDefID, set = {}, remove = {} }
		S.dirty[S.defLights] = entry
	end
	return entry
end

-- A light counts as edited only while it differs from what the config holds.
function F.markSet(name)
	if S.mode == "weapon" then
		local saved, light = S.weaponBase[name], S.work[name]
		if light and S.weaponRef[name] and not F.isReadOnly() and not (saved and F.sameLight(saved, light)) then
			S.weaponDirty[name] = { ref = S.weaponRef[name], light = F.copyLight(light) }
		else
			S.weaponDirty[name] = nil
		end
		return
	end
	local entry = F.dirtyEntry()
	if entry then
		local saved = S.baseline[S.defLights] and S.baseline[S.defLights][name]
		local unchanged = saved and S.work[name] and F.sameLight(saved, S.work[name])
		entry.set[name] = not unchanged or nil
		entry.remove[name] = nil
	end
end

function F.markRemoved(name)
	if S.mode == "weapon" then
		return
	end
	local entry = F.dirtyEntry()
	if entry then
		local saved = S.baseline[S.defLights] and S.baseline[S.defLights][name]
		entry.set[name] = nil
		entry.remove[name] = saved and true or nil
	end
end

function F.keepBaseline()
	if S.mode == "weapon" then
		return
	end
	if S.defLights and not S.baseline[S.defLights] then
		local saved = {}
		for name, light in pairs(S.work) do
			saved[name] = F.copyLight(light)
		end
		S.baseline[S.defLights] = saved
	end
end

-- The light as it was loaded or last saved, nil for a new one.
function F.savedLight(name)
	if S.mode == "weapon" then
		return S.weaponBase[name]
	end
	return S.baseline[S.defLights] and S.baseline[S.defLights][name]
end

function F.fieldChanged(light, saved, key)
	local now, was = light.config[key] or 0, saved.config[key] or 0
	return abs(now - was) > 1e-5 * max(1, abs(was))
end

-- Puts one field of the selected lights back to its saved value.
function F.revertField(key)
	local names = F.selectedNames()
	local reverted = 0
	for i = 1, #names do
		local light, saved = S.work[names[i]], F.savedLight(names[i])
		if light and saved and F.fieldChanged(light, saved, key) then
			F.openStep(reverted > 0)
			light.config[key] = saved.config[key]
			F.commit(names[i])
			reverted = reverted + 1
		end
	end
	F.endStep()
	if reverted > 0 then
		F.setStatus("Reverted " .. key .. (reverted > 1 and (" on " .. reverted .. " lights") or ""))
	end
end

function F.dirtyCount()
	local n = 0
	for _ in pairs(S.weaponDirty) do
		n = n + 1
	end
	for _, entry in pairs(S.dirty) do
		for _ in pairs(entry.set) do
			n = n + 1
		end
		for _ in pairs(entry.remove) do
			n = n + 1
		end
	end
	return n
end

function F.copyLight(light)
	local copy = {
		lightType = light.lightType,
		pieceName = light.pieceName,
		preset = light.preset,
		config = {},
		extra = {},
	}
	for key, value in pairs(light.config) do
		copy.config[key] = value
	end
	for key, value in pairs(light.extra) do
		copy.extra[key] = value
	end
	return copy
end

function F.snapshot()
	local snap = { lights = {}, selected = {}, primary = S.primary }
	for name, light in pairs(S.work) do
		snap.lights[name] = F.copyLight(light)
	end
	for name in pairs(S.selected) do
		snap.selected[name] = true
	end
	return snap
end

-- One undo step per gesture: the first change of a drag or a burst of key presses opens it.
function F.beginStep()
	if not S.stepOpen then
		S.undo[#S.undo + 1] = F.snapshot()
		if #S.undo > UNDO_LIMIT then
			table.remove(S.undo, 1)
		end
		S.redo = {}
		S.stepOpen = true
	end
	S.stepTime = F.now()
end

function F.endStep()
	S.stepOpen = false
end

-- Opens one step at the first real change, so a no-op keeps the redo stack.
function F.openStep(opened)
	if not opened then
		F.endStep()
		F.beginStep()
	end
	return true
end

local function sameMap(a, b, default)
	for key, value in pairs(a) do
		if (b[key] or default) ~= value then
			return false
		end
	end
	for key, value in pairs(b) do
		if (a[key] or default) ~= value then
			return false
		end
	end
	return true
end

function F.sameLight(a, b)
	return a.lightType == b.lightType
		and a.pieceName == b.pieceName
		and a.preset == b.preset
		and sameMap(a.config, b.config, 0)
		and sameMap(a.extra, b.extra, nil)
end

function F.restore(snap)
	F.refreshLiveUnits(true)
	for name, light in pairs(S.work) do
		if not snap.lights[name] then
			F.removeInstances(name, light.lightType)
			S.defLights[name] = nil
			F.markRemoved(name)
		end
	end
	local old = S.work
	S.work = {}
	for name, light in pairs(snap.lights) do
		S.work[name] = F.copyLight(light)
		if not old[name] or not F.sameLight(old[name], light) then
			F.pushLight(name)
			F.markSet(name)
		end
	end
	S.selected = {}
	for name in pairs(snap.selected) do
		if S.work[name] then
			S.selected[name] = true
		end
	end
	S.primary = S.work[snap.primary] and snap.primary or next(S.selected)
	S.refresh = true
end

-- Moves one snapshot between the undo and redo stacks; a drag in progress keeps its step.
function F.travel(from, to, label)
	if S.drag or S.ringDrag then
		return
	end
	F.endStep()
	local snap = table.remove(from)
	if not snap then
		F.setStatus("Nothing to " .. label:lower())
		return
	end
	to[#to + 1] = F.snapshot()
	F.restore(snap)
	F.setStatus(label)
end

function F.undo()
	F.travel(S.undo, S.redo, "Undo")
end

function F.redo()
	F.travel(S.redo, S.undo, "Redo")
end

----------------------------------------------------------------
-- Selection
----------------------------------------------------------------

-- Sorted names of the selected lights. The list is kept until the selection changes.
function F.selectedNames()
	local names = S.namesCache
	if names then
		local n = 0
		for name in pairs(S.selected) do
			if S.work[name] then
				n = n + 1
			end
		end
		local same = n == #names
		for i = 1, same and n or 0 do
			if not (S.selected[names[i]] and S.work[names[i]]) then
				same = false
				break
			end
		end
		if same then
			return names
		end
	end
	names = {}
	for name in pairs(S.selected) do
		if S.work[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	S.namesCache = names
	return names
end

function F.selectOnly(name)
	S.selected = {}
	if name and S.work[name] then
		S.selected[name] = true
		S.primary = name
		if S.unitName then
			S.lastByUnit[S.unitName] = name
		end
	else
		S.primary = nil
	end
	S.beamPart = "both"
	S.refresh = true
end

function F.toggleSelect(name)
	if S.selected[name] then
		S.selected[name] = nil
		if S.primary == name then
			S.primary = next(S.selected)
		end
	else
		S.selected[name] = true
		S.primary = name
	end
	S.refresh = true
end

function F.sortedLightNames()
	local names = {}
	for name in pairs(S.work) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function F.setUnit(unitID, force)
	if unitID == S.unitID and not force then
		return
	end
	F.endStep()
	if S.firing ~= unitID then
		F.stopFire()
	end
	if unitID ~= S.unitID then
		S.pivotPin = nil
		F.previewStop()
	end
	S.unitID = unitID
	S.unitDefID = unitID and Spring.GetUnitDefID(unitID) or nil
	local def = S.unitDefID and UnitDefs[S.unitDefID]
	S.unitName = def and def.name or nil
	S.pieceMap = unitID and Spring.GetUnitPieceMap(unitID) or nil
	S.basisCache, S.ringCache, S.gizmoRotate = {}, {}, nil
	S.work = {}
	S.selected = {}
	S.primary = nil
	S.undo = {}
	S.redo = {}
	S.defLights = nil
	S.hover = nil
	S.ringHover = nil
	S.ringDrag = nil
	if S.drag then
		S.drag = nil
		Gizmo.endDrag()
	end
	if S.cam then
		if unitID then
			F.camBegin()
		else
			F.camEnd(0.4)
		end
	end
	S.pieceHover, S.pickMode, S.pickCount, S.pickLast, S.pieceInfo = nil, nil, 0, nil, {}

	local api = F.api()
	if api and S.unitDefID then
		local allLights = api.GetUnitDefLights()
		if not allLights[S.unitDefID] then
			allLights[S.unitDefID] = { initComplete = true }
		end
		S.defLights = allLights[S.unitDefID]
		if S.mode == "weapon" then
			F.loadWeaponLights()
		else
			for name, lt in pairs(S.defLights) do
				if type(lt) == "table" then
					F.ensureInit(lt)
					S.work[name] = IO.describe(lt)
				end
			end
		end
	end
	F.keepBaseline()
	F.refreshLiveUnits(true)

	local remembered = S.unitName and S.lastByUnit[S.unitName]
	if remembered and S.work[remembered] then
		F.selectOnly(remembered)
	else
		F.selectOnly(F.sortedLightNames()[1])
	end
	if F.isReadOnly() then
		F.setStatus("Scavenger lights are built from the base unit: edits here are not saved")
	end
	S.refresh = true
end

----------------------------------------------------------------
-- Edits
----------------------------------------------------------------

function F.roundTo(value, scale)
	return floor(value * scale + 0.5) / scale
end

function F.uniqueName(base)
	if not S.work[base] then
		return base
	end
	local stem = base:gsub("%d+$", "")
	local i = 2
	while S.work[stem .. i] do
		i = i + 1
	end
	return stem .. i
end

function F.commit(name)
	F.pushLight(name)
	F.markSet(name)
	S.refresh = true
end

function F.addLight(lightType)
	if S.mode == "weapon" then
		return
	end
	if not S.defLights then
		F.setStatus("Select a unit first")
		return
	end
	F.endStep()
	F.beginStep()
	F.refreshLiveUnits(true)
	local source = S.primary and S.work[S.primary]
	local config = {}
	for key, value in pairs(DEFAULTS[lightType]) do
		config[key] = value
	end
	if source then
		config.posx, config.posy, config.posz = source.config.posx, source.config.posy, source.config.posz
	end
	local name = F.uniqueName(lightType .. "light")
	S.work[name] = {
		lightType = lightType,
		pieceName = source and source.pieceName or nil,
		config = config,
		extra = {},
	}
	F.commit(name)
	F.selectOnly(name)
	F.endStep()
	F.setStatus("Added " .. name)
end

function F.deleteSelected()
	if S.mode == "weapon" then
		return
	end
	local names = F.selectedNames()
	if #names == 0 then
		return
	end
	F.endStep()
	F.beginStep()
	F.refreshLiveUnits(true)
	for i = 1, #names do
		local name = names[i]
		F.removeInstances(name, S.work[name].lightType)
		S.work[name] = nil
		S.defLights[name] = nil
		F.markRemoved(name)
	end
	F.selectOnly(F.sortedLightNames()[1])
	F.endStep()
	F.setStatus("Deleted " .. (#names == 1 and names[1] or (#names .. " lights")))
end

function F.duplicateSelected()
	if S.mode == "weapon" then
		return
	end
	local names = F.selectedNames()
	if #names == 0 then
		return
	end
	F.endStep()
	F.beginStep()
	F.refreshLiveUnits(true)
	local copies = {}
	for i = 1, #names do
		local copyName = F.uniqueName(names[i] .. "_copy")
		S.work[copyName] = F.copyLight(S.work[names[i]])
		F.commit(copyName)
		copies[#copies + 1] = copyName
	end
	S.selected = {}
	for i = 1, #copies do
		S.selected[copies[i]] = true
	end
	S.primary = copies[1]
	F.endStep()
	S.refresh = true
	F.setStatus("Duplicated " .. (#names == 1 and names[1] or (#names .. " lights")))
end

function F.rename(newName)
	if S.mode == "weapon" then
		return
	end
	local oldName = S.primary
	newName = (newName or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if not oldName or newName == "" or newName == oldName then
		return
	end
	if S.work[newName] then
		F.setStatus("There is a light called " .. newName .. " already")
		S.refresh = true
		return
	end
	F.endStep()
	F.beginStep()
	F.refreshLiveUnits(true)
	local light = S.work[oldName]
	F.removeInstances(oldName, light.lightType)
	S.defLights[oldName] = nil
	S.work[oldName] = nil
	F.markRemoved(oldName)
	S.work[newName] = light
	S.selected[oldName] = nil
	S.selected[newName] = true
	S.primary = newName
	F.commit(newName)
	if S.unitName then
		S.lastByUnit[S.unitName] = newName
	end
	local pin = S.pivotPin
	if pin and pin.kind == "light" and pin.name == oldName then
		pin.name, pin.key = newName, "light:" .. newName
		if S.cam then
			S.cam.key = pin.key
		end
	end
	F.endStep()
	F.setStatus("Renamed to " .. newName)
end

function F.setField(key, value)
	local names = F.selectedNames()
	if #names == 0 then
		return
	end
	F.beginStep()
	for i = 1, #names do
		S.work[names[i]].config[key] = value
		F.commit(names[i])
	end
end

-- Unit length direction, or a default when the vector is empty.
function F.normalize(x, y, z)
	local len = sqrt(x * x + y * y + z * z)
	if len < 1e-6 then
		return 0, 0, 1
	end
	return x / len, y / len, z / len
end

function F.pickSize(sizeName)
	local radius = F.sizes()[sizeName]
	if radius then
		F.endStep()
		F.setField("radius", radius)
		F.endStep()
	end
end

-- A named colour set for the selected lights; `fade` puts it into the fade colour.
function F.pickColorSet(setName, fade)
	local set = F.colorSets()[setName]
	local names = F.selectedNames()
	if not set or #names == 0 then
		return
	end
	F.endStep()
	F.beginStep()
	for i = 1, #names do
		local config = S.work[names[i]].config
		if fade then
			config.color2r, config.color2g, config.color2b = set.r, set.g, set.b
		else
			config.r, config.g, config.b = set.r, set.g, set.b
		end
		if set.colortime and not fade then
			config.color2r, config.color2g, config.color2b = set.color2r or 0, set.color2g or 0, set.color2b or 0
			config.colortime = set.colortime
		end
		F.commit(names[i])
	end
	F.endStep()
end

-- Turns one light into another type, keeping where it points.
function F.retype(light, lightType)
	local config, defaults = light.config, DEFAULTS[lightType]
	if lightType == "beam" then
		local dx, dy, dz = F.normalize(config.dirx or 0, config.diry or 0, config.dirz or 0)
		local reach = light.lightType == "cone" and (config.radius or 40) or 40
		config.pos2x = F.roundTo((config.posx or 0) + dx * reach, 100)
		config.pos2y = F.roundTo((config.posy or 0) + dy * reach, 100)
		config.pos2z = F.roundTo((config.posz or 0) + dz * reach, 100)
		config.dirx, config.diry, config.dirz, config.theta = nil, nil, nil, nil
	elseif lightType == "cone" then
		local dx, dy, dz = defaults.dirx or 0, defaults.diry, defaults.dirz
		if light.lightType == "beam" then
			dx = (config.pos2x or 0) - (config.posx or 0)
			dy = (config.pos2y or 0) - (config.posy or 0)
			dz = (config.pos2z or 0) - (config.posz or 0)
		end
		dx, dy, dz = F.normalize(dx, dy, dz)
		config.dirx, config.diry, config.dirz = F.roundTo(dx, 1000), F.roundTo(dy, 1000), F.roundTo(dz, 1000)
		config.theta = defaults.theta
		config.pos2x, config.pos2y, config.pos2z = nil, nil, nil
	else
		config.dirx, config.diry, config.dirz, config.theta = nil, nil, nil, nil
		config.pos2x, config.pos2y, config.pos2z = nil, nil, nil
	end
	light.lightType = lightType
end

function F.setType(lightType)
	if S.mode == "weapon" then
		return
	end
	local names = F.selectedNames()
	local opened = false
	for i = 1, #names do
		local light = S.work[names[i]]
		if light.lightType ~= lightType then
			if not opened then
				F.refreshLiveUnits(true)
			end
			opened = F.openStep(opened)
			F.retype(light, lightType)
			F.commit(names[i])
		end
	end
	F.endStep()
end

----------------------------------------------------------------
-- Piece space
----------------------------------------------------------------

-- Piece space to world, cached per piece per draw frame: keep a copy, not the table.
function F.basis(unitID, pieceName)
	local key = pieceName or 0
	local frame = Spring.GetDrawFrame()
	local b = S.basisCache[key]
	if b and b.frame == frame and b.unit == unitID then
		return b.ok and b or nil
	end
	if not b then
		b = {}
		S.basisCache[key] = b
	end
	b.frame, b.unit, b.ok = frame, unitID, false
	local fx, fy, fz, rx, ry, rz, ux, uy, uz = Spring.GetUnitDirection(unitID)
	local px, py, pz = Spring.GetUnitPosition(unitID)
	if not (fx and rx and px) then
		return nil
	end
	-- the piece matrix by columns: x axis, y axis, z axis, origin
	---@type number, number, number, number, number, number, number, number, number, number, number, number
	local xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz = 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0
	local pieceIndex = pieceName and S.pieceMap and S.pieceMap[pieceName]
	if pieceIndex then
		local m1, m2, m3, _, m5, m6, m7, _, m9, m10, m11, _, m13, m14, m15, m16 =
			Spring.GetUnitPieceMatrix(unitID, pieceIndex)
		if m16 then
			xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz = m1, m2, m3, m5, m6, m7, m9, m10, m11, m13, m14, m15
		end
	end
	-- model x runs to the unit's left
	b.ox = -ox * rx + oy * ux + oz * fx + px
	b.oy = -ox * ry + oy * uy + oz * fy + py
	b.oz = -ox * rz + oy * uz + oz * fz + pz
	b.xx, b.xy, b.xz = -xx * rx + xy * ux + xz * fx, -xx * ry + xy * uy + xz * fy, -xx * rz + xy * uz + xz * fz
	b.yx, b.yy, b.yz = -yx * rx + yy * ux + yz * fx, -yx * ry + yy * uy + yz * fy, -yx * rz + yy * uz + yz * fz
	b.zx, b.zy, b.zz = -zx * rx + zy * ux + zz * fx, -zx * ry + zy * uy + zz * fy, -zx * rz + zy * uz + zz * fz
	b.ok = true
	return b
end

function F.copyBasis(b)
	if not b then
		return nil
	end
	local copy = {}
	for key, value in pairs(b) do
		copy[key] = value
	end
	return copy
end

-- The camera's right, up and forward, read once a draw frame.
function F.camVectors()
	local frame = Spring.GetDrawFrame()
	if S.camVecFrame ~= frame then
		S.camVecFrame = frame
		S.camVec = Spring.GetCameraVectors()
	end
	return S.camVec
end

function F.toWorld(b, x, y, z)
	return b.ox + x * b.xx + y * b.yx + z * b.zx,
		b.oy + x * b.xy + y * b.yy + z * b.zy,
		b.oz + x * b.xz + y * b.yz + z * b.zz
end

-- A world direction or offset in piece space.
function F.dirToLocal(b, wx, wy, wz)
	local lx = (wx * b.xx + wy * b.xy + wz * b.xz) / (b.xx * b.xx + b.xy * b.xy + b.xz * b.xz)
	local ly = (wx * b.yx + wy * b.yy + wz * b.yz) / (b.yx * b.yx + b.yy * b.yy + b.yz * b.yz)
	local lz = (wx * b.zx + wy * b.zy + wz * b.zz) / (b.zx * b.zx + b.zy * b.zy + b.zz * b.zz)
	return lx, ly, lz
end

function F.dirToWorld(b, x, y, z)
	return x * b.xx + y * b.yx + z * b.zx, x * b.xy + y * b.yy + z * b.zy, x * b.xz + y * b.yz + z * b.zz
end

function F.toLocal(b, wx, wy, wz)
	return F.dirToLocal(b, wx - b.ox, wy - b.oy, wz - b.oz)
end

-- World positions of a light: its origin, and its second point for cones and beams.
function F.lightWorld(light, b)
	b = b or (S.unitID and F.basis(S.unitID, light.pieceName))
	if not b then
		return nil
	end
	local c = light.config
	local x, y, z = F.toWorld(b, c.posx or 0, c.posy or 0, c.posz or 0)
	if light.lightType == "beam" then
		local x2, y2, z2 = F.toWorld(b, c.pos2x or 0, c.pos2y or 0, c.pos2z or 0)
		return x, y, z, x2, y2, z2
	elseif light.lightType == "cone" then
		local dx, dy, dz = F.dirToWorld(b, F.normalize(c.dirx or 0, c.diry or 0, c.dirz or 0))
		local reach = min(c.radius or 0, 60)
		return x, y, z, x + dx * reach, y + dy * reach, z + dz * reach
	end
	return x, y, z
end

function F.setPiece(pieceName)
	if S.mode == "weapon" then
		return
	end
	local names = F.selectedNames()
	if #names == 0 or not S.unitID then
		return
	end
	if pieceName == "" then
		pieceName = nil
	end
	local opened = false
	for i = 1, #names do
		local light = S.work[names[i]]
		if light.pieceName ~= pieceName then
			opened = F.openStep(opened)
			local from = F.basis(S.unitID, light.pieceName)
			local to = F.basis(S.unitID, pieceName)
			local c = light.config
			if from and to then
				local wx, wy, wz = F.toWorld(from, c.posx or 0, c.posy or 0, c.posz or 0)
				local lx, ly, lz = F.toLocal(to, wx, wy, wz)
				c.posx, c.posy, c.posz = F.roundTo(lx, 100), F.roundTo(ly, 100), F.roundTo(lz, 100)
				if light.lightType == "beam" then
					wx, wy, wz = F.toWorld(from, c.pos2x or 0, c.pos2y or 0, c.pos2z or 0)
					lx, ly, lz = F.toLocal(to, wx, wy, wz)
					c.pos2x, c.pos2y, c.pos2z = F.roundTo(lx, 100), F.roundTo(ly, 100), F.roundTo(lz, 100)
				elseif light.lightType == "cone" then
					wx, wy, wz = F.dirToWorld(from, c.dirx or 0, c.diry or 0, c.dirz or 0)
					lx, ly, lz = F.normalize(F.dirToLocal(to, wx, wy, wz))
					c.dirx, c.diry, c.dirz = F.roundTo(lx, 1000), F.roundTo(ly, 1000), F.roundTo(lz, 1000)
				end
			end
			light.pieceName = pieceName
			F.commit(names[i])
		end
	end
	F.endStep()
end

----------------------------------------------------------------
-- Presets
----------------------------------------------------------------

function F.lookKey(lightType, config)
	local parts = { lightType or "point" }
	for i = 1, #LOOK_KEYS do
		parts[#parts + 1] = IO.formatNumber(config[LOOK_KEYS[i]] or 0)
	end
	return table.concat(parts, " ")
end

-- Calls fn(unitDefID, lights, name, lt) for every unit light of the renderer, shared tables once.
function F.eachConfigLight(fn)
	local api = F.api()
	if not api then
		return
	end
	local seen = {}
	for unitDefID, lights in pairs(api.GetUnitDefLights()) do
		local def = UnitDefs[unitDefID]
		local derived = def and def.name:find("_scav$") and UnitDefNames[(def.name:gsub("_scav$", ""))]
		if def and not derived and not seen[lights] then
			seen[lights] = true
			for name, lt in pairs(lights) do
				if type(lt) == "table" then
					fn(unitDefID, lights, name, lt)
				end
			end
		end
	end
end

-- The looks several lights share, most used first.
function F.buildLooks()
	local groups, list = {}, {}
	F.eachConfigLight(function(_, _, name, lt)
		local described = IO.describe(lt)
		local key = F.lookKey(described.lightType, described.config)
		local group = groups[key]
		if not group then
			group = { count = 0, names = {}, lightType = described.lightType, config = {} }
			for i = 1, #LOOK_KEYS do
				group.config[LOOK_KEYS[i]] = described.config[LOOK_KEYS[i]] or 0
			end
			groups[key] = group
			list[#list + 1] = group
		end
		group.count = group.count + 1
		local stem = name:lower():gsub("%d+$", "")
		group.names[stem] = (group.names[stem] or 0) + 1
	end)
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	for i = #list, 1, -1 do
		local group = list[i]
		if group.count < 3 or i > LOOK_ROWS then
			list[i] = nil
		else
			local best, bestCount = "", 0
			for stem, n in pairs(group.names) do
				if n > bestCount or (n == bestCount and stem < best) then
					best, bestCount = stem, n
				end
			end
			group.name = best
		end
	end
	S.looks = list
	S.refresh = true
end

function F.pickLook(index)
	local look = S.looks and S.looks[index]
	if not look or #F.selectedNames() == 0 then
		return
	end
	F.applyLook(look.lightType, look.config, nil)
	S.presetText = look.name
	if S.model then
		S.model.presetName = look.name
	end
	F.setStatus("Look of " .. look.count .. " lights applied. SAVE AS PRESET names it")
end

-- Links every light of the config that looks like the selected light's preset to it.
-- The saved state of another unit's lights, taken before an edit reaches them.
function F.keepBaselineOf(lights)
	if S.baseline[lights] then
		return
	end
	local saved = {}
	for name, lt in pairs(lights) do
		if type(lt) == "table" then
			saved[name] = IO.describe(lt)
		end
	end
	S.baseline[lights] = saved
end

function F.linkSame()
	if S.mode == "weapon" then
		return
	end
	local light = S.primary and S.work[S.primary]
	local presetName = light and light.preset
	local def = presetName and F.presets()[presetName]
	if not def then
		F.setStatus("Link the light to a preset first")
		return
	end
	local presetConfig = def.lightConfig or {}
	local wanted = F.lookKey(def.lightType, presetConfig)
	local linked, units = 0, {}
	-- a unit the config fills from another one is written through that one
	local text = F.readFile(CONFIG_PATH) or ""
	local blocks = IO.listUnits(text) or {}
	local function ownsLights(unitDefID)
		local unitName = UnitDefs[unitDefID].name
		return blocks[unitName] ~= nil or IO.aliasSource(text, unitName) == nil
	end
	F.eachConfigLight(function(unitDefID, lights, name, lt)
		if lt._presetSource == nil then
			local described = IO.describe(lt)
			local same = F.lookKey(described.lightType, described.config) == wanted
			for key in pairs(IO.SIZE) do
				if presetConfig[key] ~= nil and presetConfig[key] ~= (described.config[key] or 0) then
					same = false
				end
			end
			if same then
				if lights ~= S.defLights and ownsLights(unitDefID) then
					F.keepBaselineOf(lights)
				end
				lt._presetSource = presetName
				linked = linked + 1
				units[unitDefID] = true
				if lights == S.defLights then
					if S.work[name] then
						S.work[name].preset = presetName
					end
					F.markSet(name)
				elseif ownsLights(unitDefID) then
					local entry = S.dirty[lights]
					if not entry then
						entry = { unitName = UnitDefs[unitDefID].name, unitDefID = unitDefID, set = {}, remove = {} }
						S.dirty[lights] = entry
					end
					entry.set[name] = true
				end
			end
		end
	end)
	local unitCount = 0
	for _ in pairs(units) do
		unitCount = unitCount + 1
	end
	S.refresh = true
	F.setStatus(
		"Linked " .. linked .. " lights on " .. unitCount .. " unit types to " .. presetName .. ". SAVE writes them"
	)
end

function F.presetChanged(light)
	local def = light.preset and F.presets()[light.preset]
	if not def then
		return false
	end
	if (def.lightType or "point") ~= light.lightType then
		return true
	end
	for key, value in pairs(def.lightConfig or {}) do
		if not IO.PLACEMENT[key] and (light.config[key] or 0) ~= value then
			return true
		end
	end
	return false
end

-- Gives the selected lights a look: its type and every key but placement.
function F.applyLook(lightType, lookConfig, presetName)
	local names = F.selectedNames()
	lightType = lightType or "point"
	F.endStep()
	F.beginStep()
	F.refreshLiveUnits(true)
	for i = 1, #names do
		local light = S.work[names[i]]
		if light.lightType ~= lightType and S.mode ~= "weapon" then
			F.retype(light, lightType)
		end
		for key, value in pairs(lookConfig) do
			if not IO.PLACEMENT[key] and (S.sizeInPresets or not IO.SIZE[key]) then
				light.config[key] = value
			end
		end
		-- fade keys the look leaves out are off in it
		if not lookConfig.colortime then
			light.config.color2r, light.config.color2g, light.config.color2b, light.config.colortime =
				nil, nil, nil, nil
		end
		light.preset = S.mode ~= "weapon" and presetName or nil
		F.commit(names[i])
	end
	F.endStep()
end

function F.applyPreset(presetName)
	local def = F.presets()[presetName]
	local names = F.selectedNames()
	if not def or #names == 0 then
		return
	end
	F.applyLook(def.lightType, def.lightConfig or {}, presetName)
	F.setStatus("Preset " .. presetName .. " on " .. (#names == 1 and names[1] or (#names .. " lights")))
end

-- Lua opens files only by a path relative to the write folder, which is where the game
-- runs from: the longest tail of the real path that opens is that path.
function F.diskPath(vfsPath)
	if S.diskPaths[vfsPath] ~= nil then
		return S.diskPaths[vfsPath] or nil
	end
	local path = VFS.GetFileAbsolutePath
		and (VFS.GetFileAbsolutePath(vfsPath) or VFS.GetFileAbsolutePath(vfsPath:lower()))
	local found = false
	if path then
		path = path:gsub("\\", "/")
		local tail = path:match("^[^/]*/(.*)$")
		while tail and not found do
			local file = io.open(tail, "rb")
			if file then
				file:close()
				found = tail
			end
			tail = tail:match("^[^/]*/(.*)$")
		end
	end
	S.diskPaths[vfsPath] = found
	return found or nil
end

function F.readFile(vfsPath)
	local path = F.diskPath(vfsPath)
	-- a game folder closed to Lua: an earlier save went to the fallback, carry on from it
	local file = io.open(path or (FALLBACK_DIR .. vfsPath:match("([^/]+)$")), "rb")
	if file then
		local text = file:read("*a")
		file:close()
		return text, path
	end
	return VFS.LoadFile(vfsPath, VFS.RAW_FIRST), path
end

local function writeAll(path, text)
	local file = io.open(path, "wb")
	if not file then
		return false
	end
	local ok = file:write(text)
	file:close()
	return ok ~= nil
end

-- Writes into the game folder, or into the write folder when the game folder is closed to Lua.
function F.writeFile(vfsPath, path, text)
	if path and writeAll(path, text) then
		return path
	end
	Spring.CreateDir(FALLBACK_DIR)
	local fallback = FALLBACK_DIR .. vfsPath:match("([^/]+)$")
	if writeAll(fallback, text) then
		return fallback, true
	end
	return nil
end

function F.writePresets()
	local _, path = F.readFile(PRESETS_PATH)
	local where, fallback = F.writeFile(PRESETS_PATH, path, IO.serializePresets(F.presets()))
	if not where then
		F.setStatus("Could not write the presets file")
		return false
	end
	if fallback then
		F.setStatus("Game folder is read only: presets written to " .. where)
	end
	return true
end

function F.savePreset()
	if S.mode == "weapon" then
		return
	end
	local light = S.primary and S.work[S.primary]
	local presetName = F.presetTextName()
	if not light then
		F.setStatus("Select a light first")
		return
	end
	if presetName == "" then
		F.setStatus("Type a preset name first")
		return
	end
	local presets = F.presets()
	local existed = presets[presetName] ~= nil
	-- the lights built on a preset take its type: replacing it with another type would turn them all
	if existed and (presets[presetName].lightType or "point") ~= light.lightType then
		F.setStatus(presetName .. " is a " .. (presets[presetName].lightType or "point") .. " preset: use another name")
		return
	end
	presets[presetName] = IO.presetFromLight(light, S.sizeInPresets)
	if not F.writePresets() then
		return
	end
	F.endStep()
	F.beginStep()
	light.preset = presetName
	F.commit(S.primary)
	F.endStep()
	if existed then
		F.setStatus("Preset " .. presetName .. " replaced. Other lights that use it follow on RELOAD")
	else
		F.setStatus("Preset " .. presetName .. " saved")
	end
end

function F.presetTextName()
	local name = (S.presetText or ""):gsub("[^%w_]", "_")
	return name
end

function F.deletePreset()
	local presetName = F.presetTextName()
	local presets = F.presets()
	if not presets[presetName] then
		F.setStatus("No preset called " .. presetName)
		return
	end
	local text = F.readFile(CONFIG_PATH) or ""
	local _, uses = text:gsub('preset%("' .. presetName:gsub("%p", "%%%0") .. '"', "")
	for _, light in pairs(S.work) do
		if light.preset == presetName then
			uses = uses + 1
		end
	end
	-- links not saved yet on other units (copies of saved lights do not count)
	for lights, entry in pairs(S.dirty) do
		if lights ~= S.defLights then
			for name in pairs(entry.set) do
				local lt = lights[name]
				if type(lt) == "table" and lt._presetSource == presetName then
					uses = uses + 1
				end
			end
		end
	end
	if uses > 0 then
		F.setStatus(uses .. " lights use " .. presetName .. ": unlink them first")
		return
	end
	presets[presetName] = nil
	if F.writePresets() then
		F.setStatus("Preset " .. presetName .. " deleted")
	end
end

function F.unlinkPreset()
	if S.mode == "weapon" then
		return
	end
	local names = F.selectedNames()
	local opened = false
	for i = 1, #names do
		if S.work[names[i]].preset then
			opened = F.openStep(opened)
			S.work[names[i]].preset = nil
			F.commit(names[i])
		end
	end
	F.endStep()
end

----------------------------------------------------------------
-- Save and reload
----------------------------------------------------------------

-- The config block an edited unit type is written to.
function F.saveTarget(entry, units, text)
	local api = F.api()
	local allLights = api.GetUnitDefLights()
	local own = entry.unitName
	if units[own] then
		return own
	end
	local shared = {}
	for unitDefID, lights in pairs(allLights) do
		if lights == allLights[entry.unitDefID] and UnitDefs[unitDefID] then
			shared[#shared + 1] = UnitDefs[unitDefID].name
		end
	end
	table.sort(shared)
	for i = 1, #shared do
		if units[shared[i]] then
			return shared[i]
		end
	end
	local source = IO.aliasSource(text, own)
	if source then
		return nil, own .. " copies " .. source .. " in the config: edit " .. source
	end
	-- not in the file, yet it holds lights nobody edited: code in the config fills it
	for name, lt in pairs(allLights[entry.unitDefID] or {}) do
		if type(lt) == "table" and not entry.set[name] then
			return nil, own .. " gets its lights from another unit in the config: edit that one"
		end
	end
	return own
end

-- Unit lights into the unit config. Returns how many, a note on what was left out, a fallback path.
function F.saveUnitLights()
	if next(S.dirty) == nil then
		return 0
	end
	local api = F.api()
	local text, path = F.readFile(CONFIG_PATH)
	if not text then
		return nil, "could not read " .. CONFIG_PATH
	end
	local units, err = IO.listUnits(text)
	if not units then
		return nil, err
	end
	local presets = F.presets()
	local allLights = api.GetUnitDefLights()
	local saved, skipped, kept = 0, {}, {}
	for defLights, entry in pairs(S.dirty) do
		local target, why = F.saveTarget(entry, units, text)
		if not target then
			skipped[#skipped + 1] = why
			kept[defLights] = entry
		else
			local set = {}
			for name in pairs(entry.set) do
				local lt = allLights[entry.unitDefID] == defLights and defLights[name]
				if type(lt) == "table" then
					set[name] = IO.describe(lt)
					saved = saved + 1
				end
			end
			for _ in pairs(entry.remove) do
				saved = saved + 1
			end
			local newText, applyErr = IO.applyEdits(text, target, { set = set, remove = entry.remove }, presets)
			if not newText then
				return nil, applyErr
			end
			text = newText
		end
	end
	local where, fallback = F.writeFile(CONFIG_PATH, path, text)
	if not where then
		return nil, "could not write the config"
	end
	local baseline = {}
	for defLights in pairs(kept) do
		baseline[defLights] = S.baseline[defLights]
	end
	S.dirty, S.baseline = kept, baseline
	S.looks = nil
	S.fold.looks = true
	F.keepBaseline()
	return saved, #skipped > 0 and table.concat(skipped, "; ") or nil, fallback and where or nil
end

-- Weapon lights into the weapon config, each as its own override statement.
function F.saveWeaponLights()
	if next(S.weaponDirty) == nil then
		return 0
	end
	local tables = F.weaponTables()
	local text, path = F.readFile(WEAPONS_PATH)
	if not (text and tables) then
		return nil, "could not read " .. WEAPONS_PATH
	end
	local classes = IO.listBaseClasses(text)
	local saved = 0
	for name, entry in pairs(S.weaponDirty) do
		local ref = entry.ref
		local lt = tables[ref.kind] and tables[ref.kind][ref.weaponDefID]
		local base =
			IO.baseClassFor(classes, type(lt) == "table" and lt.lightClassName or nil, entry.light.lightType, ref.kind)
		if not base then
			return nil, "no base class for " .. name
		end
		local newText, err = IO.applyWeaponEdit(text, ref.kind, ref.weaponName, base, entry.light)
		if not newText then
			return nil, err
		end
		text = newText
		saved = saved + 1
	end
	local where, fallback = F.writeFile(WEAPONS_PATH, path, text)
	if not where then
		return nil, "could not write the weapon config"
	end
	for name, entry in pairs(S.weaponDirty) do
		S.weaponBase[name] = entry.light
	end
	S.weaponDirty = {}
	return saved, nil, fallback and where or nil
end

function F.save()
	if not F.api() then
		return
	end
	if F.dirtyCount() == 0 then
		F.setStatus("Nothing to save")
		return
	end
	local unitCount, unitNote, unitFallback = F.saveUnitLights()
	local weaponCount, weaponNote, weaponFallback = F.saveWeaponLights()
	local saved = (unitCount or 0) + (weaponCount or 0)
	local parts = { "Saved " .. saved .. (saved == 1 and " light" or " lights") }
	if not unitCount then
		parts[#parts + 1] = "unit lights failed: " .. tostring(unitNote)
	elseif unitNote then
		parts[#parts + 1] = "not saved: " .. unitNote
	end
	if not weaponCount then
		parts[#parts + 1] = "weapon lights failed: " .. tostring(weaponNote)
	end
	if unitFallback or weaponFallback then
		parts[#parts + 1] = "game folder is read only, written to " .. (unitFallback or weaponFallback)
	end
	F.setStatus(table.concat(parts, ". "))
end

function F.reload()
	local api = F.api()
	if not (api and api.ReloadConfig) then
		F.setStatus("The light renderer cannot reload")
		return
	end
	local unitID, primary = S.unitID, S.primary
	if not api.ReloadConfig() then
		F.setStatus("The config has an error: see the log")
		return
	end
	S.dirty = {}
	S.baseline = {}
	S.weaponDirty = {}
	S.weaponBase = {}
	S.looks = nil
	S.fold.looks = true
	F.setUnit(unitID, true)
	if primary and S.work[primary] then
		F.selectOnly(primary)
	end
	F.setStatus("Config reloaded")
end

-- Where a weapon light is previewed: the weapon's muzzle, a ground spot ahead of the unit,
-- and the frames a shot takes between them.
function F.previewSpot(weaponDefID)
	local unitID = S.unitID
	local _, _, _, mx, my, mz = Spring.GetUnitPosition(unitID, true)
	local fx, _, fz = Spring.GetUnitDirection(unitID)
	local def = UnitDefs[S.unitDefID]
	for i, weapon in ipairs(def.weapons or {}) do
		if weapon.weaponDef == weaponDefID then
			local wx, wy, wz = Spring.GetUnitWeaponVectors(unitID, i)
			if wx then
				mx, my, mz = wx, wy, wz
			end
			break
		end
	end
	local weaponDef = WeaponDefs[weaponDefID]
	local reach = max(80, min(260, (weaponDef and weaponDef.range or 300) * 0.5))
	local tx, tz = mx + fx * reach, mz + fz * reach
	local speed = weaponDef and weaponDef.projectilespeed or 0
	local frames = max(8, min(45, speed > 0 and reach / speed or 20))
	return mx, my, mz, tx, Spring.GetGroundHeight(tx, tz), tz, floor(frames)
end

-- Spawns one weapon light as a shot would; endless ones fly to the spot and are removed.
function F.previewLight(name)
	local ref = S.weaponRef[name]
	local api = F.api()
	local tables = F.weaponTables()
	local lt = ref and tables and tables[ref.kind] and tables[ref.kind][ref.weaponDefID]
	local p = type(lt) == "table" and lt.lightParamTable
	if not (p and api and api.AddPointLight and S.unitID and Spring.ValidUnitID(S.unitID)) then
		return false
	end
	local mx, my, mz, tx, ty, tz, frames = F.previewSpot(ref.weaponDefID)
	local shape = lt.lightType or "point"
	local add = (shape == "beam" and api.AddBeamLight) or (shape == "cone" and api.AddConeLight) or api.AddPointLight
	S.previewCount = (S.previewCount or 0) + 1
	local id = "lightEditorPreview" .. S.previewCount
	if ref.kind == "explosion" then
		p[1], p[2], p[3] = tx, ty + (lt.yOffset or 0), tz
	else
		p[1], p[2], p[3] = mx, my, mz
	end
	if ref.kind == "projectile" then
		if shape == "beam" then
			p[5], p[6], p[7] = tx, ty + 8, tz
		else
			p[5], p[6], p[7] = (tx - mx) / frames, (ty - my) / frames, (tz - mz) / frames
		end
	end
	add(id, nil, nil, nil, p)
	local lifetime = p[IO.SLOT.lifetime] or 0
	if lifetime <= 0 then
		local start = Spring.GetGameFrame()
		local flies = ref.kind == "projectile" and shape ~= "beam"
		S.previews[#S.previews + 1] = {
			id = id,
			shape = shape,
			add = add,
			params = p,
			flies = flies,
			from = { mx, my, mz },
			to = { tx, ty + 8, tz },
			start = start,
			stop = start + (flies and frames or 30),
		}
	end
	return true
end

function F.previewSelected()
	if S.mode ~= "weapon" then
		return
	end
	local names = F.selectedNames()
	local shown = 0
	for i = 1, #names do
		if F.previewLight(names[i]) then
			shown = shown + 1
		end
	end
	if shown == 0 then
		F.setStatus("Select a weapon light to preview")
	end
end

-- The repeat pace in seconds; 0 stops it.
function F.setPreviewLoop(seconds)
	seconds = tonumber(seconds) or 0
	S.previewEvery = seconds > 0 and seconds or nil
	S.previewNext = Spring.GetGameFrame()
	S.refresh = true
end

-- Once a game frame: moves the flying previews, removes the ended ones, repeats the loop.
function F.previewStep()
	local frame = Spring.GetGameFrame()
	if frame == S.previewFrame then
		return
	end
	S.previewFrame = frame
	local api = F.api()
	local list = S.previews
	for i = #list, 1, -1 do
		local entry = list[i]
		if not api or frame >= entry.stop then
			if api and api.RemoveLight then
				api.RemoveLight(entry.shape, entry.id, nil, true)
			end
			table.remove(list, i)
		elseif entry.flies then
			local t = (frame - entry.start) / (entry.stop - entry.start)
			local p, from, to = entry.params, entry.from, entry.to
			p[1] = from[1] + (to[1] - from[1]) * t
			p[2] = from[2] + (to[2] - from[2]) * t
			p[3] = from[3] + (to[3] - from[3]) * t
			entry.add(entry.id, nil, nil, nil, p)
		end
	end
	if S.previewEvery and frame >= S.previewNext then
		S.previewNext = frame + max(1, floor(S.previewEvery * 30 + 0.5))
		F.previewSelected()
	end
end

-- Ends the loop and takes the previews that are still up away.
function F.previewStop()
	S.previewEvery = nil
	local api = F.api()
	for i = 1, #S.previews do
		if api and api.RemoveLight then
			api.RemoveLight(S.previews[i].shape, S.previews[i].id, nil, true)
		end
	end
	S.previews = {}
	S.refresh = true
end

-- Ends a test fire with a stop order.
function F.stopFire()
	local unitID = S.firing
	if not unitID then
		return
	end
	S.firing = nil
	S.refresh = true
	if Spring.ValidUnitID(unitID) then
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end
end

-- Orders the unit to shoot at the ground ahead, to see its weapon lights. Again to stop.
function F.testFire()
	if S.firing then
		F.stopFire()
		F.setStatus("Fire stopped")
		return
	end
	if not (S.unitID and Spring.ValidUnitID(S.unitID)) then
		return
	end
	local x, _, z = Spring.GetUnitPosition(S.unitID)
	local dx, _, dz = Spring.GetUnitDirection(S.unitID)
	local reach = min((UnitDefs[S.unitDefID].maxWeaponRange or 300) * 0.8, 700)
	local tx, tz = x + dx * reach, z + dz * reach
	Spring.GiveOrderToUnit(S.unitID, CMD.ATTACK, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	S.firing = S.unitID
	S.fireFrame = Spring.GetGameFrame()
	F.setStatus("Firing: STOP FIRE ends it")
end

-- The unit got another order meanwhile: the button reads TEST FIRE again.
function F.syncFire()
	local unitID = S.firing
	if not unitID or Spring.GetGameFrame() - S.fireFrame < 30 then
		return
	end
	if not Spring.ValidUnitID(unitID) or Spring.GetUnitCurrentCommand(unitID) ~= CMD.ATTACK then
		S.firing = nil
		S.refresh = true
	end
end

function F.setMode(mode)
	if mode ~= S.mode and (mode == "unit" or mode == "weapon") then
		-- the stop button and the previews live in weapon mode only
		F.stopFire()
		F.previewStop()
		S.mode = mode
		F.setUnit(S.unitID, true)
	end
end

function F.copyUnit()
	if not S.unitName then
		return
	end
	if S.mode == "weapon" then
		local classes = IO.listBaseClasses(F.readFile(WEAPONS_PATH) or "")
		local tables = F.weaponTables() or {}
		local out = {}
		for _, name in ipairs(F.sortedLightNames()) do
			local ref = S.weaponRef[name]
			local lt = tables[ref.kind] and tables[ref.kind][ref.weaponDefID]
			local base = IO.baseClassFor(classes, lt and lt.lightClassName, S.work[name].lightType, ref.kind)
			if base then
				for _, line in ipairs(IO.serializeWeaponLight(ref.kind, ref.weaponName, base, S.work[name])) do
					out[#out + 1] = line
				end
			end
		end
		Spring.SetClipboard(table.concat(out, "\n"))
		F.setStatus("Copied the weapon lights of " .. S.unitName)
		return
	end
	local lights = {}
	for name in pairs(S.work) do
		lights[name] = IO.describe(S.defLights[name])
	end
	Spring.SetClipboard(IO.serializeUnit(S.unitName, lights, F.presets()))
	F.setStatus("Copied the lights of " .. S.unitName)
end

----------------------------------------------------------------
-- Panel
----------------------------------------------------------------

function F.formatValue(value)
	value = floor(value * 1000 + 0.5) / 1000
	if value == floor(value) then
		return string.format("%d", value)
	end
	return (string.format("%.3f", value):gsub("0+$", ""))
end

function F.clampRaw(key, raw)
	local range = S.sliderRange[key]
	if range then
		return max(range[1], min(range[2], raw))
	end
	return raw
end

function F.hex(r, g, b)
	local function channel(v)
		return max(0, min(255, floor((v or 0) * 255 + 0.5)))
	end
	return string.format("#%02x%02x%02x", channel(r), channel(g), channel(b))
end

function F.padRows(rows, count, blank)
	for i = #rows + 1, count do
		rows[i] = blank
	end
	for i = #rows, count + 1, -1 do
		rows[i] = nil
	end
	return rows
end

-- Fills the data model: the live one, or the first one before it opens.
function F.refreshModel(dm)
	dm = dm or S.model
	if not dm then
		return
	end
	local names = F.sortedLightNames()
	local selectedNames = F.selectedNames()
	local light = S.primary and S.work[S.primary]
	local dirtyEntry = S.defLights and S.dirty[S.defLights]

	dm.unitName = S.unitName or "no unit selected"
	dm.lightCount = #names
	dm.countLabel = S.unitName
			and (#names .. (S.mode == "weapon" and " weapon" or "") .. (#names == 1 and " light" or " lights"))
		or "select a unit"
	dm.hasUnit = S.unitName ~= nil
	dm.hasLight = light ~= nil
	dm.noLights = S.unitName ~= nil and #names == 0
	dm.selCount = #selectedNames
	dm.multi = #selectedNames > 1
	dm.dirtyCount = F.dirtyCount()
	dm.canUndo = #S.undo > 0
	dm.canRedo = #S.redo > 0
	dm.status = S.status
	dm.hint = S.hint

	local lightRows = {}
	for i = 1, min(#names, LIGHT_ROWS) do
		local name = names[i]
		local entry = S.work[name]
		lightRows[i] = {
			name = name,
			kind = entry.lightType,
			piece = entry.pieceName or "",
			selected = S.selected[name] == true,
			edited = S.weaponDirty[name] ~= nil or (dirtyEntry ~= nil and dirtyEntry.set[name] == true),
			blank = false,
		}
	end
	dm.lights = F.padRows(
		lightRows,
		LIGHT_ROWS,
		{ name = "", letter = "", kind = "", piece = "", selected = false, edited = false, blank = true }
	)

	local pin = S.pivotPin
	local pinPiece = pin ~= nil and pin.kind == "piece"
	local pieceRows = {
		{
			name = "",
			label = NO_PIECE,
			active = light ~= nil and light.pieceName == nil,
			pivot = pinPiece and pin.name == nil,
			blank = false,
		},
	}
	if S.pieceMap then
		local pieceNames = {}
		for pieceName in pairs(S.pieceMap) do
			pieceNames[#pieceNames + 1] = pieceName
		end
		table.sort(pieceNames)
		for i = 1, min(#pieceNames, PIECE_ROWS - 1) do
			pieceRows[#pieceRows + 1] = {
				name = pieceNames[i],
				label = pieceNames[i],
				active = light ~= nil and light.pieceName == pieceNames[i],
				pivot = pinPiece and pin.name == pieceNames[i],
				blank = false,
			}
		end
	end
	dm.pieces = F.padRows(pieceRows, PIECE_ROWS, { name = "", label = "", active = false, pivot = false, blank = true })
	dm.pieceLabel = light and (light.pieceName or NO_PIECE) or ""
	dm.pickMode = S.pickMode or ""
	dm.pivotAutoOn = pin == nil and S.cam ~= nil
	dm.pinShown = pin ~= nil
	dm.pivotLight = pin ~= nil and pin.kind == "light"
	dm.pivotPiece = pinPiece
	local pivotLabel = "the selected light, else the unit"
	if pin then
		pivotLabel = pin.kind .. " " .. (pin.name or NO_PIECE)
	end
	dm.pivotLabel = pivotLabel

	local presets = F.presets()
	local presetNames = {}
	for presetName in pairs(presets) do
		presetNames[#presetNames + 1] = presetName
	end
	table.sort(presetNames)
	local presetRows = {}
	for i = 1, min(#presetNames, PRESET_ROWS) do
		local def = presets[presetNames[i]]
		presetRows[i] = {
			name = presetNames[i],
			kind = def.lightType or "point",
			swatch = F.hex(
				def.lightConfig and def.lightConfig.r,
				def.lightConfig and def.lightConfig.g,
				def.lightConfig and def.lightConfig.b
			),
			active = light ~= nil and light.preset == presetNames[i],
			blank = false,
		}
	end
	dm.presets = F.padRows(
		presetRows,
		PRESET_ROWS,
		{ name = "", letter = "", kind = "", swatch = "#000000", active = false, blank = true }
	)
	local presetLabel = "none"
	if light and light.preset then
		presetLabel = light.preset .. (F.presetChanged(light) and ", changed" or "")
	end
	dm.presetLabel = presetLabel
	dm.linked = light ~= nil and light.preset ~= nil
	local lookRows = {}
	for i, look in ipairs(S.looks or {}) do
		lookRows[i] = {
			index = i,
			name = look.name,
			count = "x" .. look.count,
			kind = look.lightType,
			swatch = F.hex(look.config.r, look.config.g, look.config.b),
			team = look.config.r < 0,
			blank = false,
		}
	end
	dm.looks = F.padRows(
		lookRows,
		LOOK_ROWS,
		{ index = 0, name = "", count = "", letter = "", kind = "", swatch = "#000000", team = false, blank = true }
	)
	dm.sizeInPresets = S.sizeInPresets

	local config = light and light.config or {}
	local sizes = F.sizes()
	local sizeNames = {}
	for sizeName in pairs(sizes) do
		sizeNames[#sizeNames + 1] = sizeName
	end
	table.sort(sizeNames, function(a, b)
		return sizes[a] < sizes[b]
	end)
	local sizeRows, sizeLabel = {}, "custom"
	for i = 1, min(#sizeNames, SIZE_ROWS) do
		local sizeName = sizeNames[i]
		local active = light ~= nil and config.radius == sizes[sizeName]
		if active then
			sizeLabel = sizeName
		end
		sizeRows[i] = { name = sizeName, value = F.formatValue(sizes[sizeName]), active = active, blank = false }
	end
	dm.sizes = F.padRows(sizeRows, SIZE_ROWS, { name = "", value = "", active = false, blank = true })
	dm.sizeLabel = sizeLabel

	local colorSets = F.colorSets()
	local colorNames = {}
	for setName in pairs(colorSets) do
		colorNames[#colorNames + 1] = setName
	end
	table.sort(colorNames)
	local colorRows, colorLabel, fadeLabel = {}, "custom", "custom"
	local onFade = S.cp ~= nil and S.cp.which == "fade"
	for i = 1, min(#colorNames, COLOR_ROWS) do
		local set = colorSets[colorNames[i]]
		local main = light ~= nil and config.r == set.r and config.g == set.g and config.b == set.b
		local fade = light ~= nil and config.color2r == set.r and config.color2g == set.g and config.color2b == set.b
		if main then
			colorLabel = colorNames[i]
		end
		if fade then
			fadeLabel = colorNames[i]
		end
		colorRows[i] = {
			name = colorNames[i],
			swatch = F.hex(set.r, set.g, set.b),
			team = set.r < 0,
			active = (onFade and fade) or (not onFade and main),
			blank = false,
		}
	end
	dm.colorSets =
		F.padRows(colorRows, COLOR_ROWS, { name = "", swatch = "#000000", team = false, active = false, blank = true })
	dm.colorLabel = colorLabel
	dm.fadeLabel = fadeLabel
	F.colourWindowModel(dm, light ~= nil)
	dm.night = S.night == true
	dm.orbit = S.cam ~= nil
	dm.keysOpen = S.keysOpen == true
	dm.focus = S.focus == true
	dm.paused = S.paused == true
	dm.flat = S.flat == true
	dm.canvas = S.canvas == true

	dm.lightType = light and light.lightType or ""
	local weaponMode = S.mode == "weapon"
	dm.weaponMode = weaponMode
	dm.firing = S.firing ~= nil
	dm.loopKey = S.previewEvery and tostring(S.previewEvery) or "0"
	dm.showLight = light ~= nil and not weaponMode
	dm.showAim = light ~= nil and not weaponMode and light.lightType ~= "beam"
	dm.showBeam = light ~= nil and not weaponMode and light.lightType == "beam"
	dm.beamPart = S.beamPart
	if S.focusField ~= "name" then
		dm.lightName = S.primary or ""
		S.nameText = S.primary or ""
	end
	local saved = light and F.savedLight(S.primary)
	for i = 1, #FIELDS do
		local field = FIELDS[i]
		local value = config[field.field] or 0
		dm["ch_" .. field.key] = saved ~= nil and F.fieldChanged(light, saved, field.field)
		dm["sl_" .. field.key] = F.clampRaw(field.key, floor(value * field.scale + 0.5))
		if S.focusField ~= field.key then
			dm["num_" .. field.key] = F.formatValue(value)
		end
	end
	dm.swatch = F.hex(config.r, config.g, config.b)
	dm.swatch2 = F.hex(config.color2r, config.color2g, config.color2b)
	for key, folded in pairs(S.fold) do
		dm["fold_" .. key] = folded
	end
end

function F.rootElement()
	return S.document and S.document:GetElementById("le-root")
end

local SIDE_IDS = { "le-keys", "le-cp" }

-- Docks the open side windows in a row right of the panel, or left of it where the screen ends.
function F.placeSide()
	if not (S.keysOpen or S.cp) then
		return
	end
	local root = F.rootElement()
	if not root then
		return
	end
	local shown = S.sideShown
	for i = #shown, 1, -1 do
		shown[i] = nil
	end
	for i = 1, #SIDE_IDS do
		local id = SIDE_IDS[i]
		local open = (id == "le-keys" and S.keysOpen) or (id == "le-cp" and S.cp ~= nil)
		local element = open and S.document:GetElementById(id)
		if element and element.offset_width > 0 then
			shown[#shown + 1] = element
		end
	end
	local vsx = Spring.GetViewGeometry()
	local gap = floor(root.offset_width / 50)
	local total = 0
	for i = 1, #shown do
		total = total + gap + shown[i].offset_width
	end
	local x = root.absolute_left + root.offset_width + gap
	if x + total - gap > vsx then
		x = root.absolute_left - total
	end
	local top = floor(root.absolute_top)
	for i = 1, #shown do
		local element = shown[i]
		local at = floor(x) * 100000 + top
		if S.sideAt[element.id] ~= at then
			S.sideAt[element.id] = at
			element.style.left = floor(x) .. "px"
			element.style.top = top .. "px"
		end
		x = x + element.offset_width + gap
	end
end

----------------------------------------------------------------
-- Colour window
----------------------------------------------------------------

-- Hue 0..360, saturation and value 0..1, from 0..1 channels.
function F.hsv(r, g, b)
	local high, low = max(r, g, b), min(r, g, b)
	local delta = high - low
	local h = 0
	if delta > 0 then
		if high == r then
			h = 60 * (((g - b) / delta) % 6)
		elseif high == g then
			h = 60 * ((b - r) / delta + 2)
		else
			h = 60 * ((r - g) / delta + 4)
		end
	end
	return h % 360, high > 0 and delta / high or 0, high
end

function F.fromHsv(h, s, v)
	h = h % 360
	local c = v * s
	local x = c * (1 - abs((h / 60) % 2 - 1))
	local m = v - c
	local r, g, b = 0, 0, 0
	if h < 60 then
		r, g = c, x
	elseif h < 120 then
		r, g = x, c
	elseif h < 180 then
		g, b = c, x
	elseif h < 240 then
		g, b = x, c
	elseif h < 300 then
		r, b = x, c
	else
		r, b = c, x
	end
	return r + m, g + m, b + m
end

function F.cpKeys()
	if S.cp and S.cp.which == "fade" then
		return "color2r", "color2g", "color2b"
	end
	return "r", "g", "b"
end

-- The square follows the light's colour, kept in 0..1; the hue stays put on greys.
function F.cpSync(config)
	local cp = S.cp
	if not cp or S.cpDrag then
		return
	end
	local kr, kg, kb = F.cpKeys()
	local function unit(v)
		return max(0, min(1, v or 0))
	end
	local r, g, b = unit(config[kr]), unit(config[kg]), unit(config[kb])
	if cp.h then
		local sr, sg, sb = F.fromHsv(cp.h, cp.s, cp.v)
		if abs(sr - r) + abs(sg - g) + abs(sb - b) < 0.02 then
			return
		end
	end
	local h, sat, v = F.hsv(r, g, b)
	cp.h = (sat > 0 and v > 0) and h or (cp.h or 0)
	cp.s, cp.v = sat, v
end

function F.cpToggle(which)
	if which == "" or (S.cp and S.cp.which == which) then
		S.cp, S.cpDrag = nil, nil
		F.endStep()
	else
		S.cp = { which = which }
	end
	S.refresh = true
end

-- A press or drag in the square or the hue strip sets the colour of the selected lights.
function F.cpDragTo(event)
	local p = event and event.parameters
	local cp = S.cp
	local element = cp and S.document:GetElementById(S.cpDrag == "hue" and "le-cp-hue" or "le-cp-sv")
	if not (p and element and element.offset_width > 0 and element.offset_height > 0) then
		return
	end
	local fx = max(0, min(1, (p.mouse_x - element.absolute_left) / element.offset_width))
	local fy = max(0, min(1, (p.mouse_y - element.absolute_top) / element.offset_height))
	if S.cpDrag == "hue" then
		cp.h = fy * 359.9
	else
		cp.s, cp.v = fx, 1 - fy
	end
	local r, g, b = F.fromHsv(cp.h or 0, cp.s or 0, cp.v or 0)
	local kr, kg, kb = F.cpKeys()
	F.setField(kr, F.roundTo(r, 100))
	F.setField(kg, F.roundTo(g, 100))
	F.setField(kb, F.roundTo(b, 100))
	S.refresh = true
end

function F.cpRelease()
	if S.cpDrag then
		S.cpDrag = nil
		F.endStep()
	end
end

function F.colourWindowModel(dm, hasLight)
	if not hasLight then
		S.cp, S.cpDrag = nil, nil
	end
	local cp = S.cp
	dm.cpOpen = cp ~= nil
	dm.cpWhich = cp and cp.which or ""
	dm.cpOnColor = cp ~= nil and cp.which == "color"
	dm.cpOnFade = cp ~= nil and cp.which == "fade"
	if not cp then
		dm.cpTitle, dm.cpHex, dm.cpHueHex = "", "#000000", "#ff0000"
		dm.cpSvX, dm.cpSvY, dm.cpHueY = "0%", "0%", "0%"
		return
	end
	local light = S.primary and S.work[S.primary]
	if light then
		F.cpSync(light.config)
	end
	local kr, kg, kb = F.cpKeys()
	local c = light and light.config or {}
	dm.cpTitle = cp.which == "fade" and "FADE COLOUR" or "COLOUR"
	dm.cpHex = F.hex(c[kr], c[kg], c[kb])
	dm.cpHueHex = F.hex(F.fromHsv(cp.h or 0, 1, 1))
	dm.cpSvX = string.format("%.1f%%", (cp.s or 0) * 100)
	dm.cpSvY = string.format("%.1f%%", (1 - (cp.v or 0)) * 100)
	dm.cpHueY = string.format("%.1f%%", (cp.h or 0) / 360 * 100)
end

function F.placePanel()
	local root = F.rootElement()
	if root and S.panelLeft and S.panelTop then
		local vsx, vsy = Spring.GetViewGeometry()
		local left = max(0, min(vsx - 60, S.panelLeft))
		local top = max(0, min(vsy - 40, S.panelTop))
		root.style.left = floor(left) .. "px"
		root.style.top = floor(top) .. "px"
	end
end

function F.readSliderRanges()
	for i = 1, #FIELDS do
		local key = FIELDS[i].key
		local element = S.document:GetElementById("le-sl-" .. key)
		if element then
			local lo, hi = tonumber(element:GetAttribute("min")), tonumber(element:GetAttribute("max"))
			if lo and hi then
				S.sliderRange[key] = { lo, hi }
			end
		end
	end
end

function F.buildModel()
	local model = {}
	F.refreshModel(model)
	model.presetName = S.presetText or ""

	model.act = function(_, action, arg)
		F.act(action, arg)
	end
	model.fold = function(_, key)
		S.fold[key] = not S.fold[key]
		if key == "looks" and not S.fold.looks and not S.looks then
			F.buildLooks()
		end
		S.refresh = true
	end
	model.pickLook = function(_, index)
		F.pickLook(tonumber(index))
	end
	model.tip = function(event, key)
		if event then
			event:StopPropagation()
		end
		local hint = HINTS[key] or ""
		if S.model and S.model["ch_" .. key] then
			hint = hint .. " Changed since the last save: click the gold label to put it back."
		end
		if hint ~= S.hint then
			S.hint = hint
			if S.model then
				S.model.hint = hint
			end
		end
	end
	model.pickLight = function(_, name)
		if name == "" then
			return
		end
		local _, ctrl, _, shift = Spring.GetModKeyState()
		if ctrl or shift then
			F.toggleSelect(name)
		else
			F.selectOnly(name)
		end
	end
	model.pickPiece = function(_, name)
		F.setPiece(name)
	end
	model.pickPivot = function(_, name)
		F.setPivot("piece", name)
	end
	model.revert = function(_, key)
		local field = FIELD_BY_KEY[key]
		if field then
			F.revertField(field.field)
		end
	end
	model.pieceHover = function(_, name)
		S.pieceHover = name ~= "" and name or nil
	end
	model.pickSize = function(_, name)
		F.pickSize(name)
	end
	model.pickColor = function(_, name)
		if name ~= "" then
			F.pickColorSet(name, S.cp ~= nil and S.cp.which == "fade")
		end
	end
	model.cpToggle = function(_, which)
		F.cpToggle(which)
	end
	model.cpPress = function(event, kind)
		F.endStep()
		S.cpDrag = kind
		F.cpDragTo(event)
	end
	model.cpMove = function(event)
		if S.cpDrag then
			F.cpDragTo(event)
		end
	end
	model.cpRelease = function()
		F.cpRelease()
	end
	model.cpTip = function(event, name)
		if event then
			event:StopPropagation()
		end
		S.hint = name
		if S.model then
			S.model.hint = name
		end
	end
	model.pickPreset = function(_, name)
		if name == "" then
			return
		end
		S.presetText = name
		if S.model then
			S.model.presetName = name
		end
		F.applyPreset(name)
	end
	model.slide = function(event, key)
		local field = FIELD_BY_KEY[key]
		local raw = event and event.parameters and tonumber(event.parameters.value)
		local light = S.primary and S.work[S.primary]
		if not (field and raw and light) then
			return
		end
		-- skip the echo of our own value
		local current = light.config[field.field] or 0
		if raw == F.clampRaw(key, floor(current * field.scale + 0.5)) then
			return
		end
		F.setField(field.field, raw / field.scale)
	end
	model.num = function(event, key)
		local field = FIELD_BY_KEY[key]
		local element = event and event.current_element
		local value = element and tonumber(element:GetAttribute("value"))
		if field and value and S.focusField == key then
			F.setField(field.field, max(field.min or value, value))
		end
	end
	model.numFocus = function(_, key)
		S.focusField = key
		Spring.SDLStartTextInput()
	end
	model.numBlur = function()
		S.focusField = nil
		Spring.SDLStopTextInput()
		S.refresh = true
	end
	model.nameChange = function(event)
		local element = event and event.current_element
		S.nameText = element and element:GetAttribute("value") or S.nameText
		if event and event.parameters and event.parameters.linebreak then
			F.rename(S.nameText)
		end
	end
	model.nameFocus = function()
		S.nameFor = S.primary
		S.focusField = "name"
		Spring.SDLStartTextInput()
	end
	model.nameBlur = function()
		S.focusField = nil
		Spring.SDLStopTextInput()
		if S.nameFor == S.primary then
			F.rename(S.nameText)
		end
		S.refresh = true
	end
	model.presetNameChange = function(event)
		local element = event and event.current_element
		S.presetText = element and element:GetAttribute("value") or S.presetText
	end
	model.presetFocus = function()
		S.focusField = "preset"
		Spring.SDLStartTextInput()
	end
	model.presetBlur = function()
		S.focusField = nil
		Spring.SDLStopTextInput()
	end
	model.dragStart = function(event)
		local root = F.rootElement()
		local p = event and event.parameters
		if root and p then
			S.windowDrag = { dx = p.mouse_x - root.absolute_left, dy = p.mouse_y - root.absolute_top }
		end
	end
	model.dragMove = function(event)
		local p = event and event.parameters
		if S.windowDrag and p then
			S.panelLeft = p.mouse_x - S.windowDrag.dx
			S.panelTop = p.mouse_y - S.windowDrag.dy
			F.placePanel()
		end
	end
	model.dragEnd = function()
		S.windowDrag = nil
		S.refresh = true
	end
	return model
end

function F.act(action, arg)
	if action == "save" then
		F.save()
	elseif action == "reload" then
		F.reload()
	elseif action == "undo" then
		F.undo()
	elseif action == "redo" then
		F.redo()
	elseif action == "copy" then
		F.copyUnit()
	elseif action == "add" then
		F.addLight(arg)
	elseif action == "duplicate" then
		F.endStep()
		F.duplicateSelected()
		F.endStep()
	elseif action == "delete" then
		F.deleteSelected()
	elseif action == "type" then
		F.setType(arg)
	elseif action == "beampart" then
		S.beamPart = arg
	elseif action == "presetsave" then
		F.savePreset()
	elseif action == "presetdelete" then
		F.deletePreset()
	elseif action == "linksame" then
		F.linkSame()
	elseif action == "presetunlink" then
		F.unlinkPreset()
	elseif action == "presetsize" then
		S.sizeInPresets = not S.sizeInPresets
	elseif action == "mode" then
		F.setMode(arg)
	elseif action == "fire" then
		F.testFire()
	elseif action == "preview" then
		F.previewSelected()
	elseif action == "loop" then
		F.setPreviewLoop(arg)
	elseif action == "night" then
		F.setNight(arg == "on" or (arg == "toggle" and not S.night))
	elseif action == "keys" then
		S.keysOpen = not S.keysOpen
	elseif action == "focus" then
		F.setFocus(not S.focus)
	elseif action == "pause" then
		F.setPaused(not S.paused)
	elseif action == "flat" then
		S.flat = arg == "on" or (arg == "toggle" and not S.flat)
	elseif action == "canvas" then
		S.canvas = arg == "on" or (arg == "toggle" and not S.canvas)
	elseif action == "pivot" then
		F.setPivot(arg)
	elseif action == "piecepick" then
		F.setPaused(false)
		F.setPickMode(S.pickMode ~= arg and arg or nil)
	elseif action == "camera" then
		F.setPaused(false)
		if arg == "orbit" then
			F.camBegin()
		else
			F.camEnd(0.4)
		end
	elseif action == "close" then
		S.closing = true
	end
	S.refresh = true
end

----------------------------------------------------------------
-- World: markers, gizmo, mouse
----------------------------------------------------------------

function F.worldPerPixel(x, y, z)
	local cx, cy, cz = Spring.GetCameraPosition()
	local dist = sqrt((x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2)
	local _, vsy = Spring.GetViewGeometry()
	return dist * 2 * tan(math.rad(Spring.GetCameraFOV() * 0.5)) / vsy
end

function F.segmentDistSq(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local len = dx * dx + dy * dy
	local t = len > 0 and max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / len)) or 0
	local cx, cy = ax + dx * t, ay + dy * t
	return (px - cx) ^ 2 + (py - cy) ^ 2
end

-- The light under the pointer, and for a beam which part of it.
function F.hitMarker(mx, my)
	if S.mode == "weapon" then
		return nil
	end
	if not S.unitID then
		return nil
	end
	local grab = MARKER_GRAB_PX * MARKER_GRAB_PX
	local best, bestPart, bestDist = nil, nil, grab
	for name, light in pairs(S.work) do
		local x, y, z, x2, y2, z2 = F.lightWorld(light)
		if x then
			local sx, sy = Spring.WorldToScreenCoords(x, y, z)
			local d, part = (sx - mx) ^ 2 + (sy - my) ^ 2, "start"
			if light.lightType == "beam" and x2 then
				local ex, ey = Spring.WorldToScreenCoords(x2, y2, z2)
				local dEnd = (ex - mx) ^ 2 + (ey - my) ^ 2
				if dEnd < d then
					d, part = dEnd, "end"
				end
				-- the line between the ends counts only away from them
				if d >= grab then
					d, part = F.segmentDistSq(mx, my, sx, sy, ex, ey), "both"
				end
			end
			if d < bestDist then
				best, bestPart, bestDist = name, part, d
			end
		end
	end
	return best, bestPart
end

-- Where the gizmo sits: the light, a beam part, or the middle of a selection.
function F.gizmoPivot()
	if S.mode == "weapon" then
		return nil
	end
	local names = F.selectedNames()
	if #names == 0 or not S.unitID then
		return nil
	end
	if #names == 1 then
		local light = S.work[names[1]]
		local x, y, z, x2, y2, z2 = F.lightWorld(light)
		if not x then
			return nil
		end
		if light.lightType == "beam" then
			if S.beamPart == "end" then
				return x2, y2, z2
			elseif S.beamPart == "both" then
				return (x + x2) * 0.5, (y + y2) * 0.5, (z + z2) * 0.5
			end
		end
		return x, y, z
	end
	local sx, sy, sz, n = 0, 0, 0, 0
	for i = 1, #names do
		local x, y, z = F.lightWorld(S.work[names[i]])
		if x then
			sx, sy, sz, n = sx + x, sy + y, sz + z, n + 1
		end
	end
	if n == 0 then
		return nil
	end
	return sx / n, sy / n, sz / n
end

function F.canRotate()
	local names = F.selectedNames()
	if #names > 1 then
		return true
	end
	local light = names[1] and S.work[names[1]]
	if not light then
		return false
	end
	return light.lightType == "cone" or (light.lightType == "beam" and S.beamPart == "both")
end

-- Tells the gizmo its pivot, handles and axes, and only what changed: each call there allocates.
function F.updateGizmo()
	local x, y, z = F.gizmoPivot()
	local at = Gizmo.getPivot and Gizmo.getPivot()
	if not x then
		if at or not Gizmo.getPivot then
			Gizmo.setPivot(nil)
		end
		return
	end
	if not at or at.x ~= x or at.y ~= y or at.z ~= z then
		Gizmo.setPivot(x, y, z)
	end
	local rotate = F.canRotate()
	if rotate ~= S.gizmoRotate then
		S.gizmoRotate = rotate
		local hidden = {}
		if not rotate then
			hidden.rx, hidden.ry, hidden.rz = true, true, true
		end
		if not Gizmo.setCentreMode then
			hidden.centre = true
		end
		Gizmo.setHidden(hidden)
	end
	if Gizmo.setBasis then
		local names = F.selectedNames()
		local b = #names == 1 and F.basis(S.unitID, S.work[names[1]].pieceName)
		if b then
			local xx, xy, xz = F.normalize(b.xx, b.xy, b.xz)
			local yx, yy, yz = F.normalize(b.yx, b.yy, b.yz)
			local zx, zy, zz = F.normalize(b.zx, b.zy, b.zz)
			-- the gizmo wants a right handed frame
			local det = xx * (yy * zz - yz * zy) - xy * (yx * zz - yz * zx) + xz * (yx * zy - yy * zx)
			if det < 0 then
				xx, xy, xz = -xx, -xy, -xz
			end
			local a = S.gizmoAxes
			local same = a
				and a[1][1] == xx
				and a[1][2] == xy
				and a[1][3] == xz
				and a[2][1] == yx
				and a[2][2] == yy
				and a[2][3] == yz
				and a[3][1] == zx
				and a[3][2] == zy
				and a[3][3] == zz
			if not same then
				-- new tables, never the old ones changed: a running drag holds them
				S.gizmoAxes = { { xx, xy, xz }, { yx, yy, yz }, { zx, zy, zz } }
				Gizmo.setBasis(S.gizmoAxes[1], S.gizmoAxes[2], S.gizmoAxes[3])
			end
		elseif S.gizmoAxes then
			S.gizmoAxes = nil
			Gizmo.setBasis(nil)
		end
	end
end

-- Rotates a vector around a unit axis.
function F.rotate(vx, vy, vz, ax, ay, az, angle)
	local c, s = cos(angle), sin(angle)
	local d = (vx * ax + vy * ay + vz * az) * (1 - c)
	return vx * c + (ay * vz - az * vy) * s + ax * d,
		vy * c + (az * vx - ax * vz) * s + ay * d,
		vz * c + (ax * vy - ay * vx) * s + az * d
end

function F.beginGizmoDrag(handle, mx, my)
	local alt = Spring.GetModKeyState()
	F.endStep()
	F.beginStep()
	if alt then
		F.duplicateSelected()
	end
	F.refreshLiveUnits(true)
	local px, py, pz = F.gizmoPivot()
	if not (px and Gizmo.beginDrag(handle, mx, my)) then
		F.endStep()
		return false
	end
	local start = {}
	local names = F.selectedNames()
	for i = 1, #names do
		local light = S.work[names[i]]
		start[names[i]] = { light = F.copyLight(light), basis = F.copyBasis(F.basis(S.unitID, light.pieceName)) }
	end
	S.drag = { handle = handle, start = start, pivot = { px, py, pz }, single = #names == 1, axes = S.gizmoAxes }
	return true
end

function F.applyGizmoDrag(mx, my)
	local drag = S.drag
	if not drag then
		return
	end
	local dx, dy, dz, a1, a2, a3, scale = Gizmo.updateDrag(mx, my)
	local angle, axis = 0, nil
	local angles = { a1, a2, a3 }
	for i = 1, 3 do
		if angles[i] and angles[i] ~= 0 then
			angle = -angles[i]
			axis = drag.axes and drag.axes[i] or { i == 1 and 1 or 0, i == 2 and 1 or 0, i == 3 and 1 or 0 }
		end
	end
	local px, py, pz = drag.pivot[1], drag.pivot[2], drag.pivot[3]

	local function movePoint(b, lx, ly, lz, movable)
		local wx, wy, wz = F.toWorld(b, lx, ly, lz)
		if axis and movable then
			local rx, ry, rz = F.rotate(wx - px, wy - py, wz - pz, axis[1], axis[2], axis[3], angle)
			wx, wy, wz = px + rx, py + ry, pz + rz
		end
		if movable then
			wx, wy, wz = wx + dx, wy + dy, wz + dz
		end
		local x, y, z = F.toLocal(b, wx, wy, wz)
		return F.roundTo(x, 100), F.roundTo(y, 100), F.roundTo(z, 100)
	end

	for name, entry in pairs(drag.start) do
		local light, b = S.work[name], entry.basis
		local c0 = entry.light.config
		if light and b then
			local c = light.config
			local moveStart = not (drag.single and light.lightType == "beam" and S.beamPart == "end")
			local moveEnd = not (drag.single and light.lightType == "beam" and S.beamPart == "start")
			c.posx, c.posy, c.posz = movePoint(b, c0.posx or 0, c0.posy or 0, c0.posz or 0, moveStart)
			if light.lightType == "beam" then
				c.pos2x, c.pos2y, c.pos2z = movePoint(b, c0.pos2x or 0, c0.pos2y or 0, c0.pos2z or 0, moveEnd)
			elseif light.lightType == "cone" and axis then
				local wx, wy, wz = F.dirToWorld(b, c0.dirx or 0, c0.diry or 0, c0.dirz or 0)
				wx, wy, wz = F.rotate(wx, wy, wz, axis[1], axis[2], axis[3], angle)
				local lx, ly, lz = F.normalize(F.dirToLocal(b, wx, wy, wz))
				c.dirx, c.diry, c.dirz = F.roundTo(lx, 1000), F.roundTo(ly, 1000), F.roundTo(lz, 1000)
			end
			if scale and scale ~= 1 then
				c.radius = F.roundTo(max(0.5, (c0.radius or 0) * scale), 2)
			end
			F.commit(name)
		end
	end
end

function F.emitRing(x, y, z, radius, segments, ux, uy, uz, vx, vy, vz)
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local c, s = cos(a) * radius, sin(a) * radius
		gl.Vertex(x + ux * c + vx * s, y + uy * c + vy * s, z + uz * c + vz * s)
	end
end

-- Args go through gl.BeginEnd, so no closure per call.
function F.ringLoop(x, y, z, radius, segments, ux, uy, uz, vx, vy, vz)
	gl.BeginEnd(GL.LINE_LOOP, F.emitRing, x, y, z, radius, segments, ux, uy, uz, vx, vy, vz)
end

function F.circle(x, y, z, radius, segments, cam)
	local r, u = cam.right, cam.up
	F.ringLoop(x, y, z, radius, segments, r[1], r[2], r[3], u[1], u[2], u[3])
end

function F.emitDisc(x, y, z, radius, segments, rx, ry, rz, ux, uy, uz)
	gl.Vertex(x, y, z)
	for i = 0, segments do
		local a = i / segments * math.pi * 2
		local c, s = cos(a) * radius, sin(a) * radius
		gl.Vertex(x + rx * c + ux * s, y + ry * c + uy * s, z + rz * c + uz * s)
	end
end

function F.disc(x, y, z, radius, segments, cam)
	local r, u = cam.right, cam.up
	gl.BeginEnd(GL.TRIANGLE_FAN, F.emitDisc, x, y, z, radius, segments, r[1], r[2], r[3], u[1], u[2], u[3])
end

function F.emitLine(x, y, z, x2, y2, z2)
	gl.Vertex(x, y, z)
	gl.Vertex(x2, y2, z2)
end

function F.line(x, y, z, x2, y2, z2)
	gl.BeginEnd(GL.LINES, F.emitLine, x, y, z, x2, y2, z2)
end

-- Draws `fn(...)` over a faint soft shadow, so thin lines still read on bright ground.
function F.outlined(width, r, g, b, a, fn, ...)
	if gl.Smoothing then
		gl.Smoothing(nil, true, nil)
	end
	gl.LineWidth(width + 1.5)
	gl.Color(0, 0, 0, 0.3 * a)
	fn(...)
	gl.LineWidth(width)
	gl.Color(r, g, b, a)
	fn(...)
	if gl.Smoothing then
		gl.Smoothing(nil, false, nil)
	end
end

-- A light's marker: its circle, the line to its second point, a beam's end circle.
function F.markerShape(x, y, z, size, cam, x2, y2, z2, beam)
	F.circle(x, y, z, size, 28, cam)
	if x2 then
		F.line(x, y, z, x2, y2, z2)
		if beam then
			F.circle(x2, y2, z2, size * 0.7, 20, cam)
		end
	end
end

-- The grabbable circle of a selected light: the cone's end disc, else its radius. One table
-- a light, filled again on every call: keep a copy (F.beginRingDrag), not the table.
function F.lightRing(name)
	local light = S.work[name]
	if not (light and S.selected[name]) then
		return nil
	end
	local x, y, z, x2, y2, z2 = F.lightWorld(light)
	if not x then
		return nil
	end
	local ring = S.ringCache[name]
	if not ring then
		ring = { name = name, axisU = {}, axisV = {} }
		S.ringCache[name] = ring
	end
	if light.lightType == "cone" then
		local nx, ny, nz = F.normalize(x2 - x, y2 - y, z2 - z)
		local reach = sqrt((x2 - x) ^ 2 + (y2 - y) ^ 2 + (z2 - z) ^ 2)
		-- any vector across the axis, then the third one
		local ax, ay, az = 0, 1, 0
		if abs(ny) > 0.9 then
			ax, ay = 1, 0
		end
		local ux, uy, uz = F.normalize(ny * az - nz * ay, nz * ax - nx * az, nx * ay - ny * ax)
		local u, v = ring.axisU, ring.axisV
		u[1], u[2], u[3] = ux, uy, uz
		v[1], v[2], v[3] = ny * uz - nz * uy, nz * ux - nx * uz, nx * uy - ny * ux
		ring.kind, ring.u, ring.v = "cone", u, v
		ring.x, ring.y, ring.z = x2, y2, z2
		ring.nx, ring.ny, ring.nz = nx, ny, nz
		ring.r = reach * tan(min(MAX_THETA, light.config.theta or 0))
		ring.reach = reach
		return ring
	end
	local cam = F.camVectors()
	local f = cam.forward
	ring.kind, ring.u, ring.v = "radius", cam.right, cam.up
	ring.x, ring.y, ring.z = x, y, z
	ring.nx, ring.ny, ring.nz = f[1], f[2], f[3]
	ring.r = light.config.radius or 0
	ring.reach = nil
	return ring
end

-- Pixels from the pointer to the edge of a ring on screen.
function F.ringScreenDist(ring, mx, my)
	local u, v = ring.u, ring.v
	local best, px, py = math.huge, nil, nil
	for i = 0, 48 do
		local a = i / 48 * math.pi * 2
		local c, s = cos(a) * ring.r, sin(a) * ring.r
		local sx, sy = Spring.WorldToScreenCoords(
			ring.x + u[1] * c + v[1] * s,
			ring.y + u[2] * c + v[2] * s,
			ring.z + u[3] * c + v[3] * s
		)
		if px then
			best = min(best, F.segmentDistSq(mx, my, px, py, sx, sy))
		end
		px, py = sx, sy
	end
	return sqrt(best)
end

-- The ring whose edge is under the pointer, if any.
function F.ringAt(mx, my)
	if S.mode == "weapon" or not S.unitID then
		return nil
	end
	local best, bestDist = nil, RING_GRAB_PX
	for name in pairs(S.selected) do
		local ring = F.lightRing(name)
		if ring and ring.r > 0 then
			local d = F.ringScreenDist(ring, mx, my)
			if d < bestDist then
				best, bestDist = ring, d
			end
		end
	end
	return best
end

-- The view ray under a pointer position: GetPixelDir counts y from the top.
function F.pixelDir(mx, my)
	local _, vsy, vpx = Spring.GetViewGeometry()
	return Spring.GetPixelDir(floor(mx + (vpx or 0)), floor(vsy - 1 - my))
end

-- How far from the ring's centre the pointer is, measured in the ring's plane.
function F.ringRadiusAt(ring, mx, my)
	local cx, cy, cz = Spring.GetCameraPosition()
	local dx, dy, dz = F.pixelDir(mx, my)
	local denom = dx * ring.nx + dy * ring.ny + dz * ring.nz
	if abs(denom) > 0.05 then
		local t = ((ring.x - cx) * ring.nx + (ring.y - cy) * ring.ny + (ring.z - cz) * ring.nz) / denom
		if t > 0 then
			local hx, hy, hz = cx + dx * t - ring.x, cy + dy * t - ring.y, cz + dz * t - ring.z
			return sqrt(hx * hx + hy * hy + hz * hz)
		end
	end
	-- edge on: fall back to the distance on screen
	local sx, sy = Spring.WorldToScreenCoords(ring.x, ring.y, ring.z)
	return sqrt((mx - sx) ^ 2 + (my - sy) ^ 2) * F.worldPerPixel(ring.x, ring.y, ring.z)
end

function F.beginRingDrag(ring)
	F.endStep()
	F.beginStep()
	local start = {}
	for name in pairs(S.selected) do
		local c = S.work[name] and S.work[name].config
		if c then
			start[name] = { radius = c.radius or 0, theta = c.theta or 0 }
		end
	end
	-- the ring as it is now: the live one follows the light while it is dragged
	local held = {}
	for key, value in pairs(ring) do
		held[key] = value
	end
	held.u = { ring.u[1], ring.u[2], ring.u[3] }
	held.v = { ring.v[1], ring.v[2], ring.v[3] }
	S.ringDrag = { ring = held, start = start }
	return true
end

-- The edge follows the pointer; every selected light of that kind scales by the same factor.
function F.applyRingDrag(mx, my)
	local drag = S.ringDrag
	local ring = drag and drag.ring
	if not (ring and ring.r > 0.01) then
		return
	end
	local k = F.ringRadiusAt(ring, mx, my) / ring.r
	for name, s in pairs(drag.start) do
		local light = S.work[name]
		if light then
			local c = light.config
			if ring.kind == "cone" and light.lightType == "cone" then
				local theta = math.atan(tan(min(MAX_THETA, s.theta)) * k)
				c.theta = F.roundTo(max(0.01, min(MAX_THETA, theta)), 1000)
				F.commit(name)
			elseif ring.kind == "radius" and light.lightType ~= "cone" then
				c.radius = F.roundTo(max(0.5, s.radius * k), 2)
				F.commit(name)
			end
		end
	end
end

function F.drawMarkers()
	if S.mode == "weapon" then
		return
	end
	local cam = F.camVectors()
	if not (cam and cam.right and cam.up) then
		return
	end
	gl.DepthTest(false)
	local ringHover = S.ringDrag and S.ringDrag.ring or S.ringHover
	for name, light in pairs(S.work) do
		local x, y, z, x2, y2, z2 = F.lightWorld(light)
		if x then
			local selected = S.selected[name]
			local hovered = S.hover == name
			local px = F.worldPerPixel(x, y, z)
			local size = px * MARKER_PX * (hovered and 1.6 or 1)
			-- magenta: rare in unit lights, so markers stay visible
			local r, g, b, a, width = 0.95, 0.35, 0.85, 0.85, 1.5
			if hovered then
				r, g, b, a, width = 1, 0.6, 0.95, 1, 2.5
			elseif selected then
				r, g, b, a, width = 1, 0.78, 0.3, 1, 2
			end
			gl.Color(0, 0, 0, 0.35)
			F.disc(x, y, z, size, 20, cam)
			F.outlined(width, r, g, b, a, F.markerShape, x, y, z, size, cam, x2, y2, z2, light.lightType == "beam")
			if hovered then
				F.outlined(1, r, g, b, 0.5, F.circle, x, y, z, size * 1.7, 32, cam)
			end
			local ring = F.lightRing(name)
			if ring and ring.r > 0 then
				local hot = ringHover and ringHover.name == name and ringHover.kind == ring.kind
				local ra = hot and 1 or (ring.kind == "cone" and 0.8 or 0.5)
				local u, v = ring.u, ring.v
				F.outlined(
					hot and 2.5 or 1.25,
					1,
					hot and 0.95 or 0.78,
					hot and 0.7 or 0.3,
					ra,
					F.ringLoop,
					ring.x,
					ring.y,
					ring.z,
					ring.r,
					64,
					u[1],
					u[2],
					u[3],
					v[1],
					v[2],
					v[3]
				)
			end
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end

----------------------------------------------------------------
-- Piece picking
----------------------------------------------------------------

local PICK_PX = 12
-- box corner i as indices into { minx, miny, minz, maxx, maxy, maxz }, and the 12 edges
---@type integer[]
local CORNER = { 1, 2, 3, 4, 2, 3, 1, 5, 3, 4, 5, 3, 1, 2, 6, 4, 2, 6, 1, 5, 6, 4, 5, 6 }
---@type integer[]
local EDGES = { 1, 2, 3, 4, 5, 6, 7, 8, 1, 3, 2, 4, 5, 7, 6, 8, 1, 5, 2, 6, 3, 7, 4, 8 }

-- "light" puts the selected lights on the clicked piece, "pivot" pins the orbit to it, nil ends.
function F.setPickMode(mode)
	if mode == "light" and (S.mode == "weapon" or not next(S.selected)) then
		F.setStatus("Select a light on the unit first")
		mode = nil
	end
	S.pickMode, S.pickCount, S.pickLast = mode, 0, nil
	if mode then
		F.setStatus("Click a piece of the model. The same spot again picks the piece behind")
	end
	S.refresh = true
end

-- A piece's bounding box in piece space, or false for a piece without vertices.
function F.pieceBox(pieceName)
	local box = S.pieceInfo[pieceName]
	if box == nil then
		box = false
		local index = S.pieceMap and S.pieceMap[pieceName]
		local info = index and Spring.GetUnitPieceInfo(S.unitID, index)
		local lo, hi = info and info.min, info and info.max
		if info and lo and hi and not info.empty and (hi[1] - lo[1]) + (hi[2] - lo[2]) + (hi[3] - lo[3]) > 0.01 then
			box = { lo[1], lo[2], lo[3], hi[1], hi[2], hi[3] }
		end
		S.pieceInfo[pieceName] = box
	end
	return box
end

local function slab(t0, t1, o, d, lo, hi)
	if abs(d) < 1e-9 then
		if o < lo or o > hi then
			return 1, 0
		end
		return t0, t1
	end
	local a, b = (lo - o) / d, (hi - o) / d
	if a > b then
		a, b = b, a
	end
	return max(t0, a), min(t1, b)
end

-- Ray length to where a piece space ray enters the box, nil when it misses.
function F.rayBox(box, ox, oy, oz, dx, dy, dz)
	local t0, t1 = slab(-math.huge, math.huge, ox, dx, box[1], box[4])
	t0, t1 = slab(t0, t1, oy, dy, box[2], box[5])
	t0, t1 = slab(t0, t1, oz, dz, box[3], box[6])
	if t1 >= max(t0, 0) then
		return max(t0, 0)
	end
	return nil
end

function F.nearerHit(a, b)
	return a.t < b.t
end

-- Pieces under the pointer, nearest first: boxes by the ray, pieces without vertices by their origin.
function F.pieceHits(mx, my)
	local hits, pool, count = S.pickHits, S.pickPool, 0
	if S.unitID and S.pieceMap then
		local cx, cy, cz = Spring.GetCameraPosition()
		local wx, wy, wz = F.pixelDir(mx, my)
		for name in pairs(S.pieceMap) do
			local b = F.basis(S.unitID, name)
			local t
			if b then
				local box = F.pieceBox(name)
				if box then
					local ox, oy, oz = F.toLocal(b, cx, cy, cz)
					t = F.rayBox(box, ox, oy, oz, F.dirToLocal(b, wx, wy, wz))
				else
					local sx, sy, sz = Spring.WorldToScreenCoords(b.ox, b.oy, b.oz)
					if sz < 1 and (sx - mx) ^ 2 + (sy - my) ^ 2 < PICK_PX * PICK_PX then
						t = sqrt((b.ox - cx) ^ 2 + (b.oy - cy) ^ 2 + (b.oz - cz) ^ 2)
					end
				end
			end
			if t then
				count = count + 1
				local hit = pool[count] or {}
				pool[count] = hit
				hit.name, hit.t = name, t
				hits[count] = hit
			end
		end
	end
	for i = #hits, count + 1, -1 do
		hits[i] = nil
	end
	table.sort(hits, F.nearerHit)
	return hits, count
end

-- Which hit a click here takes: the next one behind when the last click was on the same spot.
function F.pickIndexAt(mx, my, count, advance)
	local last = S.pickLast
	if not (last and abs(last.x - mx) <= 4 and abs(last.y - my) <= 4) then
		return 1
	end
	if advance then
		return last.index % count + 1
	end
	return min(last.index, count)
end

function F.pickHoverAt(mx, my)
	local hits, count = F.pieceHits(mx, my)
	S.pickCount = count
	if count == 0 then
		return nil
	end
	S.pickIndex = F.pickIndexAt(mx, my, count, false)
	return hits[S.pickIndex].name
end

-- False when nothing is under the pointer.
function F.pickPress(mx, my)
	local hits, count = F.pieceHits(mx, my)
	if count == 0 then
		return false
	end
	local index = F.pickIndexAt(mx, my, count, true)
	S.pickLast = { x = mx, y = my, index = index }
	local name = hits[index].name
	if S.pickMode == "pivot" then
		F.setPivot("piece", name)
	else
		F.setPiece(name)
	end
	F.setStatus(string.format("Picked %s, %d of %d here", name, index, count))
	S.refresh = true
	return true
end

function F.emitBox(b, box)
	for i = 1, #EDGES do
		local c = (EDGES[i] - 1) * 3
		gl.Vertex(F.toWorld(b, box[CORNER[c + 1]], box[CORNER[c + 2]], box[CORNER[c + 3]]))
	end
end

function F.boxLines(b, box)
	gl.BeginEnd(GL.LINES, F.emitBox, b, box)
end

-- The piece under the pick pointer or a list row: its box, and its axes at the origin.
function F.drawPieceHighlight(name)
	local b = name and F.basis(S.unitID, name)
	if not b then
		return
	end
	gl.DepthTest(false)
	local box = F.pieceBox(name)
	if box then
		F.outlined(1.5, 0.45, 0.9, 1, 0.9, F.boxLines, b, box)
	end
	local len = F.worldPerPixel(b.ox, b.oy, b.oz) * 28
	local kx = len / max(1e-6, sqrt(b.xx * b.xx + b.xy * b.xy + b.xz * b.xz))
	local ky = len / max(1e-6, sqrt(b.yx * b.yx + b.yy * b.yy + b.yz * b.yz))
	local kz = len / max(1e-6, sqrt(b.zx * b.zx + b.zy * b.zy + b.zz * b.zz))
	F.outlined(2, 1, 0.35, 0.35, 1, F.line, b.ox, b.oy, b.oz, b.ox + b.xx * kx, b.oy + b.xy * kx, b.oz + b.xz * kx)
	F.outlined(2, 0.4, 1, 0.4, 1, F.line, b.ox, b.oy, b.oz, b.ox + b.yx * ky, b.oy + b.yy * ky, b.oz + b.yz * ky)
	F.outlined(2, 0.4, 0.6, 1, 1, F.line, b.ox, b.oy, b.oz, b.ox + b.zx * kz, b.oy + b.zy * kz, b.oz + b.zz * kz)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end

function F.drawPieceLabel()
	local name = S.pickHover or S.pieceHover
	local b = name and F.basis(S.unitID, name)
	if b then
		local sx, sy = Spring.WorldToScreenCoords(b.ox, b.oy, b.oz)
		local text = name
		if S.pickHover and S.pickCount > 1 then
			text = string.format("%s  %d/%d", name, S.pickIndex, S.pickCount)
		end
		gl.Color(0.45, 0.9, 1, 1)
		gl.Text(text, sx + 12, sy + 6, 18, "o")
	elseif S.pickMode then
		local mx, my = Spring.GetMouseState()
		gl.Color(0.45, 0.9, 1, 1)
		gl.Text("PICK A PIECE", mx + 20, my + 4, 16, "o")
	end
	gl.Color(1, 1, 1, 1)
end

----------------------------------------------------------------
-- Flat unit and canvas views
----------------------------------------------------------------

-- Screen pass over the G-buffer: the unit turns to clay, the rest to a grid canvas.
-- Runs before particles and lights so they draw over it.
function F.backdropInit()
	if S.backdrop ~= nil then
		return S.backdrop
	end
	S.backdrop = false
	local LuaShader, VBOTable = gl.LuaShader, gl.InstanceVBOTable
	if not (LuaShader and VBOTable) then
		S.flat, S.canvas = false, false
		F.setStatus("The flat and canvas views could not start on this machine")
		return false
	end
	local defs = LuaShader.GetEngineUniformBufferDefs()
	local shader = LuaShader({
		vertex = BACKDROP.vs,
		fragment = BACKDROP.fs:gsub("//__ENGINEUNIFORMBUFFERDEFS__", function()
			return defs
		end),
		uniformInt = { mapDepths = 0, modelDepths = 1 },
		uniformFloat = { unitSphere = { 0, 0, 0, 0 }, plane = { 0, 0, 0, 0 }, look = { 0, 0, 1, 1 } },
	}, "Light Editor backdrop")
	local rect = VBOTable.fillVAOSlots(VBOTable.MakeTexRectVAO())
	if rect and shader:Initialize() then
		S.backdrop = { shader = shader, rect = rect }
	else
		if rect then
			rect:Delete()
		end
		S.flat, S.canvas = false, false
		F.setStatus("The flat and canvas views could not start on this machine")
	end
	return S.backdrop
end

function F.backdropFree()
	local b = S.backdrop
	if b then
		b.shader:Finalize()
		b.rect:Delete()
	end
	S.backdrop = nil
end

-- How far the model reaches from its middle, and the radius of the ground disc.
function F.backdropReach()
	if S.reachDef ~= S.unitDefID then
		local reach = Spring.GetUnitRadius(S.unitID) or 30
		local d = Spring.GetUnitDefDimensions(S.unitDefID)
		if d then
			local diagonal = sqrt((d.maxx - d.minx) ^ 2 + (d.maxy - d.miny) ^ 2 + (d.maxz - d.minz) ^ 2)
			reach = max(reach, d.radius or 0, diagonal * 0.5)
		end
		S.reachDef, S.reach = S.unitDefID, reach * 1.3
	end
	local reach = S.reach
	local far = 0
	for _, light in pairs(S.work) do
		far = max(far, light.config.radius or 0)
	end
	return reach, min(1500, max(250, reach * 3, far * 1.25))
end

function F.drawBackdrop()
	local b = F.backdropInit()
	if not b then
		return
	end
	local x, y, z, mx, my, mz = Spring.GetUnitPosition(S.unitID, true)
	local reach, disc = F.backdropReach()
	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Blending(false)
	gl.Culling(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
	b.shader:Activate()
	b.shader:SetUniform("unitSphere", mx, my, mz, reach)
	b.shader:SetUniform("plane", x, y, z, disc)
	local ground = not (S.cam and S.cam.under)
	b.shader:SetUniform("look", S.flat and 1 or 0, S.canvas and 1 or 0, S.night and 0.5 or 1, ground and 1 or 0)
	b.rect:DrawArrays(GL.TRIANGLES)
	b.shader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	-- the state the particle pass expects
	gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(true)
	gl.ClipDistance(0, false)
	gl.ClipDistance(1, false)
	gl.ClipDistance(2, false)
end

----------------------------------------------------------------
-- Orbit camera
----------------------------------------------------------------

function F.overElement(element, mx, my)
	if not element then
		return false
	end
	local _, vsy = Spring.GetViewGeometry()
	local left, top = element.absolute_left, element.absolute_top
	return mx >= left
		and mx <= left + element.offset_width
		and (vsy - my) >= top
		and (vsy - my) <= top + element.offset_height
end

-- The panel or its keybinds window is under the pointer.
function F.overPanel(mx, my)
	if F.overElement(F.rootElement(), mx, my) then
		return true
	end
	if not S.document then
		return false
	end
	return (S.keysOpen == true and F.overElement(S.document:GetElementById("le-keys"), mx, my))
		or (S.cp ~= nil and F.overElement(S.document:GetElementById("le-cp"), mx, my))
end

-- Pins the orbit to a light ("light", the selected one unless named) or a piece ("piece",
-- "" = the unit's base). Anything else follows the selection again.
function F.setPivot(kind, name)
	if kind == "light" then
		name = name or S.primary
		if S.mode == "weapon" or not (name and S.work[name]) then
			F.setStatus("Select a light on the unit first")
			return
		end
		S.pivotPin = { kind = "light", name = name, key = "light:" .. name }
	elseif kind == "piece" then
		if name == "" then
			name = nil
		end
		S.pivotPin = { kind = "piece", name = name, key = "piece:" .. (name or "") }
	else
		S.pivotPin = nil
	end
	S.fold.pivot = true
	F.camBegin()
	S.refresh = true
end

-- Where the pinned pivot is now, and its key. Nil without a pin, or while it has no place.
function F.pinnedPivot()
	local pin = S.pivotPin
	if not pin or not S.unitID or not Spring.ValidUnitID(S.unitID) then
		return nil
	end
	if pin.kind == "piece" then
		local b = F.basis(S.unitID, pin.name)
		if b then
			return b.ox, b.oy, b.oz, pin.key
		end
		return nil
	end
	-- weapon lights have no place: the pin waits for the unit lights to come back
	if S.mode == "weapon" then
		return nil
	end
	local light = S.work[pin.name]
	if not light then
		S.pivotPin = nil
		S.refresh = true
		return nil
	end
	local x, y, z = F.lightWorld(light)
	return x, y, z, pin.key
end

-- What the orbit circles: the pinned light or piece, else the selected lights, else the
-- unit's middle. The key tells a new pivot.
function F.orbitPivot()
	if not S.unitID or not Spring.ValidUnitID(S.unitID) then
		return nil
	end
	local pinX, pinY, pinZ, pinKey = F.pinnedPivot()
	if pinX then
		return pinX, pinY, pinZ, pinKey
	end
	local x, y, z = F.gizmoPivot()
	if x then
		return x, y, z, S.unitID .. ":" .. table.concat(F.selectedNames(), ",")
	end
	local _, _, _, mx, my, mz = Spring.GetUnitPosition(S.unitID, true)
	return mx, my, mz, tostring(S.unitID)
end

function F.clampPitch(pitch)
	return max(-ORBIT.maxPitch, min(ORBIT.maxPitch, pitch))
end

-- Eye of an orbit pose { x, y, z, yaw, pitch, dist }; pitch above zero looks down.
function F.camEye(p)
	return CameraMath.EyeFromTarget(p.x, p.y, p.z, p.pitch, p.yaw, p.dist)
end

-- Starts the orbit or moves it to a new pivot: the eye stays and turns to it.
function F.camBegin()
	local x, y, z, key = F.orbitPivot()
	local c = S.cam
	if not x then
		return c ~= nil
	end
	if not c then
		local rx, ry = CameraMath.RotFromDir(Spring.GetCameraDirection())
		local ex, ey, ez = Spring.GetCameraPosition()
		local dist = max(ORBIT.minDist, sqrt((x - ex) ^ 2 + (y - ey) ^ 2 + (z - ez) ^ 2))
		local fx, fy, fz = CameraMath.FwdFromRot(rx, ry)
		c = {
			saved = Spring.GetCameraState(),
			clamp = Spring.GetConfigInt("FPSClampPos", 1),
			fov = Spring.GetCameraFOV(),
			offset = { 0, 0, 0 },
			now = {
				x = ex + fx * dist,
				y = ey + fy * dist,
				z = ez + fz * dist,
				yaw = ry,
				pitch = rx - math.pi * 0.5,
				dist = dist,
			},
			want = {},
			view = { name = "fps", mode = 0, rz = 0 },
		}
		S.cam = c
		-- the fps camera keeps the eye over the ground unless told not to
		Spring.SetConfigInt("FPSClampPos", 0, true)
		S.refresh = true
	end
	if key ~= c.key then
		c.key = key
		c.offset[1], c.offset[2], c.offset[3] = 0, 0, 0
	end
	local px, py, pz = x + c.offset[1], y + c.offset[2], z + c.offset[3]
	local w, n = c.want, c.now
	if not w.x or abs(px - w.x) + abs(py - w.y) + abs(pz - w.z) > 1 then
		local ex, ey, ez = F.camEye(n)
		local rx, ry = CameraMath.LookAtRotation(ex, ey, ez, px, py, pz, n.yaw)
		w.x, w.y, w.z = px, py, pz
		w.pitch = F.clampPitch(rx - math.pi * 0.5)
		w.yaw = n.yaw + ((ry - n.yaw + math.pi) % (2 * math.pi) - math.pi)
		w.dist = min(ORBIT.maxDist, max(ORBIT.minDist, sqrt((px - ex) ^ 2 + (py - ey) ^ 2 + (pz - ez) ^ 2)))
	end
	return true
end

-- A drag of dx, dy pixels: "orbit" circles the pivot, "pan" slides it in the view plane.
function F.camDrag(kind, dx, dy)
	local c = S.cam
	local w = c and c.want
	if not (w and w.x) then
		return
	end
	if kind == "orbit" then
		-- the model turns with the hand
		w.yaw = w.yaw + dx * ORBIT.rate
		w.pitch = F.clampPitch(w.pitch - dy * ORBIT.rate)
		return
	end
	local _, vsy = Spring.GetViewGeometry()
	local scale = 2 * w.dist * tan(math.rad(c.fov) * 0.5) / max(1, vsy)
	local fx, fy, fz = CameraMath.FwdFromRot(math.pi * 0.5 + w.pitch, w.yaw)
	local rx, rz = cos(w.yaw), sin(w.yaw)
	-- screen up: the camera's right crossed with its forward
	local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy
	local o = c.offset
	local nx = o[1] - (rx * dx + ux * dy) * scale
	local ny = o[2] - uy * dy * scale
	local nz = o[3] - (rz * dx + uz * dy) * scale
	local reach = max(ORBIT.minPan, ORBIT.panPerRadius * (S.unitID and Spring.GetUnitRadius(S.unitID) or 0))
	local length = sqrt(nx * nx + ny * ny + nz * nz)
	if length > reach then
		nx, ny, nz = nx * reach / length, ny * reach / length, nz * reach / length
	end
	w.x, w.y, w.z = w.x + nx - o[1], w.y + ny - o[2], w.z + nz - o[3]
	o[1], o[2], o[3] = nx, ny, nz
end

-- Wheel notches toward the pivot, negative away.
function F.camZoom(notches)
	local w = S.cam and S.cam.want
	if w and w.dist then
		w.dist = min(ORBIT.maxDist, max(ORBIT.minDist, w.dist * ORBIT.zoom ^ notches))
	end
end

function F.drawMap(on)
	if Spring.SetDrawGround then
		Spring.SetDrawGround(on)
	end
	if Spring.SetDrawWater then
		Spring.SetDrawWater(on)
	end
end

-- Glides the camera to the wanted pose; the map is hidden while the eye is under it.
function F.camStep(dt)
	local c = S.cam
	if not (c and c.want.x) then
		return
	end
	local k = 1 - math.exp(-(dt or 0.016) / ORBIT.glide)
	local n, w = c.now, c.want
	-- a pinned pivot is followed as it moves
	local pinX, pinY, pinZ, pinKey = F.pinnedPivot()
	if pinX and pinKey == c.key then
		local o = c.offset
		w.x, w.y, w.z = pinX + o[1], pinY + o[2], pinZ + o[3]
	end
	for key, value in pairs(w) do
		n[key] = n[key] + (value - n[key]) * k
	end
	local ex, ey, ez, rx, ry = F.camEye(n)
	local v = c.view
	v.px, v.py, v.pz, v.rx, v.ry, v.fov = ex, ey, ez, rx, ry, c.fov
	v.dx, v.dy, v.dz = CameraMath.FwdFromRot(rx, ry)
	Spring.SetCameraState(v, 0)
	local under = ey < Spring.GetGroundHeight(ex, ez)
	if under ~= (c.under == true) then
		c.under = under
		F.drawMap(not under)
	end
end

-- Back to the game camera as it was, over `glide` seconds.
function F.camEnd(glide)
	local c = S.cam
	if not c then
		return
	end
	S.cam = nil
	if c.under then
		F.drawMap(true)
	end
	Spring.SetConfigInt("FPSClampPos", c.clamp, true)
	Spring.SetCameraState(c.saved, glide or 0)
	S.refresh = true
end

-- Hover highlight and selection platters off while the editor runs, so the model reads clean.
function F.holdHover(held)
	local su = WG.selectedunits
	if held then
		if su and su ~= S.hoverHeldOn and su.holdMouseover then
			su.holdMouseover("light editor", true)
			if su.holdPlatters then
				su.holdPlatters("light editor", true)
			end
			S.hoverHeldOn = su
		end
	elseif su and su == S.hoverHeldOn then
		su.holdMouseover("light editor", false)
		if su.holdPlatters then
			su.holdPlatters("light editor", false)
		end
		S.hoverHeldOn = nil
	end
end

-- Focus mode: hideinterface with the editor still running.
function F.setFocus(on)
	on = on == true
	if on == S.focus then
		return
	end
	S.focus = on
	S.focusTimer = Spring.GetTimer()
	Spring.SendCommands(on and "hideinterface 1" or "hideinterface 0")
	S.refresh = true
end

-- Pause: the game gets the mouse, camera and selection; the panel and the edited lights stay.
function F.setPaused(on)
	on = on == true
	if on == S.paused then
		return
	end
	S.paused = on
	if on then
		F.endStep()
		if S.drag then
			S.drag = nil
			Gizmo.endDrag()
		end
		if S.cpDrag then
			F.cpRelease()
		end
		S.ringDrag = nil
		F.setPickMode(nil)
		S.pausedOrbit = S.cam ~= nil
		F.camEnd(0.4)
		F.holdHover(false)
		S.hover, S.ringHover, S.gizmoHover, S.pickHover, S.pieceHover = nil, nil, nil, nil, nil
	else
		local selection = Spring.GetSelectedUnits()
		if selection[1] then
			F.setUnit(selection[1])
		end
		if S.pausedOrbit and S.unitID then
			F.camBegin()
		end
		S.pausedOrbit = nil
	end
	S.refresh = true
end

-- The interface came back from outside (F5): drop the flag so the eye reads right.
function F.syncFocus()
	if not S.focus or Spring.DiffTimers(Spring.GetTimer(), S.focusTimer) < 0.5 then
		return
	end
	if not Spring.IsGUIHidden() then
		S.focus = false
		S.refresh = true
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function widget:Initialize()
	S.context = RmlUi.GetContext("shared")
	if not S.context then
		Spring.Echo("[Light Editor] no shared RmlUi context")
		widgetHandler:RemoveWidget()
		return
	end
	S.model = S.context:OpenDataModel(MODEL_NAME, F.buildModel(), self)
	if not S.model then
		Spring.Echo("[Light Editor] could not open the data model")
		widgetHandler:RemoveWidget()
		return
	end
	S.document = S.context:LoadDocument(RML_PATH, self)
	if not S.document then
		Spring.Echo("[Light Editor] could not load " .. RML_PATH)
		S.context:RemoveDataModel(MODEL_NAME)
		S.model = nil
		widgetHandler:RemoveWidget()
		return
	end
	S.document:ReloadStyleSheet()
	S.document:Show()
	F.readSliderRanges()
	F.placePanel()

	S.gizmoReady = Gizmo.init()
	if Gizmo.setScreenSize then
		Gizmo.setScreenSize(110)
	end
	if Gizmo.setCentreMode then
		Gizmo.setCentreMode("screen")
	end
	if Gizmo.setShown then
		Gizmo.setShown({ s = true })
	end
	Gizmo.setObjectRadius(0)

	WG.LightEditor = {
		act = F.act,
		setField = function(key, value)
			F.setField(key, value)
			F.endStep()
		end,
		selectLight = F.selectOnly,
		toggleSelect = F.toggleSelect,
		revertField = F.revertField,
		rename = F.rename,
		setPiece = F.setPiece,
		applyPreset = F.applyPreset,
		pickSize = F.pickSize,
		setMode = F.setMode,
		buildLooks = F.buildLooks,
		pickLook = F.pickLook,
		pickColorSet = F.pickColorSet,
		pieceHits = F.pieceHits,
		pieceBox = F.pieceBox,
		basis = F.basis,
		getState = function()
			return S
		end,
		diskPath = F.diskPath,
		lightWorld = F.lightWorld,
		dirtyCount = F.dirtyCount,
		gizmoPivot = F.gizmoPivot,
		gizmoHit = function(mx, my)
			return Gizmo.hitTest(mx, my)
		end,
		gizmoHas = function(name)
			return Gizmo[name] ~= nil
		end,
		camBegin = F.camBegin,
		setPivot = F.setPivot,
		camDrag = F.camDrag,
		camZoom = F.camZoom,
		lightRing = F.lightRing,
		ringAt = F.ringAt,
		cpToggle = F.cpToggle,
	}

	local selection = Spring.GetSelectedUnits()
	if selection[1] then
		F.setUnit(selection[1])
	end
end

function widget:Shutdown()
	WG.LightEditor = nil
	F.stopFire()
	F.previewStop()
	F.setFocus(false)
	F.backdropFree()
	F.setNight(false)
	F.camEnd(0)
	F.holdHover(false)
	if S.focusField then
		Spring.SDLStopTextInput()
	end
	Gizmo.shutdown()
	if S.document then
		S.document:Close()
		S.document = nil
	end
	if S.context and S.model then
		S.context:RemoveDataModel(MODEL_NAME)
		S.model = nil
	end
end

function widget:SelectionChanged(selection)
	if selection and selection[1] and not S.paused then
		F.setUnit(selection[1])
	end
end

function widget:UnitDestroyed(unitID)
	if unitID == S.unitID then
		F.setUnit(nil, true)
	end
end

function widget:Update(dt)
	if S.closing then
		widgetHandler:RemoveWidget()
		return
	end
	F.holdHover(not S.paused)
	F.syncFocus()
	F.syncFire()
	F.previewStep()
	F.camStep(dt)
	F.placeSide()
	-- a square drag released outside the window
	if S.cpDrag and not select(3, Spring.GetMouseState()) then
		F.cpRelease()
	end
	local api = F.api()
	if not api then
		if S.defLights then
			F.setUnit(nil, true)
		end
		return
	end
	-- the renderer loaded its config again behind our back
	if S.unitDefID and S.defLights and api.GetUnitDefLights()[S.unitDefID] ~= S.defLights then
		S.dirty = {}
		S.baseline = {}
		S.weaponDirty = {}
		S.weaponBase = {}
		F.setUnit(S.unitID, true)
	end
	if S.stepOpen and not S.drag and not S.cpDrag and F.now() - S.stepTime > 0.6 then
		F.endStep()
	end
	if S.status ~= "" and F.now() - S.statusTime > 8 then
		S.status = ""
		S.refresh = true
	end
	F.refreshLiveUnits(false)

	if S.gizmoReady then
		F.updateGizmo()
	end
	if not S.paused and not S.drag and not S.ringDrag and not (S.cam and S.cam.drag) then
		local mx, my = Spring.GetMouseState()
		local hover, part, gizmoHover, ringHover, pickHover
		local overPanel = F.overPanel(mx, my)
		if not overPanel then
			-- a list row left with the panel sends no mouseout
			S.pieceHover = nil
		end
		if overPanel then
			S.pickCount = 0
		elseif S.pickMode then
			pickHover = F.pickHoverAt(mx, my)
		else
			gizmoHover = S.gizmoReady and Gizmo.hitTest(mx, my) or nil
			if not gizmoHover then
				hover, part = F.hitMarker(mx, my)
				if not hover then
					ringHover = F.ringAt(mx, my)
				end
			end
		end
		S.gizmoHover, S.hover, S.hoverPart, S.ringHover = gizmoHover, hover, part, ringHover
		S.pickHover = pickHover
	end

	if S.refresh then
		S.refresh = false
		F.refreshModel()
	end
end

function widget:DrawWorld()
	if S.paused or not S.unitID or not Spring.ValidUnitID(S.unitID) then
		return
	end
	F.drawMarkers()
	F.drawPieceHighlight(S.pickHover or S.pieceHover)
	if S.gizmoReady and not S.pickMode then
		Gizmo.draw(S.gizmoHover)
	end
end

-- Runs for each water side and mirror pass: the main view is the above water one.
function widget:DrawWorldPreParticles(drawAboveWater, _, drawReflection, drawRefraction)
	if S.paused or not (S.flat or S.canvas) or not drawAboveWater or drawReflection or drawRefraction then
		return
	end
	if S.unitID and Spring.ValidUnitID(S.unitID) then
		F.drawBackdrop()
	end
end

-- Not DrawScreen: the widget handler skips that one while the interface is hidden.
function widget:DrawScreenEffects()
	if S.hover and not S.drag then
		local mx, my = Spring.GetMouseState()
		gl.Color(1, 0.86, 0.5, 1)
		gl.Text(S.hover, mx + 20, my + 4, 20, "o")
		gl.Color(1, 1, 1, 1)
	end
	if S.unitID and not S.paused then
		F.drawPieceLabel()
	end
end

function widget:MousePress(mx, my, button)
	if S.drag or S.ringDrag then
		return true
	end
	if S.paused then
		return false
	end
	if button == 2 or button == 3 then
		if F.overPanel(mx, my) or not F.camBegin() then
			return false
		end
		S.cam.drag = button == 3 and "orbit" or "pan"
		return true
	end
	if button ~= 1 or not S.unitID then
		return false
	end
	if S.pickMode and not F.overPanel(mx, my) then
		if not F.pickPress(mx, my) then
			F.setPickMode(nil)
		end
		return true
	end
	if S.gizmoHover and S.gizmoReady then
		return F.beginGizmoDrag(S.gizmoHover, mx, my)
	end
	if S.ringHover then
		return F.beginRingDrag(S.ringHover)
	end
	local _, ctrl, _, shift = Spring.GetModKeyState()
	if S.hover then
		if ctrl or shift then
			F.toggleSelect(S.hover)
		else
			local part = S.hoverPart
			F.selectOnly(S.hover)
			local light = S.work[S.hover]
			S.beamPart = light and light.lightType == "beam" and part or "both"
		end
		return true
	end
	-- a click on nothing lets the selected lights go; the click itself passes on
	if next(S.selected) and not (ctrl or shift) and not F.overPanel(mx, my) then
		F.selectOnly(nil)
	end
	return false
end

function widget:MouseMove(mx, my, dx, dy)
	if S.ringDrag then
		F.applyRingDrag(mx, my)
		return true
	end
	if S.cam and S.cam.drag then
		F.camDrag(S.cam.drag, dx, dy)
		return true
	end
	if S.drag then
		F.applyGizmoDrag(mx, my)
		return true
	end
	return false
end

function widget:MouseWheel(up)
	local mx, my = Spring.GetMouseState()
	if S.paused or F.overPanel(mx, my) or not F.camBegin() then
		return false
	end
	-- the game camera's way: "up" with a positive ScrollWheelSpeed zooms out
	local turn = up and 1 or -1
	F.camZoom(turn * Spring.GetConfigInt("ScrollWheelSpeed", 25) > 0 and -1 or 1)
	return true
end

function widget:MouseRelease()
	if S.ringDrag then
		S.ringDrag = nil
		F.endStep()
		return -1
	end
	if S.cam and S.cam.drag then
		S.cam.drag = nil
		return -1
	end
	if S.drag then
		S.drag = nil
		Gizmo.endDrag()
		F.endStep()
		return -1
	end
	return false
end

local KEY = { z = 122, y = 121, s = 115, d = 100, delete = 127, up = 273, down = 274, escape = 27 }

function widget:KeyPress(key, mods)
	if S.paused or not S.unitID then
		return false
	end
	if key == KEY.escape and S.pickMode then
		F.setPickMode(nil)
		return true
	end
	if S.focusField then
		local field = FIELD_BY_KEY[S.focusField]
		local light = S.primary and S.work[S.primary]
		if field and light and (key == KEY.up or key == KEY.down) then
			local step = (key == KEY.up and 1 or -1) / field.scale
			local value = F.roundTo((light.config[field.field] or 0) + step, field.scale)
			F.setField(field.field, max(field.min or value, value))
			S.model["num_" .. field.key] = F.formatValue(light.config[field.field])
			return true
		end
		return false
	end
	if mods.ctrl and key == KEY.z then
		if mods.shift then
			F.redo()
		else
			F.undo()
		end
		return true
	elseif mods.ctrl and key == KEY.y then
		F.redo()
		return true
	elseif mods.ctrl and key == KEY.s then
		F.save()
		return true
	elseif mods.ctrl and key == KEY.d then
		F.act("duplicate")
		return true
	elseif key == KEY.delete and next(S.selected) then
		F.deleteSelected()
		return true
	end
	return false
end

function widget:GetConfigData()
	return {
		panelLeft = S.panelLeft,
		panelTop = S.panelTop,
		fold = S.fold,
		lastByUnit = S.lastByUnit,
		sizeInPresets = S.sizeInPresets,
		keysOpen = S.keysOpen,
		flat = S.flat,
		canvas = S.canvas,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	S.panelLeft = tonumber(data.panelLeft)
	S.panelTop = tonumber(data.panelTop)
	if type(data.fold) == "table" then
		for key, value in pairs(data.fold) do
			if S.fold[key] ~= nil then
				S.fold[key] = value == true
			end
		end
	end
	if type(data.lastByUnit) == "table" then
		S.lastByUnit = data.lastByUnit
	end
	S.sizeInPresets = data.sizeInPresets == true
	S.keysOpen = data.keysOpen == true
	S.flat = data.flat == true
	S.canvas = data.canvas == true
	-- built when opened
	S.fold.looks = true
	S.fold.pivot = true
end
