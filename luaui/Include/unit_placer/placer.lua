-- The world half of the shared unit placer (refactor plan, Phase U1): arming, the drag, the
-- keys, and what is drawn while placing. The mission editor and the terraform brush each own
-- one; neither knows about the other.
--
-- THE GAME ALREADY DOES THIS (PtaQ, 2026-09-27: "grid and line drawing are established and
-- optimised actions in game"): BAR's Blueprint API (luaui/Widgets/api_blueprint.lua, on by
-- default, what the player's own blueprint tool uses) lays out SINGLE / LINE / SNAPLINE /
-- GRID / BOX exactly as the engine's build drag does, and draws the ghosts and the footprint
-- outlines itself -- instanced, GPU-drawn outlines tinted red where the ground refuses, cached
-- per position so a growing drag only adds and removes what changed. So the placer hands it a
-- BLUEPRINT (one unit, or a group for a paste) and draws nothing of its own. What it keeps:
-- the gestures, the keys, and turning the API's positions into placements the same way the
-- API's own createBuildings does (rotate, offset, Pos2BuildPos).
--
-- Without the Blueprint API (a user who turned it off) it falls back to unit_placer/layout.lua
-- for the positions and draws nothing but still places.
--
-- It hands back PLACEMENTS: { unitDefName, team, facing, spots } or, for a group,
-- { group = true, team, units = { { unitDefName, x, z, facing, index } } }.
--
-- KEYS while armed: R turns clockwise a quarter (Shift+R back) -- a single unit, or a whole
-- group; Tab cycles the shape. Right-click cancels.
--
-- The Blueprint API is ONE shared preview. The player's blueprint tool only touches it while
-- its own mode is on, and the placer clears it on disarm. Builders are set to none, which
-- turns off the API's faction substitution: a Cortex builder selected in the world must not
-- turn an Armada placement into Cortex. The one cost is the API's colour for "not buildable by
-- the selected builders" (yellow) on every free footprint; red still means the ground refuses.

local Layout = VFS.Include("luaui/Include/unit_placer/layout.lua")

local Placer = {}
Placer.Layout = Layout

local KEY_R, KEY_TAB = 114, 9

--- Positions the preview is handed at most. The Blueprint API pays per NEW position (a ghost,
--- an outline, a TestBuildOrder), and a drag of small units over a big area adds hundreds a
--- step; past this the preview shows the first ones and the placement still covers the drag.
Placer.MAX_PREVIEW = 400

local function api()
	local bp = WG.api_blueprint
	return (
		bp
		and bp.calculateBuildPositions
		and bp.setActiveBlueprint
		and bp.setBlueprintPositions
		and bp.rotateBlueprint
	)
			and bp
		or nil
end

---@param options table { owner: string, onPlaced: fun(result), onCancelled: fun()|nil, sticky: boolean|nil }
function Placer.new(options)
	options = options or {}
	local self = {}
	local spec ---@type table? nil while disarmed
	local drag ---@type table? { x1, z1, x2, z2 } while the button is down
	local pointer ---@type table? { x, z } the ground under the pointer, while armed
	local blueprint ---@type table? what the Blueprint API is shown: { units = { ... }, facing, spacing }
	local blueprintShown = false
	local positionsSignature
	local lastPositions = {}

	--- The blueprint for a spec: one unit at the origin, or the group at its offsets.
	local function blueprintFor(s)
		if s.group then
			local units = {}
			for index, unit in ipairs(s.group) do
				units[index] = {
					blueprintUnitID = index,
					unitDefID = unit.unitDefID,
					position = { unit.dx, 0, unit.dz },
					facing = unit.facing,
				}
			end
			return { units = units, facing = (s.turns or 0) % 4, spacing = s.spacing or 0 }
		end
		return {
			units = { { blueprintUnitID = 1, unitDefID = s.unitDefID, position = { 0, 0, 0 }, facing = 0 } },
			facing = s.facing or 0,
			spacing = s.spacing or 0,
		}
	end

	local function showBlueprint()
		local bp = api()
		if not (bp and spec) then
			return
		end
		blueprint = blueprintFor(spec)
		if bp.setActiveBuilders then
			bp.setActiveBuilders({})
		end
		bp.setActiveBlueprint(blueprint)
		blueprintShown = true
		positionsSignature = nil
	end

	local function hideBlueprint()
		local bp = api()
		if bp and blueprintShown then
			bp.setActiveBlueprint(nil)
			bp.setBlueprintPositions({})
		end
		blueprintShown = false
		blueprint = nil
		positionsSignature = nil
		lastPositions = {}
	end

	--- The Blueprint API's anchor positions for a drag (or the point under the pointer). A group
	--- is dropped by a click; with a shape other than SINGLE, a drag lays copies out in it.
	local function anchorPositions(s, bpTable, x1, z1, x2, z2, dragging)
		local bp = api()
		if not (bp and bpTable) then
			return nil
		end
		local mode = s.mode or "SINGLE"
		if s.group and not dragging then
			mode = "SINGLE"
		end
		local ok, positions
		if mode == "SINGLE" then
			ok, positions = pcall(bp.calculateBuildPositions, bpTable, "SINGLE", { x2 or x1, 0, z2 or z1 })
		else
			ok, positions = pcall(
				bp.calculateBuildPositions,
				bpTable,
				mode,
				{ x1, 0, z1 },
				{ x2 or x1, 0, z2 or z1 },
				bpTable.spacing or 0
			)
		end
		return ok and positions or nil
	end

	--- Placements from anchor positions: every unit of the blueprint at every position, turned
	--- and snapped exactly as the API's own createBuildings turns and snaps them.
	local function expand(s, bpTable, positions)
		local bp = api()
		local spots = {}
		for _, pos in ipairs(positions or {}) do
			local turned = bp.rotateBlueprint(bpTable, (bpTable.facing or 0) + (pos[4] or 0))
			for index, unit in ipairs(turned.units) do
				local x, z = pos[1] + (unit.position[1] or 0), pos[3] + (unit.position[3] or 0)
				local sx, _, sz = Spring.Pos2BuildPos(unit.unitDefID, x, Spring.GetGroundHeight(x, z), z, unit.facing)
				local def = UnitDefs[unit.unitDefID]
				spots[#spots + 1] = {
					x = math.floor((sx or x) + 0.5),
					z = math.floor((sz or z) + 0.5),
					facing = unit.facing % 4,
					index = s.group and index or nil,
					unitDefID = unit.unitDefID,
					unitDefName = def and def.name or nil,
				}
			end
		end
		return spots
	end

	--- The fallback, without the Blueprint API: the same engine rules, from layout.lua.
	local function fallbackSpots(s, x1, z1, x2, z2)
		if s.group then
			local spots =
				Layout.groupPositions(s.group, x2 or x1, z2 or z1, s.turns, true, Game.mapSizeX, Game.mapSizeZ)
			for _, spot in ipairs(spots) do
				local unit = s.group[spot.index]
				spot.unitDefID, spot.unitDefName = unit.unitDefID, unit.unitDefName
			end
			return spots
		end
		local unitDef = UnitDefs[s.unitDefID]
		if not unitDef then
			return nil
		end
		return Layout.positions({
			xsize = unitDef.xsize,
			zsize = unitDef.zsize,
			mode = s.mode,
			facing = s.facing,
			spacing = s.spacing,
			mapX = Game.mapSizeX,
			mapZ = Game.mapSizeZ,
		}, x1, z1, x2, z2)
	end

	--- The spots for a drag (or the single spot under the pointer), for the armed spec or for
	--- one handed in. Pure with respect to the shared preview: it never changes what is shown.
	---@return table|nil spots
	function self.preview(x1, z1, x2, z2, override, dragging)
		local s = override or spec
		if not s then
			return nil
		end
		if s.group == nil and not s.unitDefID then
			return nil
		end
		if not api() then
			return fallbackSpots(s, x1, z1, x2, z2)
		end
		local bpTable = (s == spec and blueprint) or blueprintFor(s)
		if dragging == nil then
			dragging = override ~= nil or drag ~= nil
		end
		return expand(s, bpTable, anchorPositions(s, bpTable, x1, z1, x2, z2, dragging) or {})
	end

	--- Arm with a unit type and how to lay it out. Refuses, with a reason, what it cannot
	--- place rather than placing something else.
	---@param s table { unitDefName, team, mode, spacing, facing }
	---@return boolean armed, string|nil why
	function self.arm(s)
		if type(s) ~= "table" then
			return false, "arm expects a table"
		end
		local unitDef = UnitDefNames[tostring(s.unitDefName)]
		if not unitDef then
			return false, "no unit type called '" .. tostring(s.unitDefName) .. "'"
		end
		local mode = tostring(s.mode or "GRID"):upper()
		local known = false
		for _, candidate in ipairs(Layout.MODES) do
			known = known or candidate == mode
		end
		if not known then
			return false, "no formation called '" .. mode .. "'"
		end
		drag = nil
		spec = {
			unitDefID = unitDef.id,
			unitDefName = unitDef.name,
			mode = mode,
			spacing = math.max(0, math.floor(tonumber(s.spacing) or 0)),
			facing = math.floor(tonumber(s.facing) or 0) % 4,
			team = math.max(0, math.floor(tonumber(s.team) or 0)),
		}
		showBlueprint()
		return true
	end

	--- Arm with a GROUP: units at offsets from a centre, as a copy or a blueprint holds them.
	---@param units table { { unitDefName, dx, dz, facing }, ... }
	---@param s table|nil { team }
	---@return boolean armed, string|nil why
	function self.armGroup(units, s)
		s = s or {}
		local group = {}
		for index, unit in ipairs(units or {}) do
			local unitDef = UnitDefNames[tostring(unit.unitDefName)]
			if not unitDef then
				return false, "no unit type called '" .. tostring(unit.unitDefName) .. "' (unit " .. index .. ")"
			end
			group[#group + 1] = {
				unitDefID = unitDef.id,
				unitDefName = unitDef.name,
				xsize = unitDef.xsize,
				zsize = unitDef.zsize,
				dx = tonumber(unit.dx) or 0,
				dz = tonumber(unit.dz) or 0,
				facing = math.floor(tonumber(unit.facing) or 0) % 4,
			}
		end
		if #group == 0 then
			return false, "nothing to place"
		end
		drag = nil
		spec = {
			group = group,
			turns = 0,
			team = math.max(0, math.floor(tonumber(s.team) or 0)),
			facing = 0,
			mode = "SINGLE",
			spacing = 0,
		}
		showBlueprint()
		return true
	end

	function self.disarm()
		spec, drag, pointer = nil, nil, nil
		hideBlueprint()
	end

	function self.armed()
		return spec ~= nil
	end

	--- The armed spec, read-only in spirit: facing, turns and mode as the keys left them.
	function self.spec()
		return spec
	end

	---@return boolean consumed
	function self.mousePress(x, z, button)
		if not spec then
			return false
		end
		if button == 3 then
			self.disarm()
			if options.onCancelled then
				options.onCancelled()
			end
			return true
		end
		if button == 1 and x then
			drag = { x1 = x, z1 = z, x2 = x, z2 = z }
			return true
		end
		return false
	end

	---@return boolean consumed
	function self.mouseMove(x, z)
		if spec and x then
			pointer = { x = x, z = z }
		end
		if drag and x then
			drag.x2, drag.z2 = x, z
			return true
		end
		return false
	end

	--- Finish the drag and hand the placement over. Disarmed BEFORE the owner is told (unless
	--- sticky), so a handler that re-renders cannot find the tool still holding the mouse.
	---@return boolean consumed
	function self.mouseRelease()
		if not (spec and drag) then
			return false
		end
		local finished, s = drag, spec
		local spots = self.preview(finished.x1, finished.z1, finished.x2, finished.z2, nil, true) or {}
		drag = nil
		if not options.sticky then
			self.disarm()
		else
			positionsSignature = nil
		end
		if options.onPlaced then
			if s.group then
				options.onPlaced({ group = true, team = s.team, units = spots })
			else
				options.onPlaced({ unitDefName = s.unitDefName, team = s.team, facing = s.facing, spots = spots })
			end
		end
		return true
	end

	---@return boolean consumed
	function self.keyPress(key, mods)
		if not spec then
			return false
		end
		mods = mods or {}
		if key == KEY_R and not mods.ctrl then
			if spec.group then
				spec.turns = (spec.turns + (mods.shift and 3 or 1)) % 4
			else
				spec.facing = (spec.facing + (mods.shift and 3 or 1)) % 4
			end
			showBlueprint()
			return true
		end
		if key == KEY_TAB then
			spec.mode = Layout.nextMode(spec.mode)
			positionsSignature = nil
			return true
		end
		return false
	end

	--- Keep the Blueprint API's preview in step with what a release would place. The API is
	--- told only when the positions change; it caches per position itself.
	function self.update(pointerX, pointerZ)
		if not spec then
			return
		end
		if pointerX and not drag then
			pointer = { x = pointerX, z = pointerZ }
		end
		local bp = api()
		if not (bp and blueprint) then
			return
		end
		local x1, z1, x2, z2
		if drag then
			x1, z1, x2, z2 = drag.x1, drag.z1, drag.x2, drag.z2
		elseif pointer then
			x1, z1, x2, z2 = pointer.x, pointer.z, pointer.x, pointer.z
		else
			return
		end
		local positions = anchorPositions(spec, blueprint, x1, z1, x2, z2, drag ~= nil) or {}
		local parts = { spec.mode, #positions }
		for _, pos in ipairs(positions) do
			parts[#parts + 1] = math.floor(pos[1]) .. ":" .. math.floor(pos[3]) .. ":" .. tostring(pos[4] or 0)
		end
		local signature = table.concat(parts, "|")
		if signature == positionsSignature then
			return
		end
		positionsSignature = signature
		if #positions > Placer.MAX_PREVIEW then
			local shown = {}
			for index = 1, Placer.MAX_PREVIEW do
				shown[index] = positions[index]
			end
			positions = shown
		end
		lastPositions = positions
		bp.setBlueprintPositions(positions)
	end

	--- The Blueprint API draws the preview (ghosts and outlines) in its own DrawWorldPreUnit;
	--- nothing to do here. Kept so owners need not know which way it is drawn.
	function self.drawWorld() end

	--- How many units the preview shows (for the harness).
	function self.ghostCount()
		if not (spec and blueprint) then
			return 0
		end
		return #lastPositions * #blueprint.units
	end

	function self.shutdown()
		self.disarm()
	end

	return self
end

return Placer
