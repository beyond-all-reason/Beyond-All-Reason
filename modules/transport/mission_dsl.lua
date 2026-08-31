local Events = VFS.Include("modules/transport/lib/events.lua")
local TransportVerbs = VFS.Include("modules/transport/lib/mission_verbs.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

return {
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Transport = TransportVerbs.MakeTransport(file) } }
	end,
	Events = Events,
	---@param runtime MissionRuntime
	Context = function(runtime)
		local carries = {} ---@type table<string, { loaded: boolean, delivered: boolean }>

		---@param name string
		---@return integer|nil
		local function living(name)
			local unitID = runtime.UnitOf(name)
			if unitID ~= nil and Spring.ValidUnitID(unitID) then
				return unitID
			end
			return nil
		end

		---@param name string
		---@return boolean
		local function carried(name)
			local unitID = living(name)
			return unitID ~= nil and ModuleHandler.Get("transport").IsCarried(unitID)
		end

		return {
			Carry = function(carrierName, cargoName, fx, fz)
				local carrierID, cargoID = living(carrierName), living(cargoName)
				if carrierID == nil or cargoID == nil then
					runtime.Log(
						LOG.WARNING,
						"Transport.Carry: no living roster unit named "
							.. (carrierID == nil and carrierName or cargoName)
					)
					return
				end
				local x, z = fx * Game.mapSizeX, fz * Game.mapSizeZ
				local y = Spring.GetGroundHeight(x, z)
				runtime.ReleaseHoldFire(carrierID)
				Spring.GiveOrderToUnit(carrierID, CMD.LOAD_UNITS, { cargoID }, {})
				Spring.GiveOrderToUnit(carrierID, CMD.UNLOAD_UNIT, { x, y, z }, { "shift" })
				carries[cargoName] = { loaded = false, delivered = false }
			end,
			IsCarried = carried,
			IsDelivered = function(cargoName)
				local carry = carries[cargoName]
				if carry == nil then
					return false
				end
				if carry.delivered then
					return true
				end
				if carried(cargoName) then
					carry.loaded = true
				elseif carry.loaded and living(cargoName) ~= nil then
					carry.delivered = true
				end
				return carry.delivered
			end,
		}
	end,
}
