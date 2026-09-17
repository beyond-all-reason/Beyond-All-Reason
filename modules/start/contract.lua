local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract

---@class StartRegion: Region a team's start as the editor draws it: a position, or the area the positions sit in
---@field type "start"
---@field team integer the start ordinal: start 1 is team 1
---@field name string|nil the area's label

---@class StartArea one ally team's area, as the match resolved it
---@field allyTeam integer 1-based, the order the boxes come in
---@field name string|nil the box's label, the compass name the resolver gives it
---@field anchors { x: number, z: number, strength: number|nil }[] the ring, in elmos; strength marks a curved anchor
---@field source string where it came from: the modoption set, the host's override, or the engine

---@class StartPosition one team's start position, as the match has it
---@field allyTeam integer 1-based
---@field teamID integer
---@field x number
---@field z number

---@class StartBoxEntry one ally team's boxes as luarules/gadgets/include/startbox_utilities.lua resolves them
---@field boxes number[][][] rings of { x, z, strength? } in elmos
---@field startpoints number[][]|nil
---@field nameLong string|nil
---@field nameShort string|nil
---@field wholeMap boolean|nil

---@class StartBoxes what the startbox resolver found for this match
---@field byAllyTeam table<integer, StartBoxEntry>|nil by ally team id, 0-based
---@field source string|nil
---@field explicit boolean a modoption set them; otherwise the engine's rects are the boxes

---@class StartContext what the match knows: the engine, and the game's startbox resolver
---@field springRepo Spring
---@field resolveBoxes fun(): StartBoxes injectable for specs

---@class StartFacts: PolicyFacts<StartContext>
---@field Areas string StartArea[] by ally team, in box order; unboxed ally teams absent
---@field Positions string StartPosition[] every team's start position the engine has, in team order

---@type StartFacts
local Facts = {
	Areas = "areas",
	Positions = "positions",
}

---@class StartRegionsSetStages what start adds to the regions module's set check, for its own type
---@field AreasDisjoint string no two starts' areas share ground; neighbours may touch

---@type StartRegionsSetStages
local RegionsSet = {
	AreasDisjoint = "AreasDisjoint",
}

---@class StartRegionsNamesStages what start adds to the regions module's naming, for its own type
---@field FromTeam string a start that carries no name is called after its team

---@type StartRegionsNamesStages
local RegionsNames = {
	FromTeam = "FromTeam",
}

---@class StartContract
---@field Facts StartFacts
---@field RegionsSet StartRegionsSetStages
---@field RegionsNames StartRegionsNamesStages

return PolicyBuilder.Contract(Modules.Start, {
	Facts = PolicyBuilder.Facts(Facts),
	RegionsSet = PolicyBuilder.Contributes(RegionsContract.CheckSet, RegionsSet),
	RegionsNames = PolicyBuilder.Contributes(RegionsContract.Names, RegionsNames),
})
