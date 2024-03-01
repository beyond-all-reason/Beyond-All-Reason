if not gadgetHandler:IsSyncedCode() then
	return
end
--[[
local function rot_to_facing(rotation)
	
	"south" | "s" | 0 == 0
	"east" | "e" | 1  == 16384
	"north" | "n" | 2 == +32 or -32k
	"west" | "w" | 3 == -16384
	
	if rotation < 8192 and rotation > -8192 then
		return 0
	end
	if rotation > 8192 and rotation < 24576 then
		return 1
	end
	if rotation < -8192 and rotation > -24576 then
		return 3
	end
	return 2
end
]]--
--
--[[
    Different loadout tables
]]
--
local loadout = {
    {name = "cortex_orca", x = 2395, y = -46, z = 1798, rot = -19024, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3752, py = -46, pz = 2807}},
    }},
    {name = "cortex_orca", x = 2101, y = -46, z = 2283, rot = -19135, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3458, py = -46, pz = 3292}},
    }},
    {name = "cortex_orca", x = 2526, y = -46, z = 1727, rot = -22660, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3883, py = -46, pz = 2736}},
    }},
    {name = "cortex_orca", x = 2174, y = -46, z = 2141, rot = -19743, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3532, py = -46, pz = 3150}},
    }},
    {name = "cortex_orca", x = 2273, y = -46, z = 1961, rot = -26036, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3630, py = -46, pz = 2970}},
    }},
    {name = "cortex_orca", x = 2225, y = -46, z = 2049, rot = -18900, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3582, py = -46, pz = 3058}},
    }},
    {name = "cortex_orca", x = 2481, y = -46, z = 1754, rot = -25613, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3838, py = -46, pz = 2763}},
    }},
    {name = "cortex_orca", x = 2299, y = -46, z = 1913, rot = -27608, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3656, py = -46, pz = 2922}},
    }},
    {name = "cortex_orca", x = 2152, y = -46, z = 2190, rot = -20447, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3509, py = -46, pz = 3199}},
    }},
    {name = "cortex_orca", x = 2355, y = -46, z = 1830, rot = -22140, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3712, py = -46, pz = 2839}},
    }},
    {name = "cortex_orca", x = 2324, y = -46, z = 1871, rot = -21438, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3681, py = -46, pz = 2880}},
    }},
    {name = "cortex_orca", x = 2564, y = -46, z = 1710, rot = -26779, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3921, py = -46, pz = 2720}},
    }},
    {name = "cortex_orca", x = 2597, y = -46, z = 1688, rot = -22725, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3954, py = -46, pz = 2697}},
    }},
    {name = "cortex_orca", x = 2671, y = -46, z = 1660, rot = -20204, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 4028, py = -46, pz = 2669}},
    }},
    {name = "cortex_orca", x = 2199, y = -46, z = 2094, rot = -24359, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3556, py = -46, pz = 3103}},
    }},
    {name = "cortex_orca", x = 2631, y = -46, z = 1664, rot = -23525, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3988, py = -46, pz = 2673}},
    }},
    {name = "cortex_orca", x = 2074, y = -46, z = 2325, rot = -27673, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3431, py = -46, pz = 3334}},
    }},
    {name = "cortex_orca", x = 2053, y = -46, z = 2367, rot = -28267, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3410, py = -46, pz = 3376}},
    }},
    {name = "cortex_orca", x = 2248, y = -46, z = 2002, rot = -29877, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3605, py = -46, pz = 3011}},
    }},
    {name = "cortex_orca", x = 2122, y = -46, z = 2234, rot = -20970, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3479, py = -46, pz = 3243}},
    }},
    {name = "cortex_orca", x = 2438, y = -46, z = 1775, rot = -28732, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3795, py = -46, pz = 2785}},
    }},
    {name = "cortex_predator", x = 4091, y = -41, z = 2745, rot = 4577, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2613, py = -41, pz = 1610}},
    }},
    {name = "cortex_predator", x = 3610, y = -41, z = 3333, rot = 6060, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2131, py = -41, pz = 2198}},
    }},
    {name = "cortex_predator", x = 3410, y = -41, z = 3460, rot = 9963, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 1932, py = -41, pz = 2325}},
    }},
    {name = "cortex_predator", x = 4005, y = -41, z = 3005, rot = 5265, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2527, py = -41, pz = 1870}},
    }},
    {name = "cortex_predator", x = 3708, y = -41, z = 3267, rot = 4594, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2230, py = -41, pz = 2132}},
    }},
    {name = "cortex_predator", x = 3970, y = -41, z = 3046, rot = 8316, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2491, py = -41, pz = 1911}},
    }},
    {name = "cortex_predator", x = 3559, y = -41, z = 3368, rot = 5400, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2081, py = -41, pz = 2233}},
    }},
    {name = "cortex_predator", x = 4104, y = -41, z = 2691, rot = 7498, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2625, py = -41, pz = 1556}},
    }},
    {name = "cortex_predator", x = 3506, y = -41, z = 3398, rot = 4976, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2027, py = -41, pz = 2263}},
    }},
    {name = "cortex_predator", x = 3889, y = -41, z = 3113, rot = 10484, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2411, py = -41, pz = 1978}},
    }},
    {name = "cortex_predator", x = 3660, y = -41, z = 3303, rot = 4746, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2182, py = -41, pz = 2168}},
    }},
    {name = "cortex_predator", x = 4036, y = -41, z = 2966, rot = 6577, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2557, py = -41, pz = 1831}},
    }},
    {name = "cortex_predator", x = 3846, y = -41, z = 3154, rot = 5416, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2367, py = -41, pz = 2018}},
    }},
    {name = "cortex_predator", x = 4078, y = -41, z = 2864, rot = 8478, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2600, py = -41, pz = 1729}},
    }},
    {name = "cortex_predator", x = 3934, y = -41, z = 3078, rot = 6340, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2456, py = -41, pz = 1943}},
    }},
    {name = "cortex_predator", x = 4084, y = -41, z = 2804, rot = 9219, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2606, py = -41, pz = 1669}},
    }},
    {name = "cortex_predator", x = 4057, y = -41, z = 2919, rot = 7581, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2578, py = -41, pz = 1784}},
    }},
    {name = "cortex_predator", x = 3748, y = -41, z = 3226, rot = 9738, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2269, py = -41, pz = 2091}},
    }},
    {name = "cortex_predator", x = 3454, y = -41, z = 3430, rot = 8993, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 1975, py = -41, pz = 2295}},
    }},
    {name = "cortex_predator", x = 3795, y = -41, z = 3186, rot = 5517, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2317, py = -41, pz = 2051}},
    }},
    {name = "cortex_phantasm", x = 2795, y = 0, z = 2285, rot = 10658, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3579, py = 0, pz = 2672}},
    }},
    {name = "cortex_phantasm", x = 3458, y = 0, z = 2924, rot = -24312, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 2651, py = 0, pz = 2110}},
    }},
    {name = "cortex_kraken", x = 2315, y = -81, z = 2807, rot = 13433, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 803, py = -81, pz = 2654}},
    }},
    {name = "cortex_kraken", x = 2231, y = -81, z = 2717, rot = 17969, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 1333, py = -81, pz = 2368}},
    }},
    {name = "cortex_kraken", x = 2582, y = -81, z = 3087, rot = 14196, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 3056, py = -81, pz = 3965}},
    }},
    {name = "cortex_kraken", x = 2485, y = -81, z = 2997, rot = 15927, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 2520, py = -81, pz = 4434}},
    }},
    {name = "cortex_kraken", x = 2393, y = -81, z = 2902, rot = 14020, teamID = 5, queue = {
    {cmdID = CMD.PATROL, position = {px = 1324, py = -81, pz = 3610}},
    }},
    {name = "cortex_kraken", x = 3537, y = -81, z = 1988, rot = -13998, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 3041, py = -81, pz = 1033}},
    }},
    {name = "cortex_kraken", x = 3956, y = -81, z = 2412, rot = -13577, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 4819, py = -81, pz = 2597}},
    }},
    {name = "cortex_kraken", x = 3869, y = -81, z = 2293, rot = -12114, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 5260, py = -81, pz = 2368}},
    }},
    {name = "cortex_kraken", x = 3660, y = -81, z = 2072, rot = -15091, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 3407, py = -81, pz = 756}},
    }},
    {name = "cortex_kraken", x = 3774, y = -81, z = 2181, rot = -13382, teamID = 4, queue = {
    {cmdID = CMD.PATROL, position = {px = 4997, py = -81, pz = 1632}},
    }},
    {name = "cortex_arrowstorm", x = 401, y = 0, z = 3293, rot = -8268, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1076, py = 0, pz = 3071}},
    {cmdID = CMD.PATROL, position = {px = 2089, py = 0, pz = 2361}},
    {cmdID = CMD.PATROL, position = {px = 1632, py = 0, pz = 3700}},
    }},
    {name = "cortex_advancedconstructionsub", x = 326, y = -81, z = 3389, rot = -14327, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1002, py = -81, pz = 3168}},
    {cmdID = CMD.PATROL, position = {px = 2014, py = -81, pz = 2457}},
    {cmdID = CMD.PATROL, position = {px = 1557, py = -81, pz = 3797}},
    }},
    {name = "cortex_advancedconstructionsub", x = 87, y = -81, z = 3606, rot = -19391, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 763, py = -81, pz = 3384}},
    {cmdID = CMD.PATROL, position = {px = 1775, py = -81, pz = 2673}},
    {cmdID = CMD.PATROL, position = {px = 1318, py = -81, pz = 4013}},
    }},
    {name = "cortex_advancedconstructionsub", x = 85, y = -81, z = 3245, rot = -14186, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 760, py = -81, pz = 3024}},
    {cmdID = CMD.PATROL, position = {px = 1772, py = -81, pz = 2313}},
    {cmdID = CMD.PATROL, position = {px = 1316, py = -81, pz = 3652}},
    }},
    {name = "cortex_despot", x = 59, y = 0, z = 3128, rot = -17857, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 734, py = 0, pz = 2907}},
    {cmdID = CMD.PATROL, position = {px = 1746, py = 0, pz = 2196}},
    {cmdID = CMD.PATROL, position = {px = 1290, py = 0, pz = 3535}},
    }},
    {name = "cortex_arrowstorm", x = 53, y = 0, z = 3494, rot = -12873, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 729, py = 0, pz = 3272}},
    {cmdID = CMD.PATROL, position = {px = 1741, py = 0, pz = 2562}},
    {cmdID = CMD.PATROL, position = {px = 1284, py = 0, pz = 3901}},
    }},
    {name = "cortex_despot", x = 403, y = 0, z = 3127, rot = -13163, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1079, py = 0, pz = 2906}},
    {cmdID = CMD.PATROL, position = {px = 2091, py = 0, pz = 2195}},
    {cmdID = CMD.PATROL, position = {px = 1634, py = 0, pz = 3535}},
    }},
    {name = "cortex_kraken", x = 440, y = -81, z = 3711, rot = -16709, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1116, py = -81, pz = 3490}},
    {cmdID = CMD.PATROL, position = {px = 2128, py = -81, pz = 2779}},
    {cmdID = CMD.PATROL, position = {px = 1671, py = -81, pz = 4119}},
    }},
    {name = "cortex_kraken", x = 545, y = -81, z = 3306, rot = -19247, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1220, py = -81, pz = 3085}},
    {cmdID = CMD.PATROL, position = {px = 2232, py = -81, pz = 2374}},
    {cmdID = CMD.PATROL, position = {px = 1776, py = -81, pz = 3713}},
    }},
    {name = "cortex_kraken", x = 280, y = -81, z = 3014, rot = -17025, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 955, py = -81, pz = 2792}},
    {cmdID = CMD.PATROL, position = {px = 1967, py = -81, pz = 2081}},
    {cmdID = CMD.PATROL, position = {px = 1511, py = -81, pz = 3421}},
    }},
    {name = "cortex_phantasm", x = 181, y = 0, z = 3498, rot = -17266, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 856, py = 0, pz = 3277}},
    {cmdID = CMD.PATROL, position = {px = 1868, py = 0, pz = 2566}},
    {cmdID = CMD.PATROL, position = {px = 1412, py = 0, pz = 3906}},
    }},
    {name = "cortex_phantasm", x = 60, y = 0, z = 3679, rot = -19976, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 735, py = 0, pz = 3457}},
    {cmdID = CMD.PATROL, position = {px = 1748, py = 0, pz = 2747}},
    {cmdID = CMD.PATROL, position = {px = 1291, py = 0, pz = 4086}},
    }},
    {name = "cortex_phantasm", x = 314, y = 0, z = 3651, rot = -17396, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 990, py = 0, pz = 3430}},
    {cmdID = CMD.PATROL, position = {px = 2002, py = 0, pz = 2719}},
    {cmdID = CMD.PATROL, position = {px = 1545, py = 0, pz = 4059}},
    }},
    {name = "cortex_oasis2", x = 372, y = 0, z = 3418, rot = -14339, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 1048, py = 0, pz = 3196}},
    {cmdID = CMD.PATROL, position = {px = 2060, py = 0, pz = 2486}},
    {cmdID = CMD.PATROL, position = {px = 1603, py = 0, pz = 3825}},
    }},
    {name = "cortex_oasis", x = 214, y = 0, z = 3129, rot = -16320, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 890, py = 0, pz = 2907}},
    {cmdID = CMD.PATROL, position = {px = 1902, py = 0, pz = 2197}},
    {cmdID = CMD.PATROL, position = {px = 1445, py = 0, pz = 3536}},
    }},
    {name = "cortex_oasis2", x = 73, y = 0, z = 3292, rot = -20175, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 749, py = 0, pz = 3070}},
    {cmdID = CMD.PATROL, position = {px = 1761, py = 0, pz = 2360}},
    {cmdID = CMD.PATROL, position = {px = 1304, py = 0, pz = 3699}},
    }},
    {name = "cortex_despot", x = 231, y = 0, z = 3291, rot = -18175, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 907, py = 0, pz = 3070}},
    {cmdID = CMD.PATROL, position = {px = 1919, py = 0, pz = 2359}},
    {cmdID = CMD.PATROL, position = {px = 1462, py = 0, pz = 3699}},
    }},
    {name = "cortex_arrowstorm", x = 189, y = 0, z = 3680, rot = -14214, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 865, py = 0, pz = 3459}},
    {cmdID = CMD.PATROL, position = {px = 1877, py = 0, pz = 2748}},
    {cmdID = CMD.PATROL, position = {px = 1420, py = 0, pz = 4088}},
    }},
    {name = "cortex_kraken", x = 4466, y = -81, z = 274, rot = 28841, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4086, py = -81, pz = 879}},
    {cmdID = CMD.PATROL, position = {px = 3547, py = -81, pz = 1335}},
    {cmdID = CMD.PATROL, position = {px = 4334, py = -81, pz = 1948}},
    }},
    {name = "cortex_advancedconstructionsub", x = 4335, y = -81, z = 64, rot = 32023, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3954, py = -81, pz = 668}},
    {cmdID = CMD.PATROL, position = {px = 3415, py = -81, pz = 1125}},
    {cmdID = CMD.PATROL, position = {px = 4202, py = -81, pz = 1738}},
    }},
    {name = "cortex_advancedconstructionsub", x = 4450, y = -81, z = 208, rot = 32023, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4069, py =  -81, pz = 812}},
    {cmdID = CMD.PATROL, position = {px = 3531, py = -81, pz = 1269}},
    {cmdID = CMD.PATROL, position = {px = 4317, py = -81, pz = 1882}},
    }},
    {name = "cortex_oasis2", x = 4272, y = 0, z = 350, rot = 30329, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3892, py = 0, pz = 955}},
    {cmdID = CMD.PATROL, position = {px = 3353, py = 0, pz = 1411}},
    {cmdID = CMD.PATROL, position = {px = 4140, py = 0, pz = 2024}},
    }},
    {name = "cortex_arrowstorm", x = 4380, y = 0, z = 199, rot = 29239, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3999, py = 0, pz = 803}},
    {cmdID = CMD.PATROL, position = {px = 3461, py = 0, pz = 1260}},
    {cmdID = CMD.PATROL, position = {px = 4247, py = 0, pz = 1873}},
    }},
    {name = "cortex_arrowstorm", x = 4099, y = 0, z = 347, rot = -31268, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3718, py = 0, pz = 952}},
    {cmdID = CMD.PATROL, position = {px = 3180, py = 0, pz = 1409}},
    {cmdID = CMD.PATROL, position = {px = 3966, py = 0, pz = 2022}},
    }},
    {name = "cortex_phantasm", x = 4515, y = 0, z = 200, rot = -29184, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4135, py = 0, pz = 805}},
    {cmdID = CMD.PATROL, position = {px = 3596, py = 0, pz = 1262}},
    {cmdID = CMD.PATROL, position = {px = 4383, py = 0, pz = 1875}},
    }},
    {name = "cortex_phantasm", x = 4504, y = 0, z = 334, rot = 27574, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4124, py = 0, pz = 939}},
    {cmdID = CMD.PATROL, position = {px = 3585, py = 0, pz = 1395}},
    {cmdID = CMD.PATROL, position = {px = 4371, py = 0, pz = 2008}},
    }},
    {name = "cortex_oasis", x = 4109, y = 0, z = 204, rot = 29517, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3728, py = 0, pz = 809}},
    {cmdID = CMD.PATROL, position = {px = 3190, py = 0, pz = 1265}},
    {cmdID = CMD.PATROL, position = {px = 3976, py = 0, pz = 1878}},
    }},
    {name = "cortex_advancedconstructionsub", x = 4216, y = -81, z = 200, rot = 24493, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3836, py = -81, pz = 805}},
    {cmdID = CMD.PATROL, position = {px = 3297, py = -81, pz = 1261}},
    {cmdID = CMD.PATROL, position = {px = 4083, py = -81, pz = 1875}},
    }},
    {name = "cortex_arrowstorm", x = 4549, y = 0, z = 64, rot = 24032, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4168, py = 0, pz = 668}},
    {cmdID = CMD.PATROL, position = {px = 3629, py = 0, pz = 1125}},
    {cmdID = CMD.PATROL, position = {px = 4416, py = 0, pz = 1738}},
    }},
    {name = "cortex_despot", x = 4126, y = 0, z = 68, rot = 30890, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3746, py = 0, pz = 672}},
    {cmdID = CMD.PATROL, position = {px = 3207, py = 0, pz = 1129}},
    {cmdID = CMD.PATROL, position = {px = 3994, py = 0, pz = 1742}},
    }},
    {name = "cortex_phantasm", x = 4394, y = 0, z = 48, rot = 29167, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 4013, py = 0, pz = 653}},
    {cmdID = CMD.PATROL, position = {px = 3475, py = 0, pz = 1109}},
    {cmdID = CMD.PATROL, position = {px = 4261, py = 0, pz = 1722}},
    }},
    {name = "cortex_oasis2", x = 4283, y = 0, z = 65, rot = 20132, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3902, py = 0, pz = 669}},
    {cmdID = CMD.PATROL, position = {px = 3363, py = 0, pz = 1126}},
    {cmdID = CMD.PATROL, position = {px = 4150, py = 0, pz = 1739}},
    }},
    {name = "cortex_kraken", x = 4176, y = -81, z = 277, rot = 25315, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3795, py = -81, pz = 881}},
    {cmdID = CMD.PATROL, position = {px = 3257, py = -81, pz = 1338}},
    {cmdID = CMD.PATROL, position = {px = 4043, py = -81, pz = 1951}},
    }},
    {name = "cortex_despot", x = 4271, y = 0, z = 211, rot = 32159, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3891, py = 0, pz = 816}},
    {cmdID = CMD.PATROL, position = {px = 3352, py = 0, pz = 1273}},
    {cmdID = CMD.PATROL, position = {px = 4139, py = 0, pz = 1886}},
    }},
    {name = "cortex_despot", x = 4365, y = 0, z = 361, rot = -24568, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3985, py = 0, pz = 965}},
    {cmdID = CMD.PATROL, position = {px = 3446, py = 0, pz = 1422}},
    {cmdID = CMD.PATROL, position = {px = 4233, py = 0, pz = 2035}},
    }},
}

local backupOne = {
    {name = 'cortex_mammoth', x = 4367, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4677, py = 34, pz = 4530}},
    }},
    {name = 'cortex_banisher', x = 4453, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4788, py = 34, pz = 4707}},
    }},
    {name = 'cortex_deceiver', x = 4542, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4838, py = 34, pz = 4778}},
    }},
    {name = 'cortex_fury', x = 4634, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4907, py = 34, pz = 4854}},
    }},
    {name = 'cortex_twitcher', x = 4758, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4951, py = 34, pz = 4889}},
    }},
    {name = 'armada_consul', x = 4868, y = 34, z = 5112, rot = 32767, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 4951, py = 34, pz = 4889}},
    }},
    {name = 'armada_marauder', x = 1382, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1439, py = 34, pz = 326}},
    }},
    {name = 'armada_starlight', x = 1487, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1548, py = 34, pz = 399}},
    }},
    {name = 'armada_bull', x = 1584, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1645, py = 34, pz = 404}},
    }},
    {name = 'armada_mauser', x = 1676, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1725, py = 34, pz = 403}},
    }},
    {name = 'armada_mauser', x = 1770, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1809, py = 34, pz = 406}},
    }},
}

local backupTwo = {
    {name = 'cortex_mammoth', x = 4367, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4677, py = 34, pz = 4530}},
    }},
    {name = 'cortex_karganeth', x = 4453, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4788, py = 34, pz = 4707}},
    }},
    {name = 'cortex_deceiver', x = 4542, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4838, py = 34, pz = 4778}},
    }},
    {name = 'cortex_tzar', x = 4634, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4907, py = 34, pz = 4854}},
    }},
    {name = 'cortex_negotiator', x = 4758, y = 34, z = 5112, rot = 32767, teamID = 1, queue = {
    {cmdID = CMD.MOVE, position = {px = 4951, py = 34, pz = 4889}},
    }},
    {name = 'armada_ambassador', x = 1382, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1439, py = 34, pz = 326}},
    }},
    {name = 'armada_ambassador', x = 1487, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1548, py = 34, pz = 399}},
    }},
    {name = 'armada_razorback', x = 1584, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1645, py = 34, pz = 404}},
    }},
    {name = 'armada_shredder', x = 1676, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1725, py = 34, pz = 403}},
    }},
    {name = 'armada_razorback', x = 1770, y = 34, z = 4, rot = 0, teamID = 0, queue = {
    {cmdID = CMD.MOVE, position = {px = 1809, py = 34, pz = 406}},
    }},
    {name = "cortex_advancedbotlab", x = 2928,	y = 33,	z = 288, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_shroud", x = 3520, y = 33, z = 80, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_shroud", x = 3072, y = 33, z = 224, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_overseer", x = 3536, y = 33, z = 32, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_overseer", x = 3120, y = 33, z = 224, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_scorpion", x = 2856, y = 36, z = 584, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_scorpion", x = 3176, y = 32, z = 728, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2800, y = 52, z = 576, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2768, y = 50, z = 544, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2736, y = 47, z = 512, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2704, y = 48, z = 480, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2688, y = 48, z = 448, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2656, y = 54, z = 416, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2624, y = 59, z = 384, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2608, y = 59, z = 352, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2608, y = 55, z = 320, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2592, y = 56, z = 288, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2592, y = 53, z = 256, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2592, y = 51, z = 224, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2592, y = 50, z = 192, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2576, y = 53, z = 160, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2576, y = 50, z = 128, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2576, y = 48, z = 96, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2560, y = 50, z = 64, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_fortificationwall", x = 2560, y = 47, z = 32, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_birdshot", x = 3040, y = 33, z = 224, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_prevailer", x = 3600,	y = 33,	z = 32, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_nemesis", x = 3568, y = 33, z = 96, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_warden", x = 2832,	y = 36,	z = 528, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_warden", x = 3216,	y = 33,	z = 672, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_dragonsmaw", x = 2912,	y = 33,	z = 608, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_dragonsmaw", x = 3120,	y = 32,	z = 736, rot = 0, teamID = 2, queue = {}},
    {name = "cortex_vehicleplant", x = 3288, y = 33, z = 296, rot = 0, teamID = 2, queue = {}},
}

local timed = {
    {name = 'cortex_blackhydra', x = 5, y = 0, z = 3165, rot = 0, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 999, py = 0, pz = 2769}},
    }},
    {name = 'cortex_advancedconstructionsub', x = 5, y = -80, z = 3238, rot = 0, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 1076, py = -80, pz = 2946}},
    }},
    {name = 'cortex_messenger', x = 5, y = 0, z = 3320, rot = 0, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 1304, py = 0, pz = 3226}},
    }},
    {name = 'cortex_blackhydra', x = 6127, y = 0, z = 1880, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 4997, py = 0, pz = 2356}},
    }},
    {name = 'cortex_advancedconstructionsub', x = 6130, y = -80, z = 1734, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 5008, py = -80, pz = 2164}},
    }},
    {name = 'cortex_messenger', x = 6125, y = 0, z = 1556, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 4824, py = 0, pz = 1977}},
    }},
    {name = 'cortex_mammoth', x = 2791, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 2884, py = 33, pz = 4887}},
    }},
    {name = 'cortex_tiger', x = 2738, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 2777, py = 33, pz = 4890}},
    }},
    {name = 'cortex_deceiver', x = 2660, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 2703, py = 33, pz = 4881}},
    }},
    {name = 'cortex_fury', x = 2600, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 2630, py = 33, pz = 4881}},
    }},
    {name = 'cortex_advancedconstructionbot', x = 2520, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {
    {cmdID = CMD.MOVE, position = {px = 2581, py = 33, pz = 4884}},
    }},
    {name = 'cortex_shiva', x = 2851, y = 33, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_mammoth', x = 2920, y = 33, z = 4, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 3100, py = 33, pz = 362}},
    }},
    {name = 'cortex_tiger', x = 3056, y = 33, z = 4, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 3171, py = 33, pz = 362}},
    }},
    {name = 'cortex_deceiver', x = 3144, y = 33, z = 4, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 3230, py = 33, pz = 362}},
    }},
    {name = 'cortex_fury', x = 3235, y = 33, z = 4, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 3310, py = 33, pz = 362}},
    }},
    {name = 'cortex_advancedconstructionbot', x = 3306, y = 33, z = 4, rot = 0, teamID = 2, queue = {
    {cmdID = CMD.MOVE, position = {px = 3425, py = 33, pz = 362}},
    }},
    {name = 'cortex_shiva', x = 2810, y = 33, z = 4, rot = 0, teamID = 2, queue = {}},
}

local special = {
    {name = 'cortex_dragonold', x = 6031, y = 150, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.FIGHT, position = {px = 5154, py = 130, pz = 4875}},
    }},
    {name = 'cortex_dragonold', x = 5970, y = 150, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.FIGHT, position = {px = 5822, py = 130, pz = 4892}},
    }},
    {name = 'cortex_dragonold', x = 5800, y = 150, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.FIGHT, position = {px = 3723, py = 130, pz = 4297}},
    }},
    {name = 'cortex_dragonold', x = 5750, y = 150, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.FIGHT, position = {px = 1830, py = 130, pz = 3256}},
    }},
    {name = 'cortex_watcher', x = 5550, y = 130, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 5833, py = 130, pz = 2056}},
    {cmdID = CMD.PATROL, position = {px = 3973, py = 130, pz = 3035}},
    }},
    {name = 'cortex_watcher', x = 5450, y = 130, z = 4, rot = 0, teamID = 4, queue = {
    {cmdID = CMD.MOVE, position = {px = 3286, py = 130, pz = 938}},
    {cmdID = CMD.PATROL, position = {px = 2565, py = 130, pz = 41}},
    }},
    {name = 'cortex_dragonold', x = 160, y = 150, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.FIGHT, position = {px = 242, py = 130, pz = 221}},
    }},
    {name = 'cortex_dragonold', x = 560, y = 150, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.FIGHT, position = {px = 742, py = 130, pz = 264}},
    }},
    {name = 'cortex_dragonold', x = 180, y = 150, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.FIGHT, position = {px = 1214, py = 130, pz = 399}},
    }},
    {name = 'cortex_dragonold', x = 210, y = 150, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.FIGHT, position = {px = 1932, py = 130, pz = 556}},
    }},
    {name = 'cortex_watcher', x = 330, y = 130, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 970, py = 130, pz = 2682}},
    {cmdID = CMD.PATROL, position = {px = 2272, py = 130, pz = 1943}},
    }},
    {name = 'cortex_watcher', x = 400, y = 130, z = 5110, rot = 32767, teamID = 5, queue = {
    {cmdID = CMD.MOVE, position = {px = 2982, py = 130, pz = 4094}},
    {cmdID = CMD.PATROL, position = {px = 3440, py = 130, pz = 5068}},
    }},
    {name = 'cortex_constructionseaplane', x = 6000, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_constructionseaplane', x = 5930, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_constructionseaplane', x = 5870, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_hailstorm', x = 5700, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_hailstorm', x = 5650, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_hailstorm', x = 5600, y = 130, z = 4, rot = 0, teamID = 2, queue = {}},
    {name = 'cortex_constructionseaplane', x = 50, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_constructionseaplane', x = 84, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_constructionseaplane', x = 128, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_hailstorm', x = 240, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_hailstorm', x = 270, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
    {name = 'cortex_hailstorm', x = 300, y = 130, z = 5110, rot = 32767, teamID = 3, queue = {}},
}

local objectiveUnits = {
    [1] = {
    {name = 'armada_missioncommandtower', x = 5814, y = 34, z = 4875, rot = 0, teamID = 1, queue = {}, objectiveUnitID = 2},
    --{name = 'armada_missioncommandtower', x = 932, y = 34, z = 491, rot = 0, teamID = 0, queue = {}, objectiveUnitID = 3},
    },
}

local objectiveUnitsAlive = {}

local function Fail()
    GG.wipeoutAllyTeam(0) -- kill all units when failed 
    GameOver = Spring.GameOver({2}) --winningAllyTeamN where N is Ally ID
end

local function Loadout()
    for k , unit in pairs(loadout) do
        if UnitDefNames[unit.name] then
           -- Spring.Echo("trying to spawn a unit, synced is", Script.GetSynced())
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
            for i = 1, #unit.queue do
                local order = unit.queue[i]
                local position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
            end
        end
    end
end

function ObjectiveLoadout()
    for i, unitGroup in ipairs(objectiveUnits) do
        for j, unit in ipairs(unitGroup) do
            if UnitDefNames[unit.name] then
                local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
                objectiveUnitsAlive[unitID] = true
                if unit.objectiveUnitID then
                    objectiveUnits[unitID] = unit.objectiveUnitID
                end
                for k, order in ipairs(unit.queue) do
                    local position = {order.position["px"], order.position["py"], order.position["pz"]}
                    Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
                end
            end
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID)
    if objectiveUnitsAlive[unitID] then -- check if it hasn't already died
        objectiveUnitsAlive[unitID] = nil -- remove it 
        for i, unitGroup in ipairs(objectiveUnits) do
            for j, unit in ipairs(unitGroup) do
                if unit.objectiveUnitID == 2 then
                    Fail()
                    Spring.Echo('\n\n\nYOU LOST CRITICAL BUILDING!!\nMISSION FAILED!!!')
                    objectiveUnits[unitID] = nil
                    return
                end
            end
        end
    end
end

local function BackupOne()
    for k , unit in pairs(backupOne) do
        if UnitDefNames[unit.name] then
           -- Spring.Echo("trying to spawn a unit, synced is", Script.GetSynced())
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
            for i = 1, #unit.queue do
                local order = unit.queue[i]
                local position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
            end
        end
    end
end

local function BackupTwo()
    for k , unit in pairs(backupTwo) do
        if UnitDefNames[unit.name] then
          -- Spring.Echo("trying to spawn a unit, synced is", Script.GetSynced())
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
            for i = 1, #unit.queue do
                local order = unit.queue[i]
                local position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
            end
        end
    end
end

local function Timed()
    for k , unit in pairs(timed) do
        if UnitDefNames[unit.name] then
           -- Spring.Echo("trying to spawn a unit, synced is", Script.GetSynced())
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
            for i = 1, #unit.queue do
                local order = unit.queue[i]
                local position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
            end
        end
    end
end

local function Special()
    for k , unit in pairs(special) do
        if UnitDefNames[unit.name] then
           -- Spring.Echo("trying to spawn a unit, synced is", Script.GetSynced())
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)
            for i = 1, #unit.queue do
                local order = unit.queue[i]
                local position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, position, CMD.OPT_SHIFT)
            end
        end
    end
end

function gadget:GameFrame(frameNum)
    local n = frameNum
    if n <= 1 then
        Loadout()   --Initial loadout with commands
        ObjectiveLoadout() -- objective loadout
    end
    if n == 16200 then -- 9min 
        BackupOne() --One time insertion at certain GameFrame
    end
    if n == 32400 then -- 18min
        BackupTwo() --One time insertion at certain GameFrame
    end
    if n>0 and n%14400 == 0 then -- 8min ((30frame/s *60sec)*8=14400 )
        Timed()  --Looped insertion at certain GameFrame   
    end
    if n>0 and n%36000 == 0 then -- 20min 
        Special()   --Looped insertion at certain GameFrame
    end
end