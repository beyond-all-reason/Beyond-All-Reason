---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = require("modules/transfer/enums")
-- comms binds SendToUnsynced at load; this forwarder is what it captures, and a test points it where it likes
local sendToUnsynced = {}
---@diagnostic disable-next-line: global-in-non-module
_G.SendToUnsynced = _G.SendToUnsynced
	or function(...)
		if sendToUnsynced.target then
			sendToUnsynced.target(...)
		end
	end
local Helpers = require("modules/transfer/spec/support/synced_helpers")
local ResourceShared, ResourceComms
local function reloadTransfer()
	ResourceShared = require("modules/transfer/resource/shared")
	ResourceComms = require("modules/transfer/resource/comms")
end
reloadTransfer()

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()

local spring = Builders.Spring
	.new()
	:WithTeam(sender)
	:WithTeam(receiver)
	:WithAlliance(sender.id, receiver.id, true)
	:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
	:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Resource comms #comms", function()
	describe("CaseOf", function()
		it("should return OnSelf when sender equals receiver", function()
			local policy = { senderTeamId = 1, receiverTeamId = 1, canShare = true, taxRate = 0.3 }
			assert.equal(TransferEnums.ResourceTermsCase.OnSelf, ResourceShared.CaseOf(policy))
		end)

		it("should return OnTaxFree when tax rate is zero", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0 }
			assert.equal(TransferEnums.ResourceTermsCase.OnTaxFree, ResourceShared.CaseOf(policy))
		end)

		it("should return OnTaxed when taxed", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0.3 }
			assert.equal(TransferEnums.ResourceTermsCase.OnTaxed, ResourceShared.CaseOf(policy))
		end)

		it("should return OnDisabled when canShare is false", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = false, taxRate = 0 }
			assert.equal(TransferEnums.ResourceTermsCase.OnDisabled, ResourceShared.CaseOf(policy))
		end)
	end)

	describe("SendTransferChatMessages", function()
		-- The chat widget (luaui/Widgets/gui_chat.lua) reads the line as key:name=value:name=value and translates the key
		-- with those pairs; any other wire shape leaves every placeholder nil on screen.
		it("sends the key and name=value pairs the chat widget parses", function()
			local Comms = require("modules/transfer/resource/comms")
			local mock = spring:Build()
			mock.GetTeamInfo = function()
				return "team", 7, false, false
			end
			local captured
			sendToUnsynced.target = function(action, playerID, payload)
				captured = { action = action, playerID = playerID, payload = payload }
			end
			local ok, err = pcall(Helpers.withSpring, mock, function()
				Comms.SendTransferChatMessages({
					success = true,
					sent = 125,
					received = 100,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				}, {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					taxRate = 0.2,
					amountSendable = 500,
					amountReceivable = 1000,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				})
			end)
			sendToUnsynced.target = nil
			assert(ok, err)
			assert.equal("sendMsg", captured.action)
			assert.equal(7, captured.playerID)
			local parts = {}
			for part in string.gmatch(captured.payload, "[^:]+") do
				parts[#parts + 1] = part
			end
			assert.equal("ui.playersList.chat.sentMetalTaxed", parts[1])
			local pairsSeen = {}
			for i = 2, #parts do
				local name, value = parts[i]:match("^(%w+)=(.+)$")
				assert.is_truthy(name, "every parameter is name=value, got " .. tostring(parts[i]))
				pairsSeen[name] = value
			end
			assert.same({ receivedAmount = "100", sentAmount = "125", taxRatePercentage = "20" }, pairsSeen)
		end)
	end)

	describe("FormatNumberForUI", function()
		it("should floor numbers to whole values", function()
			assert.equal("285", ResourceComms.FormatNumberForUI(285.71))
			assert.equal("100", ResourceComms.FormatNumberForUI(100.99))
			assert.equal("0", ResourceComms.FormatNumberForUI(0.5))
		end)

		it("should pass through non-number values", function()
			assert.equal("hello", ResourceComms.FormatNumberForUI("hello"))
		end)
	end)
end)
