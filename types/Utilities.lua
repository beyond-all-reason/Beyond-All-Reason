---@meta

---@class UtilitiesGametype
---@field IsSinglePlayer fun(): boolean
---@field Is1v1 fun(): boolean
---@field IsTeams fun(): boolean
---@field IsBigTeams fun(): boolean
---@field IsSmallTeams fun(): boolean
---@field IsRaptors fun(): boolean
---@field IsScavengers fun(): boolean
---@field IsPvE fun(): boolean
---@field IsCoop fun(): boolean
---@field IsFFA fun(): boolean
---@field IsSandbox fun(): boolean
---@field GetCurrentHolidays fun(): table<string, boolean>?

---@class UtilitiesColor
---@field ToString fun(r: number, g: number, b: number): string
---@field ToStringEx fun(r: number, g: number, b: number, a: number, oR: number, oG: number, oB: number, oA: number): string
---@field ToIntArray fun(r: number, g: number, b: number): number, number, number
---@field ColorIsDark fun(r: number, g: number, b: number): boolean
---@field ConvertColor fun(r: number, g: number, b: number): string

---@class UtilitiesTGA
---@field width number
---@field height number
---@field channels number
---@field pixels number[]

---@class Utilities
---@field [string] any
---@field LoadTGA fun(filename: string): UtilitiesTGA
---@field SaveTGA fun(filename: string, tga: UtilitiesTGA): boolean
---@field NewTGA fun(width: number, height: number, channels: number): UtilitiesTGA
---@field MakeRealTable fun(syncedTable: any): table
---@field GetAllyTeamCount fun(): number
---@field GetAllyTeamList fun(): integer[]
---@field GetPlayerCount fun(): integer?
---@field Gametype UtilitiesGametype
---@field GetScavAllyTeamID fun(): integer?
---@field GetRaptorTeamID fun(): integer?
---@field GetScavTeamID fun(): integer?
---@field GetRaptorAllyTeamID fun(): integer?
---@field IsDevMode fun(): boolean
---@field ShowDevUI fun(): boolean
---@field IsDevModeCached fun(): boolean
---@field CustomKeyToUsefulTable fun(customParams: table): table
---@field SafeLuaTableParser fun(str: string): table?, string?
---@field Color UtilitiesColor
---@field ConvertColor fun(r: number, g: number, b: number): string
---@field GetAccountID fun(playerID: number): number

---@type Utilities
---@diagnostic disable-next-line: missing-fields
Utilities = {}
