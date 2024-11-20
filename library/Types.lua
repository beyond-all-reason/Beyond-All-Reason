---@meta

--------------------------------------------------------------------------------
-- Vectors
--------------------------------------------------------------------------------

---Cartesian triple (XYZ)
---
---@class xyz
---@field x number
---@field y number
---@field z number

---@alias float3 xyz

--------------------------------------------------------------------------------
-- Color
--------------------------------------------------------------------------------

---Color triple (RGB)
---
---@class rgb
---@field r number
---@field g number
---@field b number

---Color quadruple (RGBA)
---
---@class rgba
---@field r number
---@field g number
---@field b number
---@field a number

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

---@alias CameraMode
---| 0 # fps
---| 1 # ta
---| 2 # spring
---| 3 # rot
---| 4 # free
---| 5 # ov
---| 6 # dummy

---Parameters for camera state
---
---@class CameraState
---
---Highly dependent on the type of the current camera controller
---@field name "ta"|"spring"|"rot"|"ov"|"free"|"fps"|"dummy"
---@field mode CameraMode The camera mode
---@field fov number?
---@field px number? Position X of the ground point in screen center
---@field py number? Position Y of the ground point in screen center
---@field pz number? Position Z of the ground point in screen center
---@field dx number? Camera direction vector X
---@field dy number? Camera direction vector Y
---@field dz number? Camera direction vector Z
---@field rx number? Camera rotation angle on X axis (spring)
---@field ry number? Camera rotation angle on Y axis (spring)
---@field rz number? Camera rotation angle on Z axis (spring)
---@field angle number? Camera rotation angle on X axis (aka tilt/pitch) (ta)
---@field flipped number? -1 for when south is down, 1 for when north is down (ta)
---@field dist number? Camera distance from the ground (spring)
---@field height number? Camera distance from the ground (ta)
---@field oldHeight number? Camera distance from the ground, cannot be changed (rot)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

---Parameters for command options
---
---@class CommandOptions
---@field coded integer
---@field alt boolean
---@field ctrl boolean
---@field shift boolean
---@field right boolean
---@field meta boolean
---@field internal boolean

---Used when assigning multiple commands at once
---
---@class Command
---@field cmdID integer
---@field params number[]
---@field options CommandOptions

---Command Description
---
---Contains data about a command.
---
---@class CommandDescription
---@field id integer?
---@field type integer?
---@field name string?
---@field action string?
---@field tooltip string?
---@field texture string?
---@field cursor string?
---@field queueing boolean?
---@field hidden boolean?
---@field disabled boolean?
---@field showUnique boolean?
---@field onlyTexture boolean?
---@field params table<string, string>?

--------------------------------------------------------------------------------
-- Resources
--------------------------------------------------------------------------------

---@alias ResourceName "metal"|"energy"|"m"|"e"

---@alias StorageName "metalStorage"|"energyStorage"|"ms"|"es"

---@alias ResourceUsage table<ResourceName, number>