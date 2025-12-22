-- It would be better if LuaSyncedCtrl published this interface for us, until then we cope
---@class ISpring
---@field CMD table Spring command constants
---@field GetModOptions fun(): table
---@field GetGameFrame fun(): number, any
---@field IsCheatingEnabled fun(): boolean
---@field Log fun(tag: string, level: string, msg: string)
---@field GetTeamRulesParam fun(teamID: number, key: string): any
---@field SetTeamRulesParam fun(teamID: number, key: string, value: any, losAccess: boolean?)
---@field GetTeamResources fun(teamID: number, resourceType: string): number?, number?, number?, number?, number?, number?, number?, number?, number?
---@field GetPlayerInfo fun(playerID: number, getUnread: boolean?): string, number, boolean, number
---@field GetTeamList fun(): number[]
---@field GetPlayerList fun(): number[]
---@field GetPlayerListUnpacked fun(): TeamData[]?
---@field GetPlayerIdsList fun(): number[]?
---@field AreTeamsAllied fun(team1ID: number, team2ID: number): boolean
---@field GetTeamUnits fun(teamID: number): number[]?
---@field GetUnitTeam fun(unitID: number): number?
---@field GetUnitDefID fun(unitID: number): number?
---@field GetUnitDefs fun(): table<string, UnitWrapper>
---@field GiveOrderToUnit fun(unitID: number, commandID: number, params: table, options: table)
---@field AddTeamResource fun(teamID: number, resourceType: ResourceName, amount: number) @deprecated Use SetTeamResourceData when game_economy is enabled
---@field ShareTeamResource fun(teamID_src: number, teamID_recv: number, resourceType: ResourceName, amount: number) @deprecated Use ProcessEconomy when game_economy is enabled
---@field GetTeamResourceData fun(teamID: number, resource: ResourceName): ResourceData
---@field SetTeamResourceData fun(teamID: number, data: ResourceData)
---@field SetTeamResource fun(teamID: number, resource: ResourceName, amount: number)
---@field SetTeamShareLevel fun(teamID: number, resource: ResourceName, level: number)
---@field GetGaiaTeamID fun(): number
---@field GetTeamInfo fun(teamID: number, getUnread: boolean?): string, number, boolean, boolean, string, number, table, number, number
---@field GetTeamLuaAI fun(teamID: number): string?
---@field ValidUnitID fun(unitID: number): boolean
---@field TransferUnit fun(unitID: number, newTeamID: number, given: boolean): boolean
---@field GetUnitDefNames fun(): table<string, { id: number }>
---@field SetEconomyController fun(controller: GameEconomyController)
---@field SetUnitTransferController fun(controller: GameUnitTransferController)
---@field GetAuditTimer fun(): number

---@class EconomyTeamResult
---@field teamId number
---@field resourceType ResourceName
---@field current number
---@field sent number
---@field received number

---@class GameEconomyController
---@field ProcessEconomy fun(frame: number, teams: table<number, TeamResourceData>): EconomyTeamResult[]

---@class GameUnitTransferController
---@field AllowUnitTransfer fun(unitID: number, unitDefID: number, fromTeamID: number, toTeamID: number, capture: boolean): boolean
---@field TeamShare fun(srcTeamID: number, dstTeamID: number)

---@class ResourceShareParams
---@field senderTeamID number
---@field targetTeamID number
---@field resourceType string
---@field amount number

---@class UnitWrapper
---@field unitDefId string
---@field unitDef table? -- Populated by SpringBuilder with real unit definition data
---@field [string] any Additional unit definition properties when loaded

---@alias ResourceName "metal"|"m"|"energy"|"e"
---@alias StorageName "metalStorage"|"ms"|"energyStorage"|"es"

---@class ResourceData
---@field resourceType ResourceName resource type identifier
---@field current number current stockpile (clamped to storage)
---@field storage number max storage capacity
---@field pull number requested usage
---@field income number production income
---@field expense number expenditure
---@field shareSlider number share threshold slider (0-1)
---@field excess number resources that overflowed storage this frame (for sharing)

---@class TeamResourceData
---@field allyTeam number
---@field isDead boolean
---@field metal ResourceData
---@field energy ResourceData

---@class TeamData
---@field id number
---@field name string
---@field leader number
---@field isDead boolean
---@field isAI boolean
---@field side string
---@field allyTeam number
