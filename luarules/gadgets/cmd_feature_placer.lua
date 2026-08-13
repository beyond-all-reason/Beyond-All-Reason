function gadget:GetInfo()
	return {
		name = "Feature Placer",
		desc = "Synced gadget for placing, removing, and managing map features via brush tool",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:RecvFromSynced(name, a, b)
		if name == "FeaturePlacerHistory" then
			if Script.LuaUI("terraform_feature_history") then
				Script.LuaUI.terraform_feature_history(a, b)
			end
		elseif name == "feature_save_begin" then
			if Script.LuaUI("terraform_feature_save_begin") then
				Script.LuaUI.terraform_feature_save_begin(a)
			end
		elseif name == "feature_save_data" then
			if Script.LuaUI("terraform_feature_save_data") then
				Script.LuaUI.terraform_feature_save_data(a)
			end
		elseif name == "feature_save_end" then
			if Script.LuaUI("terraform_feature_save_end") then
				Script.LuaUI.terraform_feature_save_end(a)
			end
		end
	end
	return
end

----------------------------------------------------------------
-- Constants & Headers
----------------------------------------------------------------
-- The widget generates brush layouts now (common/feature_scatter.lua) and ships
-- the resulting concrete placements, so what it previewed is exactly what gets
-- created. $feature_scatter$ and $feature_point$, which asked this gadget to
-- roll its own positions, are gone.
local PLACELIST_HEADER = "$feature_place_list$"
local TRANSFORM_HEADER = "$feature_transform$"
local REMOVEIDS_HEADER = "$feature_remove_ids$"
local REMOVE_HEADER = "$feature_remove$"
local UNDO_HEADER = "$feature_undo$"
local REDO_HEADER = "$feature_redo$"
local SAVE_HEADER = "$feature_save$"
local LOAD_HEADER = "$feature_load$"
local CLEARALL_HEADER = "$feature_clearall$"

local MAX_UNDO = 100

-- A feature within this of the ground counts as sitting on it, so its y is left
-- out of save files and untouched maps keep byte-identical output. Tilt is not
-- an angle threshold; see isRestingOrientation.
local LIFT_EPSILON = 0.5

----------------------------------------------------------------
-- Localize
----------------------------------------------------------------
local max = math.max
local min = math.min
local floor = math.floor
local cos = math.cos
local sin = math.sin
local abs = math.abs
local random = math.random
local pi = math.pi

local SendToUnsynced = SendToUnsynced
local CreateFeature = Spring.CreateFeature
local DestroyFeature = Spring.DestroyFeature
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundNormal = Spring.GetGroundNormal
local GetAllFeatures = Spring.GetAllFeatures
local GetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureDefID = Spring.GetFeatureDefID
local GetFeatureHeading = Spring.GetFeatureHeading
local ValidFeatureID = Spring.ValidFeatureID
local GetGaiaTeamID = Spring.GetGaiaTeamID
local SetFeatureRotation = Spring.SetFeatureRotation
local GetFeatureRotation = Spring.GetFeatureRotation
local SetFeaturePosition = Spring.SetFeaturePosition
local SetFeatureMoveCtrl = Spring.SetFeatureMoveCtrl
local GetGameFrame = Spring.GetGameFrame

-- Same containment module the widget draws its brush outline from, so removal
-- matches the shape the user sees. The copy that used to live here was
-- apothem-based and disagreed with the outline on hexagons and octagons.
local BrushShapes = VFS.Include("common/brush_shapes.lua")
local isInsideShape = BrushShapes.isInside

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local undoStack = {}
local redoStack = {}
local gaiaTeamID

----------------------------------------------------------------
-- Wobble animation
----------------------------------------------------------------
local wobbleQueue = {}
local WOBBLE_DURATION = 22 -- frames (~0.73s at 30fps)
local WOBBLE_AMPLITUDE = 8 -- degrees peak tilt
local WOBBLE_FREQ = 0.6 -- radians per frame
local WOBBLE_RAMP = 3 -- frames to ramp in

-- GameFrame is registered only while wobble animations run; otherwise every
-- match paid an empty pairs() walk every sim frame.
local wobbleActive = false

-- Captures the feature's full resting orientation, not just its yaw. The wobble
-- used to snap pitch and roll to zero when it finished, which silently flattened
-- anything placed or loaded with a tilt.
local function addWobble(featureID)
	if featureID then
		local pitch, yaw, roll = GetFeatureRotation(featureID)
		wobbleQueue[featureID] = {
			start = GetGameFrame(),
			axis = random() * 2 * pi,
			pitch = pitch or 0,
			yaw = yaw or 0,
			roll = roll or 0,
		}
		if not wobbleActive then
			wobbleActive = true
			gadgetHandler:UpdateCallIn("GameFrame")
		end
	end
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function sendHistoryUpdate()
	SendToUnsynced("FeaturePlacerHistory", #undoStack, #redoStack)
end

local function pushUndo(entry)
	redoStack = {}
	undoStack[#undoStack + 1] = entry
	while #undoStack > MAX_UNDO do
		table.remove(undoStack, 1)
	end
	sendHistoryUpdate()
end

----------------------------------------------------------------
-- Feature placement
----------------------------------------------------------------
-- Layout generation moved to common/feature_scatter.lua on the widget side, so
-- the brush preview and the features that actually appear are the same array
-- rather than two implementations of the same algorithm. This gadget now only
-- realises a list it is handed.

-- Features above the ground are still in the physics update queue right after
-- creation and would fall. Zeroing the movement masks (leaving moveCtrl itself
-- disabled) makes every Move a no-op, so the feature settles out of the queue at
-- the height it was given. Deliberately not unlocked again if it later returns
-- to the ground: this is authored scenery, and staying put is what the author
-- asked for.
local function lockFeatureInPlace(featureID)
	if SetFeatureMoveCtrl then
		SetFeatureMoveCtrl(featureID, false, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	end
end

local function readTransform(featureID)
	local x, y, z = GetFeaturePosition(featureID)
	if not x then
		return nil
	end
	local pitch, yaw, roll = GetFeatureRotation(featureID)
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

local function applyTransform(featureID, t)
	if not ValidFeatureID(featureID) then
		return false
	end

	-- A transform supersedes any placement wobble still running on this feature.
	-- Left in the queue, the wobble would keep writing its own rotation and then
	-- restore the pre-transform orientation when it finished.
	wobbleQueue[featureID] = nil

	if t.y > GetGroundHeight(t.x, t.z) + LIFT_EPSILON then
		lockFeatureInPlace(featureID)
	end

	SetFeaturePosition(featureID, t.x, t.y, t.z)
	SetFeatureRotation(featureID, t.pitch, t.yaw, t.roll)
	return true
end

-- Wire format, entries separated by "|":
--   defName x z heading [pitch roll y]
-- The optional tail is omitted for the flat-on-ground case, which is almost
-- every feature, keeping messages small.
local function parsePlacement(entry)
	local parts = {}
	for word in entry:gmatch("%S+") do
		parts[#parts + 1] = word
	end

	local defName = parts[1]
	local x = tonumber(parts[2])
	local z = tonumber(parts[3])
	if not (defName and x and z) or not FeatureDefNames[defName] then
		return nil
	end

	x = max(0, min(Game.mapSizeX, x))
	z = max(0, min(Game.mapSizeZ, z))

	return {
		defName = defName,
		x = x,
		z = z,
		heading = (tonumber(parts[4]) or 0) % 65536,
		pitch = tonumber(parts[5]) or 0,
		roll = tonumber(parts[6]) or 0,
		y = tonumber(parts[7]) or GetGroundHeight(x, z),
	}
end

local function createFromPlacement(p)
	local id = CreateFeature(p.defName, p.x, p.y, p.z, p.heading, gaiaTeamID)
	if not id then
		return nil
	end

	if p.y > GetGroundHeight(p.x, p.z) + LIFT_EPSILON then
		lockFeatureInPlace(id)
		SetFeaturePosition(id, p.x, p.y, p.z)
	end

	-- CreateFeature only takes a heading, so any tilt has to be applied after --
	-- and before addWobble, which snapshots the resting orientation it must
	-- return to.
	if p.pitch ~= 0 or p.roll ~= 0 then
		local _, yaw = GetFeatureRotation(id)
		SetFeatureRotation(id, p.pitch, yaw or 0, p.roll)
	end

	return id
end

----------------------------------------------------------------
-- Undo strokes
----------------------------------------------------------------
-- One user action is one undo step, even though it can arrive as several
-- messages -- a 500-feature stamp is 13 batches, and a gizmo drag over a big
-- selection several more. Messages carry a stroke id; consecutive messages
-- sharing one append to the same entry. Same idea as the terraform brush
-- merging a paint stroke.
--
-- Only one stroke is ever open, because a place and a transform cannot belong to
-- the same user action. The entry is pushed lazily on the first real change, so
-- a message that turns out to be a no-op neither leaves an empty undo step
-- behind nor clears the redo stack.
local stroke = { id = nil, kind = nil, entry = nil, index = nil, pushed = false }

local function closeStroke()
	stroke.id = nil
	stroke.kind = nil
	stroke.entry = nil
	stroke.index = nil
	stroke.pushed = false
end

local function openStroke(strokeID, kind, action)
	if stroke.id == strokeID and stroke.kind == kind then
		return stroke.entry
	end
	closeStroke()
	stroke.id = strokeID
	stroke.kind = kind
	stroke.entry = { action = action, features = {} }
	stroke.index = {}
	stroke.pushed = false
	return stroke.entry
end

local function commitStroke()
	if not stroke.pushed and stroke.entry then
		pushUndo(stroke.entry)
		stroke.pushed = true
	end
end

-- Payload is "strokeId|entry|entry|...". An empty stroke id means "do not
-- coalesce", giving one entry per message.
local function splitStroke(payload)
	local strokeID = payload:match("^([^|]*)")
	return strokeID, #strokeID + 2
end

local function placeFromList(payload, wobble)
	local strokeID, bodyStart = splitStroke(payload)
	local entry = (strokeID ~= "") and openStroke(strokeID, "place", "place") or nil
	local placed = entry and entry.features or {}

	local count = 0
	for chunk in payload:sub(bodyStart):gmatch("[^|]+") do
		local p = parsePlacement(chunk)
		if p then
			local id = createFromPlacement(p)
			if id then
				p.id = id
				placed[#placed + 1] = p
				count = count + 1
				if wobble then
					addWobble(id)
				end
			end
		end
	end

	if count > 0 then
		if entry then
			commitStroke()
		else
			pushUndo({ action = "place", features = placed })
		end
	end
	return count
end

----------------------------------------------------------------
-- Feature removal
----------------------------------------------------------------
-- Is this feature's orientation just the engine's own resting alignment, or did
-- something actually tilt it?
--
-- This distinction matters because non-upright feature defs are ground-aligned
-- by UpdateDirVectors, so a rock on any real slope reports a non-zero pitch and
-- roll it was never given. Testing `pitch ~= 0` would therefore mark most
-- features on most maps as transformed and write the optional tail for all of
-- them, breaking the promise that an unedited map serialises byte-for-byte.
--
-- Compared as up-vectors rather than euler angles: no gimbal lock, and it is the
-- same quantity UpdateDirVectors actually sets.
local UP_MATCH_EPSILON = 0.02

local function isRestingOrientation(featureID, def, x, z)
	local _, _, _, _, _, _, ux, uy, uz = Spring.GetFeatureDirection(featureID)
	if not ux then
		return true
	end

	local ex, ey, ez = 0, 1, 0
	if not def.upright then
		local nx, ny, nz = GetGroundNormal(x, z)
		if nx then
			ex, ey, ez = nx, ny, nz
		end
	end

	return abs(ux - ex) < UP_MATCH_EPSILON and abs(uy - ey) < UP_MATCH_EPSILON and abs(uz - ez) < UP_MATCH_EPSILON
end

-- Snapshot everything needed to recreate a feature exactly, tilt and lift
-- included, so undoing a removal restores what was there rather than a flat
-- copy of it.
local function captureFeature(featureID)
	local defID = GetFeatureDefID(featureID)
	local def = defID and FeatureDefs[defID]
	if not def then
		return nil
	end

	local x, y, z = GetFeaturePosition(featureID)
	if not x then
		return nil
	end

	local pitch, _, roll = GetFeatureRotation(featureID)
	return {
		defName = def.name,
		x = x,
		y = y,
		z = z,
		heading = GetFeatureHeading(featureID) or 0,
		pitch = pitch or 0,
		roll = roll or 0,
		resting = isRestingOrientation(featureID, def, x, z),
	}
end

local function removeFeatures(centerX, centerZ, radius, shape, angleDeg)
	local extent = radius * 1.42
	local x1 = max(0, centerX - extent)
	local z1 = max(0, centerZ - extent)
	local x2 = min(Game.mapSizeX, centerX + extent)
	local z2 = min(Game.mapSizeZ, centerZ + extent)

	local features = GetFeaturesInRectangle(x1, z1, x2, z2)
	if not features or #features == 0 then
		return
	end

	local removed = {}
	for i = 1, #features do
		local fid = features[i]
		local fx, _, fz = GetFeaturePosition(fid)
		if fx and isInsideShape(fx - centerX, fz - centerZ, radius, shape, angleDeg) then
			local snapshot = captureFeature(fid)
			if snapshot then
				removed[#removed + 1] = snapshot
				DestroyFeature(fid)
			end
		end
	end
	if #removed > 0 then
		pushUndo({ action = "remove", features = removed })
	end
end

local function removeFeatureIDs(payload)
	local removed = {}
	for token in payload:gmatch("[^|]+") do
		local fid = tonumber(token)
		if fid and ValidFeatureID(fid) then
			local snapshot = captureFeature(fid)
			if snapshot then
				removed[#removed + 1] = snapshot
				DestroyFeature(fid)
			end
		end
	end
	if #removed > 0 then
		pushUndo({ action = "remove", features = removed })
	end
	return #removed
end

----------------------------------------------------------------
-- Gizmo transforms
----------------------------------------------------------------
local function transformFeatures(payload)
	local strokeID, bodyStart = splitStroke(payload)
	if strokeID == "" then
		return 0
	end

	local entry = openStroke(strokeID, "transform", "transform")
	local index = stroke.index
	local applied = 0

	for chunk in payload:sub(bodyStart):gmatch("[^|]+") do
		local parts = {}
		for word in chunk:gmatch("%S+") do
			parts[#parts + 1] = word
		end

		local fid = tonumber(parts[1])
		local after = {
			x = tonumber(parts[2]),
			y = tonumber(parts[3]),
			z = tonumber(parts[4]),
			pitch = tonumber(parts[5]) or 0,
			yaw = tonumber(parts[6]) or 0,
			roll = tonumber(parts[7]) or 0,
		}

		if fid and after.x and after.y and after.z and ValidFeatureID(fid) then
			local slot = index[fid]
			if not slot then
				-- First time this feature moves in this stroke: its current state
				-- is what undo has to restore to.
				local before = readTransform(fid)
				if before then
					entry.features[#entry.features + 1] = { id = fid, before = before, after = after }
					index[fid] = #entry.features
					commitStroke()
				end
			else
				entry.features[slot].after = after
			end

			if applyTransform(fid, after) then
				applied = applied + 1
			end
		end
	end

	return applied
end

----------------------------------------------------------------
-- Undo / Redo
----------------------------------------------------------------
-- Recreating a feature gives it a NEW id, and it is not only the entry being
-- replayed that stores that id: a "transform" entry deeper in the stack is keyed
-- entirely by live feature ids. Leave those pointing at the destroyed id and
-- undoing a gizmo drag silently does nothing (ValidFeatureID fails), or worse,
-- once the engine's id pool recycles the number, moves an unrelated feature.
--
-- So every recreate publishes an old -> new mapping across both stacks.
local function remapFeatureIDs(mapping)
	local function patch(stack)
		for i = 1, #stack do
			local features = stack[i].features
			for j = 1, #features do
				local newID = mapping[features[j].id]
				if newID then
					features[j].id = newID
				end
			end
		end
	end
	patch(undoStack)
	patch(redoStack)
end

local function recreateInto(features)
	local mapping = nil
	for i = 1, #features do
		local f = features[i]
		local oldID = f.id
		f.id = createFromPlacement(f)
		if oldID and f.id and oldID ~= f.id then
			mapping = mapping or {}
			mapping[oldID] = f.id
		end
	end
	if mapping then
		remapFeatureIDs(mapping)
	end
end

local function destroyAll(features)
	for i = 1, #features do
		local f = features[i]
		if ValidFeatureID(f.id) then
			DestroyFeature(f.id)
		end
	end
end

local function featureUndo()
	if #undoStack == 0 then
		return
	end
	closeStroke()

	local entry = undoStack[#undoStack]
	undoStack[#undoStack] = nil

	if entry.action == "place" then
		destroyAll(entry.features)
	elseif entry.action == "remove" then
		recreateInto(entry.features)
	elseif entry.action == "transform" then
		for i = 1, #entry.features do
			local f = entry.features[i]
			applyTransform(f.id, f.before)
		end
	end

	redoStack[#redoStack + 1] = entry
	sendHistoryUpdate()
end

local function featureRedo()
	if #redoStack == 0 then
		return
	end
	closeStroke()

	local entry = redoStack[#redoStack]
	redoStack[#redoStack] = nil

	if entry.action == "place" then
		recreateInto(entry.features)
	elseif entry.action == "remove" then
		destroyAll(entry.features)
	elseif entry.action == "transform" then
		for i = 1, #entry.features do
			local f = entry.features[i]
			applyTransform(f.id, f.after)
		end
	end

	undoStack[#undoStack + 1] = entry
	sendHistoryUpdate()
end

----------------------------------------------------------------
-- Save: collect all features and send to unsynced
----------------------------------------------------------------
local function exportAllFeatures()
	local allFeatures = GetAllFeatures()
	local data = {}
	for i = 1, #allFeatures do
		local fid = allFeatures[i]
		local snapshot = captureFeature(fid)
		if snapshot then
			local entry = snapshot.defName
				.. " "
				.. floor(snapshot.x)
				.. " "
				.. floor(snapshot.z)
				.. " "
				.. snapshot.heading
			-- Only carry the tilt/lift tail when there is one, so maps that were
			-- never touched by the gizmo serialise exactly as they did before.
			-- "Tilted" means tilted away from the engine's own resting alignment,
			-- not simply non-zero pitch: ground-aligned features on a slope have
			-- plenty of that without anyone having touched them.
			if not snapshot.resting or abs(snapshot.y - GetGroundHeight(snapshot.x, snapshot.z)) > LIFT_EPSILON then
				entry = entry .. string.format(" %.4f %.4f %.1f", snapshot.pitch, snapshot.roll, snapshot.y)
			end
			data[#data + 1] = entry
		end
	end
	-- Send count first, then batches of features
	local count = #data
	SendToUnsynced("feature_save_begin", count)
	local BATCH = 50
	for i = 1, count, BATCH do
		local batch = {}
		for j = i, min(i + BATCH - 1, count) do
			batch[#batch + 1] = data[j]
		end
		SendToUnsynced("feature_save_data", table.concat(batch, "|"))
	end
	SendToUnsynced("feature_save_end", count)
end

----------------------------------------------------------------
-- Load: create features from batch messages
----------------------------------------------------------------
-- Same wire format as $feature_place_list$; the only difference is that loading
-- a saved map should not play the placement wobble on every feature at once.
local function loadFeatureBatch(payload)
	return placeFromList(payload, false)
end

----------------------------------------------------------------
-- Clear all: destroy every feature on map
----------------------------------------------------------------
local function clearAllFeatures()
	local allFeatures = GetAllFeatures()
	local removed = {}
	for i = 1, #allFeatures do
		local fid = allFeatures[i]
		local snapshot = captureFeature(fid)
		if snapshot then
			removed[#removed + 1] = snapshot
			DestroyFeature(fid)
		end
	end
	if #removed > 0 then
		pushUndo({ action = "remove", features = removed })
	end
	Spring.Echo("[Feature Placer] Cleared " .. #removed .. " features")
end

----------------------------------------------------------------
-- Message parsing
----------------------------------------------------------------
function gadget:RecvLuaMsg(msg, playerID)
	-- Undo
	if msg == UNDO_HEADER then
		if not Spring.IsCheatingEnabled() then
			return true
		end
		featureUndo()
		return true
	end

	-- Redo
	if msg == REDO_HEADER then
		if not Spring.IsCheatingEnabled() then
			return true
		end
		featureRedo()
		return true
	end

	-- Placement: an explicit list the widget already previewed
	if msg:sub(1, #PLACELIST_HEADER) == PLACELIST_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		-- No closeStroke() here: the batches of one stamp must coalesce, and
		-- openStroke already closes a stroke of a different id or kind, so a new
		-- placement still cannot share an entry with a gizmo drag.
		placeFromList(msg:sub(#PLACELIST_HEADER + 1), true)
		return true
	end

	-- Gizmo transform
	if msg:sub(1, #TRANSFORM_HEADER) == TRANSFORM_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		transformFeatures(msg:sub(#TRANSFORM_HEADER + 1))
		return true
	end

	-- Remove an explicit selection
	if msg:sub(1, #REMOVEIDS_HEADER) == REMOVEIDS_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		closeStroke()
		removeFeatureIDs(msg:sub(#REMOVEIDS_HEADER + 1))
		return true
	end

	-- Save
	if msg == SAVE_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Save requires /cheat to be enabled")
			return true
		end
		exportAllFeatures()
		return true
	end

	-- Load batch
	if msg:sub(1, #LOAD_HEADER) == LOAD_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		closeStroke()
		loadFeatureBatch(msg:sub(#LOAD_HEADER + 1))
		return true
	end

	-- Clear all
	if msg == CLEARALL_HEADER then
		if not Spring.IsCheatingEnabled() then
			return true
		end
		closeStroke()
		clearAllFeatures()
		return true
	end

	-- Remove
	if msg:sub(1, #REMOVE_HEADER) == REMOVE_HEADER then
		if not Spring.IsCheatingEnabled() then
			Spring.Echo("[Feature Placer] Requires /cheat to be enabled")
			return true
		end
		local payload = msg:sub(#REMOVE_HEADER + 1)
		local parts = {}
		for word in payload:gmatch("%S+") do
			parts[#parts + 1] = word
		end
		local centerX = tonumber(parts[1])
		local centerZ = tonumber(parts[2])
		local radius = tonumber(parts[3])
		local shape = parts[4] or "circle"
		local angleDeg = tonumber(parts[5]) or 0

		if not centerX or not centerZ or not radius then
			return true
		end
		radius = max(8, min(2000, radius))
		closeStroke()
		removeFeatures(centerX, centerZ, radius, shape, angleDeg)
		return true
	end
end

function gadget:Initialize()
	gaiaTeamID = GetGaiaTeamID()
	-- Idle until the first wobble is queued (see addWobble).
	gadgetHandler:RemoveCallIn("GameFrame")
end

function gadget:GameFrame(frame)
	for fid, info in pairs(wobbleQueue) do
		local elapsed = frame - info.start
		if elapsed > WOBBLE_DURATION or not ValidFeatureID(fid) then
			if ValidFeatureID(fid) then
				SetFeatureRotation(fid, info.pitch, info.yaw, info.roll)
			end
			wobbleQueue[fid] = nil
		else
			local t = elapsed / WOBBLE_DURATION
			local ramp = min(1, elapsed / WOBBLE_RAMP)
			local decay = (1 - t) * (1 - t)
			local angleDeg = WOBBLE_AMPLITUDE * sin(elapsed * WOBBLE_FREQ) * decay * ramp
			local angle = angleDeg * pi / 180
			local pitch = info.pitch + angle * cos(info.axis)
			local roll = info.roll + angle * sin(info.axis)
			SetFeatureRotation(fid, pitch, info.yaw, roll)
		end
	end
	if not next(wobbleQueue) then
		wobbleActive = false
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end
