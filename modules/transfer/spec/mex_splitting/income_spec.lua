local Income = require("modules/transfer/mex_splitting/income")

describe("shared mex income", function()
	local teams = {
		[0] = { allyTeam = 0, isDead = false },
		[1] = { allyTeam = 0, isDead = false },
		[2] = { allyTeam = 0, isDead = true },
		[3] = { allyTeam = 1, isDead = false },
	}

	it(
		"pays each living member of an ally team the average of what their mexes made; the dead, other allies and energy untouched",
		function()
			local income = Income.Shared(teams, {
				[0] = { metal = 90, energy = 5 },
				[1] = { metal = 30, energy = 0 },
				[2] = { metal = 100, energy = 0 },
				[3] = { metal = 7, energy = 1 },
			})
			assert.are.same({
				[0] = { metal = 60, energy = 5 },
				[1] = { metal = 60, energy = 0 },
				[2] = { metal = 100, energy = 0 },
				[3] = { metal = 7, energy = 1 },
			}, income)
		end
	)

	it("changes nothing for a team alone at its start", function()
		assert.are.same({ [3] = { metal = 7, energy = 1 } }, Income.Shared(teams, { [3] = { metal = 7, energy = 1 } }))
	end)
end)
