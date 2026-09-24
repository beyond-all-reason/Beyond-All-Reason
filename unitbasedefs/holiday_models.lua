-- model: replacement objectname applied in alldefs_post during the holiday
-- hats: number of baked-in hat pieces (h1..hN) in that model; consumed as
--       customparams.holidayhatcount by unit_intergrated_hats.lua
local aprilFoolsModels = {
	corak = { model = "units/event/aprilfools/CORAK.s3o", hats = 7 },
	corllt = { model = "units/event/aprilfools/CORllt.s3o", hats = 8 },
	corhllt = { model = "units/event/aprilfools/CORhllt.s3o", hats = 8 },
	corack = { model = "units/event/aprilfools/CORACK.s3o", hats = 6 },
	corck = { model = "units/event/aprilfools/CORCK.s3o", hats = 6 },
	armpw = { model = "units/event/aprilfools/ARMPW.s3o", hats = 7 },
	cordemon = { model = "units/event/aprilfools/cordemon.s3o", hats = 4 },
	--correap -- Requires Model Update
	corstorm = { model = "units/event/aprilfools/corstorm.s3o", hats = 7 },
	armcv = { model = "units/event/aprilfools/armcv.s3o", hats = 5 },
	armrock = { model = "units/event/aprilfools/armrock.s3o", hats = 6 },
	armbull = { model = "units/event/aprilfools/armbull.s3o", hats = 6 },
	armllt = { model = "units/event/aprilfools/armllt.s3o", hats = 6 },
	armwin = { model = "units/event/aprilfools/armwin.s3o", hats = 6 },
	armham = { model = "units/event/aprilfools/armham.s3o", hats = 5 },
	corwin = { model = "units/event/aprilfools/corwin.s3o", hats = 7 },
	--corthud -- Requires Model Update
}

local halloweenModels = {
	armcom = { model = "units/event/halloween/armcom.s3o" },
	armdecom = { model = "units/event/halloween/armcom.s3o" },
	corcom = { model = "units/event/halloween/corcom.s3o", hats = 2 },
	cordecom = { model = "units/event/halloween/corcom.s3o" },
	legcom = { model = "units/event/halloween/legcom.s3o" },
	legdecom = { model = "units/event/halloween/legcom.s3o" },
	correap = { model = "units/event/halloween/correap.s3o" },
	leggob = { model = "units/event/halloween/leggob.s3o" },
	armrectr = { model = "units/event/halloween/armrectr.s3o" },
	armspy = { model = "units/event/halloween/armspy.s3o" },
}

local xmasModels = {
	armcom = { model = "units/event/xmas/armcom.s3o" },
	armdecom = { model = "units/event/xmas/armcom.s3o" },
	corcom = { model = "units/event/xmas/corcom.s3o" },
	cordecom = { model = "units/event/xmas/corcom.s3o" },
}

return {
	AprilFools = aprilFoolsModels,
	Halloween = halloweenModels,
	Xmas = xmasModels,
}
