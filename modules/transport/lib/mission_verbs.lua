local Events = VFS.Include("modules/transport/lib/events.lua")

local TransportVerbs = {}

---@param unitRef MissionUnitRef
---@param verb string
local function checkUnitRef(unitRef, verb)
	assert(type(unitRef) == "table" and type(unitRef.name) == "string", verb .. " expects a Unit(...) reference")
end

---@param file MissionDslFile
---@return TransportActions
function TransportVerbs.MakeTransport(file)
	local transport = {}

	---@param cargo MissionUnitRef
	---@return TransportCarryChain
	transport.Carry = function(cargo)
		checkUnitRef(cargo, "Transport.Carry")
		local request = { cargo = cargo.name }
		local chain = {}

		---@param ctx MissionContext
		chain.execute = function(ctx)
			assert(request.carrier ~= nil, "Transport.Carry(" .. cargo.name .. ") needs .By(Units.…)")
			assert(request.fx ~= nil, "Transport.Carry(" .. cargo.name .. ") needs .To(fx, fz)")
			ctx.Carry(request.carrier, request.cargo, request.fx, request.fz)
		end

		---@param carrier MissionUnitRef
		---@return TransportCarryChain
		chain.By = function(carrier)
			checkUnitRef(carrier, "Transport.Carry(...).By")
			request.carrier = carrier.name
			return chain
		end

		---@param fx number
		---@param fz number
		---@return TransportCarryChain
		chain.To = function(fx, fz)
			assert(type(fx) == "number" and type(fz) == "number", "Transport.Carry(...).To expects two map fractions")
			request.fx, request.fz = fx, fz
			return chain
		end

		return chain
	end

	---@param cargo MissionUnitRef
	---@return MissionCondition
	transport.Carried = function(cargo)
		checkUnitRef(cargo, "Transport.Carried")
		return {
			inputs = { Events.UnitLoaded, Events.UnitUnloaded },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return ctx.IsCarried(cargo.name)
			end,
		}
	end

	---@param cargo MissionUnitRef
	---@return MissionCondition
	transport.Delivered = function(cargo)
		checkUnitRef(cargo, "Transport.Delivered")
		return {
			inputs = { Events.UnitLoaded, Events.UnitUnloaded },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return ctx.IsDelivered(cargo.name)
			end,
		}
	end

	return transport
end

return TransportVerbs
