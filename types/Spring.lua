---@class UnitScriptTable
---@field CallAsUnit fun(unitID: integer, fn: function, ...: any): any
---@field WaitForMove fun(pieceNum: integer, axis: integer)
---@field WaitForTurn fun(pieceNum: integer, axis: integer)
---@field WaitForScale fun(pieceNum: integer)
---@field GetUnitCOBValue fun(unitID: integer, cobVal: integer, ...: any): integer
---@field SetUnitCOBValue fun(unitID: integer, cobVal: integer, param: integer|boolean): nil
---@field Sleep fun(ms: number)
---@field StartThread fun(fn: function, ...: any)
---@field SetSignalMask fun(mask: integer)
---@field Signal fun(mask: integer)
---@field Hide fun(pieceNum: integer)
---@field Show fun(pieceNum: integer)
---@field GetScriptEnv fun(unitID: integer): table
---@field GetLongestReloadTime fun(unitID: integer): number

---@class TeamData
---@field id number
---@field name string
---@field leader number
---@field isDead boolean
---@field isAI boolean
---@field side string
---@field allyTeam number

---@class PlayerData
---@field id number
---@field name string
---@field active boolean
---@field spectator boolean
---@field pingTime number
---@field cpuUsage number
---@field country string
---@field rank number
---@field hasSkirmishAIsInTeam boolean
---@field playerOpts table
---@field desynced boolean

---@class UnitWrapper
---@field unitDefId string
---@field unitDef table?
---@field [string] any

--- BAR extends engine `ObjectRenderingTable` in `luarules/Utilities/unitrendering.lua`.
---@class ObjectRenderingTable
---@field ActivateMaterial fun(objectID: integer, lod: integer)
---@field DeactivateMaterial fun(objectID: integer, lod: integer)

--- Payload of the synced gadget:ResourceExcess(excesses) callin. Fires every frame for
--- every team; excesses[teamID] = { [1]=metalOverflow, [2]=energyOverflow } is the overflow
--- the engine already deducted from the producer this frame. Return true to take ownership
--- (engine skips native buffering into resDelayedShare).
---@alias ResourceExcesses table<number, number[]>

