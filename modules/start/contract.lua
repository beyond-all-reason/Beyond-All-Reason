local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract

---@class StartRegion: Region a team's start as drawn in the editor: a single position, or the area the positions lie in
---@field type "start"
---@field team integer start ordinal; start 1 is team 1
---@field name string|nil the area's label

---@class StartArea one ally team's start area, as resolved for the match
---@field allyTeam integer 1-based, in box order
---@field name string|nil the box's label; a compass name assigned by the resolver
---@field anchors { x: number, z: number, strength: number|nil }[] the ring in elmos; strength is set on curved anchors
---@field source string origin: the modoption, the host's override, or the engine

---@class StartPosition one team's start position for the match
---@field allyTeam integer 1-based
---@field teamID integer
---@field x number
---@field z number

---@class StartBoxEntry one ally team's boxes, as resolved by luarules/gadgets/include/startbox_utilities.lua
---@field boxes number[][][] rings of { x, z, strength? } in elmos
---@field startpoints number[][]|nil
---@field nameLong string|nil
---@field nameShort string|nil
---@field wholeMap boolean|nil

---@class StartBoxes the startbox resolver's result for the match
---@field byAllyTeam table<integer, StartBoxEntry>|nil by ally team id, 0-based
---@field source string|nil
---@field explicit boolean true when a modoption set the boxes; false when they are the engine's rects

---@class StartContext the engine and the game's startbox resolver
---@field springRepo Spring
---@field resolveBoxes fun(): StartBoxes injectable for specs

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas string StartArea[] by ally team, in box order; ally teams without a box are absent
---@field Positions string StartPosition[] every team's start position known to the engine, in team order

---@type StartFacts
local Facts = {
	Areas = "areas",
	Positions = "positions",
}

---@class StartRegionsSetStages start's stages on the regions module's set check, for the start type
---@field AreasDisjoint string no two start areas overlap; sharing an edge is allowed

---@type StartRegionsSetStages
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}

---@class StartRegionsNamesStages start's stages on the regions module's naming, for the start type
---@field FromTeam string an unnamed start is named after its team

---@type StartRegionsNamesStages
local RegionsNames = {
	FromTeam = "FromTeam",
}

---@class StartRegionEnv the keys start's region stages read from the caller-supplied env (see RegionSetContext.env)
---@field starts { allyTeam: integer, x: number, z: number }[]|nil the map's start positions, when the caller has them

---@class StartRegionsDescribeStages start's stages on the regions module's description, for regions of any type
---@field NearestStart string the start inside the region, or else the nearest to its centre; adds nothing when env.starts is nil

---@type StartRegionsDescribeStages
local RegionsDescribe = {
	NearestStart = "NearestStart",
}

---@class StartContract
---@field Facts StartFacts
---@field RegionsSet StartRegionsSetStages
---@field RegionsNames StartRegionsNamesStages
---@field RegionsDescribe StartRegionsDescribeStages

return PolicyBuilder.Contract(Modules.Start, {
	Facts = PolicyBuilder.Facts(Facts),
	RegionsSet = PolicyBuilder.Contributes(RegionsContract.CheckSet, RegionsSet),
	RegionsNames = PolicyBuilder.Contributes(RegionsContract.Names, RegionsNames),
	RegionsDescribe = PolicyBuilder.Contributes(RegionsContract.Describe, RegionsDescribe),
})
