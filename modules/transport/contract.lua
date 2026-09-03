local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class TransportApproachContext where a carrier meets the ground: shared by load and unload
---@field goalY number
---@field height number|nil the passenger's model height
---@field reach number|nil nil for a ground transport
---@field distance number|nil

---@class TransportLoadContext: TransportApproachContext
---@field carrierDef table|nil
---@field passengerDef table|nil
---@field allied boolean|nil
---@field ownTeam boolean|nil the passenger is the carrier's own team's
---@field nano boolean|nil the passenger is a nano turret
---@field passengerSpeed number|nil
---@field carried boolean|nil already aboard some carrier
---@field underConstruction boolean|nil
---@field inAnimation boolean|nil mid load or unload animation (tractor beams)
---@field enemyLoading boolean|nil false when the carrier's ruleset never lifts enemies
---@field seen boolean|nil the carrier's ally team has the passenger in LOS or radar

---@class TransportUnloadContext: TransportApproachContext
---@field nano boolean|nil
---@field groundNormalY number|nil

---@class TransportLoadedSpeedContext
---@field carriesCommander boolean
---@field transportSpeed number elmos per second
---@field dragEnabled boolean the comm_trans_slow rule
---@field framesPerSecond number

---@class TransportLoadStages: PolicyStages<TransportLoadContext, boolean>
---@field Submerged string
---@field WithinReach string
---@field Untransportable string
---@field Carried string
---@field UnderConstruction string
---@field InAnimation string
---@field MovingEnemy string
---@field EnemyLoading string
---@field EnemyImmune string
---@field Unseen string
---@field AlliedNano string
---@field Allowed string

---@type TransportLoadStages
local Load = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	Untransportable = "Untransportable",
	Carried = "Carried",
	UnderConstruction = "UnderConstruction",
	InAnimation = "InAnimation",
	MovingEnemy = "MovingEnemy",
	EnemyLoading = "EnemyLoading",
	EnemyImmune = "EnemyImmune",
	Unseen = "Unseen",
	AlliedNano = "AlliedNano",
	Allowed = "Allowed",
}

---@class TransportUnloadStages: PolicyStages<TransportUnloadContext, boolean>
---@field Submerged string
---@field WithinReach string
---@field NanoOnSlope string
---@field Allowed string

---@type TransportUnloadStages
local Unload = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	NanoOnSlope = "NanoOnSlope",
	Allowed = "Allowed",
}

---@class TransportLoadedSpeedStages: PolicyStages<TransportLoadedSpeedContext, number>
---@field CommanderDrag string

---@type TransportLoadedSpeedStages
local LoadedSpeed = {
	CommanderDrag = "CommanderDrag",
}

---@class TransportPipelines what LoadPolicies("transport") hands back
---@field load AssembledPipeline<TransportLoadContext, boolean>
---@field unload AssembledPipeline<TransportUnloadContext, boolean>
---@field loaded_speed AssembledPipeline<TransportLoadedSpeedContext, number>

---@class TransportContract
---@field Load TransportLoadStages
---@field Unload TransportUnloadStages
---@field LoadedSpeed TransportLoadedSpeedStages

return PolicyBuilder.Contract("transport", {
	Load = PolicyBuilder.Single(Load),
	Unload = PolicyBuilder.Single(Unload),
	LoadedSpeed = PolicyBuilder.Product(LoadedSpeed),
})
