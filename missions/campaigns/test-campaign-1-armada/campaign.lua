-- SPDX-FileCopyrightText: 2025 The BAR Authors
-- SPDX-License-Identifier: MIT

return {
	campaignId = "armada",
	title = "Test Campaign 1 - Armada",
	description = "This is a description field meant to hold longer string content.",
	backgroundImage = "BAR3-5K_Loadingscreen_1.jpg",
	logo = "armada_logo.png",
	faction = "armada",

    players = { min = 1, max = 4 },

    missions = {
        "mission_01",
        "mission_02",
        "mission_03",
    },

    unlock = {
        mission_02 = { requires = { "mission_01" } },
        mission_03 = { requires = { "mission_02" } },
    },
}
