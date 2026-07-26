local M = {}

M.ModeCategories = {
	Game = "game",
}

M.Modes = {
	Standard = "standard",
}

---@alias DeathModeKey "neverend"|"com"|"territorial_domination"|"builders"|"killall"|"own_com"
---@class DeathModeFields
---@field NeverEnd "neverend" the game runs until everyone leaves
---@field Commander "com" a team loses when its last commander dies
---@field TerritorialDomination "territorial_domination" rounds of territory control decide it
---@field Builders "builders" a team loses when it can no longer build
---@field KillAll "killall" a team loses when every unit is dead
---@field OwnCommander "own_com" a player loses when their own commander dies

---@type DeathModeFields
M.DeathMode = {
	NeverEnd = "neverend",
	Commander = "com",
	TerritorialDomination = "territorial_domination",
	Builders = "builders",
	KillAll = "killall",
	OwnCommander = "own_com",
}

---@alias DraftModeKey "disabled"|"random"|"captain"|"skill"|"fair"
---@class DraftModeFields
---@field Disabled "disabled"
---@field Random "random"
---@field Captain "captain"
---@field Skill "skill"
---@field Fair "fair"

---@type DraftModeFields
M.DraftMode = {
	Disabled = "disabled",
	Random = "random",
	Captain = "captain",
	Skill = "skill",
	Fair = "fair",
}

---@alias AnonymousModeKey "disabled"|"global"|"local"|"disco"|"allred"
---@class AnonymousModeFields
---@field Disabled "disabled"
---@field Global "global"
---@field Local "local"
---@field Disco "disco"
---@field AllRed "allred"

---@type AnonymousModeFields
M.AnonymousMode = {
	Disabled = "disabled",
	Global = "global",
	Local = "local",
	Disco = "disco",
	AllRed = "allred",
}

return M
