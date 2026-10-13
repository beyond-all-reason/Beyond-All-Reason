---
--- One keyframe of a PlayCameraSequence action: where the eye goes, where it looks, and how
--- it gets there. Fields are flat and typed so a mission editor can build a form from this
--- table, and validation.lua checks a keyframe field by field against it.
---
--- Units: elmos, seconds, degrees (pitch 0 = level, 90 = straight down; yaw is a compass
--- bearing, 0 = toward the top of the map; roll; vertical fov).
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

-- Settings is the field -> type table, as in objectives_schema.lua.
return {
	Settings = {
		-- the eye: an absolute position (y defaults to the ground height), or riding along
		-- with a named unit, offset in elmos (x to its right, z to its front with relativeToHeading)
		position = Types.Position,
		unitName = Types.UnitName,
		offsetX = Types.Number,
		offsetY = Types.Number,
		offsetZ = Types.Number,
		relativeToHeading = Types.Boolean,
		-- where it looks: a point, a named unit, or the centroid of several...
		lookAtPosition = Types.Position,
		lookAtUnitName = Types.UnitName,
		lookAtUnitNames = Types.UnitNames,
		-- ...or a fixed direction; neither keeps the previous keyframe's direction
		pitch = Types.Number,
		yaw = Types.Number,
		roll = Types.Number,
		fov = Types.Number,
		-- seconds to reach this keyframe (0 cuts) and to stay on it, and the curve of the move
		duration = Types.Quantity,
		hold = Types.Quantity,
		easing = Types.Easing,
		path = Types.CameraPath,
	},
	-- the eye comes from exactly one of these, and it looks at no more than one thing
	ExactlyOneOf = { "position", "unitName" },
	AtMostOneOf = { "lookAtPosition", "lookAtUnitName", "lookAtUnitNames" },
}
