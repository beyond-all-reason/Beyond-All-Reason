--- Transfer's mission-sandbox verbs: the group is validated against the
--- roster at load, and the effect reaches the pipeline through the ctx.

local Verbs = VFS.Include("modules/missions/lib/verbs.lua")
local TransferVerbs = VFS.Include("modules/transfer/lib/mission_verbs.lua")

describe("transfer mission verbs", function()
	local Transfer = TransferVerbs.MakeTransfer({ outpost_auto = true })

	it("Transfer builds an effect that moves the group through ctx", function()
		local team = Verbs.MakeTeam(3, 1)
		local effect = Transfer.Units("outpost_auto", team)
		local transferred = {}
		effect.execute({
			TransferGroup = function(group, teamID)
				transferred[#transferred + 1] = { group = group, teamID = teamID }
			end,
		})
		assert.are.same({ { group = "outpost_auto", teamID = 3 } }, transferred)
	end)

	it("a group the roster never declared is a load error", function()
		local ok, err = pcall(Transfer.Units, "outpost", Verbs.MakeTeam(0, 0))
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("outpost", 1, true))
	end)

	it("Transfer rejects bad arguments", function()
		assert.has_error(function()
			Transfer.Units(nil, Verbs.MakeTeam(0, 0))
		end)
		assert.has_error(function()
			Transfer.Units("outpost_auto", 3)
		end)
	end)
end)
