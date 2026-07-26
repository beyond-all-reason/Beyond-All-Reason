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

-- Engine types (temporary -- will move to recoil-lua-library when eco branch merges)
---@class ResourceData
---@field resourceType ResourceName
---@field current number
---@field storage number
---@field pull number
---@field income number
---@field expense number
---@field shareSlider number
---@field sent number
---@field received number
---@field excess number

---@class TeamResourceData
---@field allyTeam number
---@field isDead boolean
---@field metal ResourceData
---@field energy ResourceData

-- TODO: delete when recoil-lua-library publishes TeamData types
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

--- The engine surface as an injected dependency: modules that take the
--- engine as a parameter (context factories, policy pipelines, spec mocks)
--- annotate it as `Spring`. The submodule declares the GLOBAL, not a named
--- type, so this alias is what makes the annotation resolve; `table` keeps
--- mock injection free of false mismatches.
---@alias Spring table

--- gadget:ResourceExcess payload (RecoilEngine PR #2642): per team, the
--- overflow the engine already deducted this frame — [1] metal, [2] energy.
---@alias ResourceExcesses table<integer, { [1]: number, [2]: number }>
