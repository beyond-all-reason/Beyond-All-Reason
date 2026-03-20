return {
	campaignId = "cortex-main",
	title = "Test Campaign 2 - Cortex",
	description = "This is a description field meant to hold longer string content.",
	backgroundImage = "BAR3-5K_Loadingscreen_2.jpg",
	logo = "cortex_logo.png",
	faction = "cortex",
	unlocked = false, -- dynamic data, should not be here, but in lobby state - this is just for testing purposes
	prerequisites = { "armada-main" }, -- Optional field to specify other campaigns that must be completed before this one is unlocked

	players = { min = 1, max = 4 },

	missions = {},

	unlock = {},
}
