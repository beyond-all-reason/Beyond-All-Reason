return {
	campaignId = "armada-main",
	title = "Test Campaign 1 - Armada",
	description = "This is a description field meant to hold longer string content.",
	backgroundImage = "BAR3-5K_Loadingscreen_1.jpg",
	logo = "armada_logo.png",
	faction = "armada",
	unlocked = true, -- dynamic data, should not be here, but in lobby state - this is just for testing purposes
	prerequisites = {}, -- Optional field to specify other campaigns that must be completed before this one is unlocked

	players = { min = 1, max = 4 }, -- should this be a list of numbers? to support eg. 1, 2, and 4 players, but not 3?

	missions = {
		"mission_01",
		"mission_02",
	},

	unlock = { -- could be prerequisites in missions instead
		mission_02 = { requires = { "mission_01" } },
	},
}
