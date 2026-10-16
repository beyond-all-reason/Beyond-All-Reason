local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

-- The fields of one PlayCameraSequence keyframe. Distances in elmos, angles in degrees, times in seconds.
return {
	Settings = {
		-- where the camera is: a position, or riding along with a unit at an offset
		position = Types.Position,
		unitName = Types.UnitName,
		offsetX = Types.Number,
		offsetY = Types.Number,
		offsetZ = Types.Number,
		relativeToHeading = Types.Boolean, -- the offset turns with the unit
		-- what it looks at; or pitch (0 = level, 90 = straight down) and yaw (compass bearing)
		lookAtPosition = Types.Position,
		lookAtUnitName = Types.UnitName,
		pitch = Types.Number,
		yaw = Types.Number,
		roll = Types.Number,
		fov = Types.Number, -- vertical
		duration = Types.Quantity, -- to get here, 0 = cut
		hold = Types.Quantity, -- to stay here
		easing = Types.CameraEasing,
		path = Types.CameraPath, -- of the camera and of the point it looks at
	},
	ExactlyOneOf = { "position", "unitName" },
	AtMostOneOf = { "lookAtPosition", "lookAtUnitName" },
}
