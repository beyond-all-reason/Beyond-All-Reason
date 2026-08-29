---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local GADGET = "modules/transport/gadgets/transport_rules.lua"

local function units()
	local dropship = Spawn(UnitDef("corvalk"), "gaia").At(0.1, 0.1).Named("dropship").Neutral()
	local cargo = Spawn(UnitDef("corak"), "gaia").At(0.1, 0.12).Named("reinforcements").Neutral()
	return { dropship = dropship, cargo = cargo }
end

---@param triggers fun() the mission's one trigger file
local function mission(triggers)
	return Builders.Mission.new():WithModule("transport", GADGET):WithSources("t", {
		["units.lua"] = units,
		["triggers/ride.lua"] = triggers,
	})
end

local function ride()
	local Units = VFS.Include("modules/missions/t/units.lua")
	When(MatchFlow.Started()).Do(Transport.Carry(Units.cargo).By(Units.dropship).To(0.5, 0.5))
	When(Transport.Delivered(Units.cargo)).Do(MatchFlow.Victory(Team.Player))
end

---@param orders { cmd: integer, params: any[] }[]
---@param cmd integer
local function orderOf(orders, cmd)
	for _, order in ipairs(orders) do
		if order.cmd == cmd then
			return order
		end
	end
	return nil
end

describe("the ride, through the real transport module", function()
	it("Carry orders the carrier to pick the unit up and set it down at the spot", function()
		local m = mission(ride):Arm():Step()
		local CMD = m.env.CMD
		local dropship = m:Units()[m:UnitOf("dropship")]
		assert.are.same({ m:UnitOf("reinforcements") }, orderOf(dropship.orders, CMD.LOAD_UNITS).params)
		assert.are.same({ 4096, 0, 4096 }, orderOf(dropship.orders, CMD.UNLOAD_UNIT).params)
	end)

	it("Carry names units the roster knows, or says so and does nothing", function()
		local m = mission(ride):Arm()
		m:Kill("dropship", 0):Step()
		assert.is_true(m:Logged("Transport.Carry: no living roster unit named dropship"))
	end)

	it("Delivered latches once the cargo has been aboard and is set down again", function()
		local m = mission(ride):Arm():Step()
		assert.are.equal(0, #m:Calls("matchflow"))
		m:Board("reinforcements", "dropship"):Step()
		assert.are.equal(0, #m:Calls("matchflow"))
		m:SetDown("reinforcements"):Step()
		assert.are.equal("Victory", m:Calls("matchflow")[1].method)
	end)

	it("a unit set down that was never asked for a ride is not a delivery", function()
		local m = mission(function()
				local Units = VFS.Include("modules/missions/t/units.lua")
				When(Transport.Delivered(Units.cargo)).Do(MatchFlow.Victory(Team.Player))
			end)
			:Arm()
			:Step()
		m:Board("reinforcements", "dropship"):Step():SetDown("reinforcements"):Step()
		assert.are.equal(0, #m:Calls("matchflow"))
	end)
end)
