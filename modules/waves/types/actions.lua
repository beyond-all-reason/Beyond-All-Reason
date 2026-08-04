---@meta actions

---@class (partial) MissionContext
---@field StartWaves fun(request: table) what a pack's Begin composed
---@field StopWaves fun(pack: string)
---@field SetWaveIntensity fun(pack: string, intensity: number)
---@field SurgeWaves fun(pack: string)
---@field WaveStatus fun(pack: string): WaveStatus|nil
---@field SpawnWaveUnits fun(pack: string, defName: UnitDefName, count: integer): boolean
---@field SpawnWaveOffWave fun(pack: string): boolean
---@field SpawnWaveStructures fun(pack: string)
---@field AddWaveAggression fun(pack: string, amount: number)

--- The mission kit derives its authoring surface from these types: alias and class names are load-bearing.

--- An alias, not a bare number: the editor derives its slot names from param types.

---@alias WaveIntensity number

---@class WavePackRef
---@field name string "<module>.<pack>", the running director's name
---@field module string the flavor module that can rebuild the spec
---@field pack string which builder inside it

---@class MissionWavesChain : MissionEffect
---@field Against fun(team: MissionTeam): MissionWavesChain
---@field From fun(fx: number, fz: number): MissionWavesChain
---@field Intensity fun(intensity: WaveIntensity): MissionWavesChain

---@class MissionWavePack : WavePackRef
---@field Begin fun(): MissionWavesChain
---@field Intensify fun(intensity: WaveIntensity): MissionEffect
---@field Surge fun(): MissionEffect
---@field End fun(): MissionEffect
---@field Spawn fun(defName: UnitDefName, count: integer): MissionEffect
---@field OffWave fun(): MissionEffect
---@field Structures fun(): MissionEffect
---@field Aggression fun(amount: number): MissionEffect
---@field AngerAtLeast fun(anger: number): MissionCondition
---@field Spawned fun(count: integer?): MissionCondition
---@field Cleared fun(count: integer?): MissionCondition
---@field BossDefeated fun(count: integer?): MissionCondition
