local function techsplitTweaks(name, uDef)
    if name == "coralab" then
        uDef.buildoptions = {
            [1] = "corack",
            [2] = "coraak",
            [3] = "cormort",
            [4] = "corcan",
            [5] = "corpyro",
            [6] = "corspy",
            [7] = "coramph",
            [8] = "cormando",
            [9] = "cortermite",
            [10] = "corhrk",
            [11] = "corvoyr",
            [12] = "corroach",
        }
    end

    if name == "armalab" then
        uDef.buildoptions = {
            [1] = "armack",
            [2] = "armfido",
            [3] = "armaak",
            [4] = "armzeus",
            [5] = "armmav",
            [6] = "armamph",
            [7] = "armspid",
            [8] = "armfast",
            [9] = "armvader",
            [10] = "armmark",
            [11] = "armsptk",
            [12] = "armspy",
        }
    end

    if name == "armavp" then
        uDef.buildoptions = {
            [1] = "armacv",
            [2] = "armch",
            [3] = "armcroc",
            [4] = "armlatnk",
            [5] = "armah",
            [6] = "armmart",
            [7] = "armseer",
            [8] = "armmh",
            [9] = "armanac",
            [10] = "armsh",
            [11] = "armgremlin"
        }
    end

    if name == "coravp" then
        uDef.buildoptions = {
            [1] = "corch",
            [2] = "coracv",
            [3] = "corsala",
            [4] = "correap",
            [5] = "cormart",
            [6] = "corhal",
            [7] = "cormh",
            [8] = "corsnap",
            [9] = "corah",
            [10] = "corsh",
            [11] = "corvrad",
            [12] = "corban"
        }
    end

    if name == "armck" then
        uDef.buildoptions = {
            [1] = "armsolar",
            [2] = "armwin",
            [3] = "armmex",
            [4] = "armmstor",
            [5] = "armestor",
            [6] = "armamex",
            [7] = "armmakr",
            [8] = "armalab",
            [9] = "armlab",
            [10] = "armvp",
            [11] = "armap",
            [12] = "armnanotc",
            [13] = "armeyes",
            [14] = "armrad",
            [15] = "armdrag",
            [16] = "armllt",
            [17] = "armrl",
            [18] = "armdl",
            [19] = "armjamt",
            [22] = "armsy",
            [23] = "armgeo",
            [24] = "armbeamer",
            [25] = "armhlt",
            [26] = "armferret",
            [27] = "armclaw",
            [28] = "armjuno",
            [29] = "armadvsol",
            [30] = "armguard"
        }
    end

    if name == "corck" then
        uDef.buildoptions = {
            [1] = "corsolar",
            [2] = "corwin",
            [3] = "cormstor",
            [4] = "corestor",
            [5] = "cormex",
            [6] = "cormakr",
            [10] = "corlab",
            [11] = "coralab",
            [12] = "corvp",
            [13] = "corap",
            [14] = "cornanotc",
            [15] = "coreyes",
            [16] = "cordrag",
            [17] = "corllt",
            [18] = "corrl",
            [19] = "corrad",
            [20] = "cordl",
            [21] = "corjamt",
            [22] = "corsy",
            [23] = "corexp",
            [24] = "corgeo",
            [25] = "corhllt",
            [26] = "corhlt",
            [27] = "cormaw",
            [28] = "cormadsam",
            [29] = "coradvsol",
            [30] = "corpun"
        }
    end

    if name == "armack" then
        uDef.buildoptions = {
            [1] = "armadvsol",
            [2] = "armmoho",
            [3] = "armbeamer",
            [4] = "armhlt",
            [5] = "armguard",
            [6] = "armferret",
            [7] = "armcir",
            [8] = "armjuno",
            [9] = "armpb",
            [10] = "armarad",
            [11] = "armveil",
            [12] = "armfus",
            [13] = "armgmm",
            [14] = "armhalab",
            [15] = "armlab",
            [16] = "armalab",
            [17] = "armsd",
            [18] = "armmakr",
            [19] = "armestor",
            [20] = "armmstor",
            [21] = "armageo",
            [22] = "armckfus",
            [23] = "armdl",
            [24] = "armdf",
            [25] = "armvp",
            [26] = "armsy",
            [27] = "armap",
            [28] = "armnanotc",
            [29] = "armamd",
        }
    end

    if name == "corack" then
        uDef.buildoptions = {
            [1] = "coradvsol",
            [2] = "cormoho",
            [3] = "corvipe",
            [4] = "corhllt",
            [5] = "corpun",
            [6] = "cormadsam",
            [7] = "corerad",
            [8] = "corjuno",
            [9] = "corfus",
            [10] = "corarad",
            [11] = "corshroud",
            [12] = "corsd",
            [13] = "corlab",
            [14] = "corhalab",
            [15] = "coralab",
            [16] = "cormakr",
            [17] = "corestor",
            [18] = "cormstor",
            [19] = "corageo",
            [20] = "corhlt",
            [21] = "cordl",
            [22] = "corvp",
            [23] = "corap",
            [24] = "corsy",
            [25] = "cornanotc",
            [26] = "corfmd",
        }
    end

    if name == "armcv" then
        uDef.buildoptions = {
            [1] = "armsolar",
            [2] = "armwin",
            [3] = "armmex",
            [4] = "armmstor",
            [5] = "armestor",
            [6] = "armamex",
            [7] = "armmakr",
            [8] = "armavp",
            [9] = "armlab",
            [10] = "armvp",
            [11] = "armap",
            [12] = "armnanotc",
            [13] = "armeyes",
            [14] = "armrad",
            [15] = "armdrag",
            [16] = "armllt",
            [17] = "armrl",
            [18] = "armdl",
            [19] = "armjamt",
            [22] = "armsy",
            [23] = "armgeo",
            [24] = "armbeamer",
            [25] = "armhlt",
            [26] = "armferret",
            [27] = "armclaw",
            [28] = "armjuno",
            [29] = "armadvsol",
            [30] = "armguard"
        }
    end

    if name == "armbeaver" then
        uDef.buildoptions = {
            [1] = "armsolar",
            [2] = "armwin",
            [3] = "armmex",
            [4] = "armmstor",
            [5] = "armestor",
            [6] = "armamex",
            [7] = "armmakr",
            [8] = "armavp",
            [9] = "armlab",
            [10] = "armvp",
            [11] = "armap",
            [12] = "armnanotc",
            [13] = "armeyes",
            [14] = "armrad",
            [15] = "armdrag",
            [16] = "armllt",
            [17] = "armrl",
            [18] = "armdl",
            [19] = "armjamt",
            [20] = "armsy",
            [21] = "armtide",
            [22] = "armfmkr",
            [23] = "armasy",
            [24] = "armfrt",
            [25] = "armtl",
            [26] = "armgeo",
            [27] = "armbeamer",
            [28] = "armhlt",
            [29] = "armferret",
            [30] = "armclaw",
            [31] = "armjuno",
            [32] = "armfrad",
            [33] = "armadvsol",
            [34] = "armguard"
        }
    end

    if name == "corcv" then
        uDef.buildoptions = {
            [1] = "corsolar",
            [2] = "corwin",
            [3] = "cormstor",
            [4] = "corestor",
            [5] = "cormex",
            [6] = "cormakr",
            [10] = "corlab",
            [11] = "coravp",
            [12] = "corvp",
            [13] = "corap",
            [14] = "cornanotc",
            [15] = "coreyes",
            [16] = "cordrag",
            [17] = "corllt",
            [18] = "corrl",
            [19] = "corrad",
            [20] = "cordl",
            [21] = "corjamt",
            [22] = "corsy",
            [23] = "corexp",
            [24] = "corgeo",
            [25] = "corhllt",
            [26] = "corhlt",
            [27] = "cormaw",
            [28] = "cormadsam",
            [29] = "coradvsol",
            [30] = "corpun"
        }
    end

    if name == "cormuskrat" then
        uDef.buildoptions = {
            [1] = "corsolar",
            [2] = "corwin",
            [3] = "cormstor",
            [4] = "corestor",
            [5] = "cormex",
            [6] = "cormakr",
            [7] = "corlab",
            [8] = "coravp",
            [9] = "corvp",
            [10] = "corap",
            [11] = "cornanotc",
            [12] = "coreyes",
            [13] = "cordrag",
            [14] = "corllt",
            [15] = "corrl",
            [16] = "corrad",
            [17] = "cordl",
            [18] = "corjamt",
            [19] = "corsy",
            [20] = "corexp",
            [21] = "corgeo",
            [22] = "corhllt",
            [23] = "corhlt",
            [24] = "cormaw",
            [25] = "cormadsam",
            [26] = "corfrad",
            [27] = "cortide",
            [28] = "corasy",
            [29] = "cortl",
            [30] = "coradvsol",
            [31] = "corpun"
        }
    end

    if name == "armacv" then
        uDef.buildoptions = {
            [1] = "armadvsol",
            [2] = "armmoho",
            [3] = "armbeamer",
            [4] = "armhlt",
            [5] = "armguard",
            [6] = "armferret",
            [7] = "armcir",
            [8] = "armjuno",
            [9] = "armpb",
            [10] = "armarad",
            [11] = "armveil",
            [12] = "armfus",
            [13] = "armgmm",
            [14] = "armhavp",
            [15] = "armlab",
            [16] = "armavp",
            [17] = "armsd",
            [18] = "armmakr",
            [19] = "armestor",
            [20] = "armmstor",
            [21] = "armageo",
            [22] = "armckfus",
            [23] = "armdl",
            [24] = "armdf",
            [25] = "armvp",
            [26] = "armsy",
            [27] = "armap",
            [28] = "armnanotc",
            [29] = "armamd",
        }
    end

    if name == "coracv" then
        uDef.buildoptions = {
            [1] = "coradvsol",
            [2] = "cormoho",
            [3] = "corvipe",
            [4] = "corhllt",
            [5] = "corpun",
            [6] = "cormadsam",
            [7] = "corerad",
            [8] = "corjuno",
            [9] = "corfus",
            [10] = "corarad",
            [11] = "corshroud",
            [12] = "corsd",
            [13] = "corvp",
            [14] = "corhavp",
            [15] = "coravp",
            [16] = "cormakr",
            [17] = "corestor",
            [18] = "cormstor",
            [19] = "corageo",
            [20] = "corhlt",
            [21] = "cordl",
            [22] = "corlab",
            [23] = "corap",
            [24] = "corsy",
            [25] = "cornanotc",
            [26] = "corfmd",
        }
    end

    ------------------------------
    -- Armada and Cortex Air Split

    -- Air Labs

    if name == "armaap" then
        uDef.buildpic = "ARMHAAP.DDS"
        uDef.objectname = "Units/ARMAAPLAT.s3o"
        uDef.script = "Units/techsplit/ARMHAAP.cob"
        uDef.customparams.buildinggrounddecaltype = "decals/armamsub_aoplane.dds"
        uDef.customparams.buildinggrounddecalsizex = 13
        uDef.customparams.buildinggrounddecalsizey = 13
        uDef.featuredefs.dead["object"] = "Units/armaaplat_dead.s3o"
        uDef.buildoptions = {
            [1] = "armaca",
            [2] = "armseap",			
            [3] = "armsb",
            [4] = "armsfig",
            [5] = "armsehak",
            [6] = "armsaber",
            [7] = "armhvytrans"
        }
        uDef.sfxtypes = {
            explosiongenerators = {
                [1] = "custom:radarpulse_t1_slow",
            },
            pieceexplosiongenerators = {
                [1] = "deathceg2",
                [2] = "deathceg3",
                [3] = "deathceg4",
            },
        }
        uDef.sounds = {
            build = "seaplok1",
            canceldestruct = "cancel2",
            underattack = "warning1",
            unitcomplete = "untdone",
            count = {
                [1] = "count6",
                [2] = "count5",
                [3] = "count4",
                [4] = "count3",
                [5] = "count2",
                [6] = "count1",
            },
            select = {
                [1] = "seaplsl1",
            },
        }
    end

    if name == "coraap" then
        uDef.buildpic = "CORHAAP.DDS"
        uDef.objectname = "Units/CORAAPLAT.s3o"
        uDef.script = "Units/CORHAAP.cob"
        uDef.buildoptions = {
            [1] = "coraca",
            [2] = "corhunt",
            [3] = "corcut",
            [4] = "corsb",
            [5] = "corseap",
            [6] = "corsfig",
            [7] = "corhvytrans",
        }
        uDef.featuredefs.dead["object"] = "Units/coraaplat_dead.s3o"
        uDef.customparams.buildinggrounddecaltype = "decals/coraap_aoplane.dds"
        uDef.customparams.buildinggrounddecalsizex = 6
        uDef.customparams.buildinggrounddecalsizey = 6
        uDef.customparams.sfxtypes = {
            pieceexplosiongenerators = {
                [1] = "deathceg2",
                [2] = "deathceg3",
                [3] = "deathceg4",
            },
        }
        uDef.customparams.sounds = {
            build = "seaplok2",
            canceldestruct = "cancel2",
            underattack = "warning1",
            unitcomplete = "untdone",
            count = {
                [1] = "count6",
                [2] = "count5",
                [3] = "count4",
                [4] = "count3",
                [5] = "count2",
                [6] = "count1",
            },
            select = {
                [1] = "seaplsl2",
            },
        }
    end

    if name == "armap" then
        uDef.buildoptions = {
            [1] = "armca",
            [2] = "armpeep",
            [3] = "armfig",
            [4] = "armthund",
            [5] = "armatlas",
            [6] = "armkam",
        }
    end

    if name == "corap" then
        uDef.buildoptions = {
            [1] = "corca",
            [2] = "corfink",
            [3] = "corveng",
            [4] = "corshad",
            [5] = "corvalk",
            [6] = "corbw",
        }
    end

    -- Air Cons

    if name == "armca" then
        uDef.buildoptions = {
            [1] = "armsolar",
            [2] = "armwin",
            [3] = "armmstor",
            [4] = "armestor",
            [5] = "armmex",
            [6] = "armmakr",
            [7] = "armaap",
            [8] = "armlab",
            [9] = "armvp",
            [10] = "armap",
            [11] = "armnanotc",
            [12] = "armeyes",
            [13] = "armrad",
            [14] = "armdrag",
            [15] = "armllt",
            [16] = "armrl",
            [17] = "armdl",
            [18] = "armjamt",
            [19] = "armsy",
            [20] = "armamex",
            [21] = "armgeo",
            [22] = "armbeamer",
            [23] = "armhlt",
            [24] = "armferret",
            [25] = "armclaw",
            [26] = "armjuno",
            [27] = "armadvsol",
            [30] = "armguard",
            [31] = "armnanotc",
        }
    end

    if name == "corca" then
        uDef.buildoptions = {
            [1] = "corsolar",
            [2] = "corwin",
            [3] = "cormstor",
            [4] = "corestor",
            [5] = "cormex",
            [6] = "cormakr",
            [10] = "corlab",
            [11] = "coraap",
            [12] = "corvp",
            [13] = "corap",
            [14] = "cornanotc",
            [15] = "coreyes",
            [16] = "cordrag",
            [17] = "corllt",
            [18] = "corrl",
            [19] = "corrad",
            [20] = "cordl",
            [21] = "corjamt",
            [22] = "corsy",
            [23] = "corexp",
            [24] = "corgeo",
            [25] = "corhllt",
            [26] = "corhlt",
            [27] = "cormaw",
            [28] = "cormadsam",
            [29] = "coradvsol",
            [30] = "corpun",
            [31] = "cornanotc",
        }
    end

    if name == "armaca" then
        uDef.buildpic = "ARMCSA.DDS"
        uDef.objectname = "Units/ARMCSA.s3o"
        uDef.script = "units/ARMCSA.cob"
        uDef.buildoptions = {
            [1] = "armadvsol",
            [2] = "armmoho",
            [3] = "armbeamer",
            [4] = "armhlt",
            [5] = "armguard",
            [6] = "armferret",
            [7] = "armcir",
            [8] = "armjuno",
            [9] = "armpb",
            [10] = "armarad",
            [11] = "armveil",
            [12] = "armfus",
            [13] = "armgmm",
            [14] = "armhaap",
            [15] = "armlab",
            [16] = "armaap",
            [17] = "armsd",
            [18] = "armmakr",
            [19] = "armestor",
            [20] = "armmstor",
            [21] = "armageo",
            [22] = "armckfus",
            [23] = "armdl",
            [24] = "armdf",
            [25] = "armvp",
            [26] = "armsy",
            [27] = "armap",
            [28] = "armnanotc",
            [29] = "armamd",
        }
    end

    if name == "coraca" then
        uDef.buildpic = "CORCSA.DDS"
        uDef.objectname = "Units/CORCSA.s3o"
        uDef.script = "units/CORCSA.cob"
        uDef.buildoptions = {
            [1] = "coradvsol",
            [2] = "cormoho",
            [3] = "corvipe",
            [4] = "corhllt",
            [5] = "corpun",
            [6] = "cormadsam",
            [7] = "corerad",
            [8] = "corjuno",
            [9] = "corfus",
            [10] = "corarad",
            [11] = "corshroud",
            [12] = "corsd",
            [13] = "corap",
            [14] = "corhaap",
            [15] = "coraap",
            [16] = "cormakr",
            [17] = "corestor",
            [18] = "cormstor",
            [19] = "corageo",
            [20] = "corhlt",
            [21] = "cordl",
            [22] = "corvp",
            [23] = "corlab",
            [24] = "corsy",
            [25] = "cornanotc",
            [26] = "corfmd",
        }
    end
    
    ------------
    -- Sea Split

    -- Sea Labs

	if name == "armhasy" or name == "corhasy" then
		uDef.metalcost = uDef.metalcost - 1200
	end

    if name == "armsy" then
        uDef.buildoptions[8] = "armbeaver"
    end

    if name == "corsy" then
        uDef.buildoptions[8] = "cormuskrat"
    end

    if name == "armasy" then
        uDef.metalcost = uDef.metalcost + 400
        uDef.buildoptions = {
            [1] = "armacsub",
            [2] = "armmship",
            [3] = "armcrus",
            [4] = "armsubk",
            [5] = "armah",
            [6] = "armlship",
            [7] = "armcroc",
            [8] = "armsh",
            [9] = "armanac",
            [10] = "armch",
            [11] = "armmh",
            [12] = "armsjam"
        }

    elseif name == "corasy" then
        uDef.metalcost = uDef.metalcost + 400
        uDef.buildoptions = {		
            [1] = "coracsub",
            [2] = "corcrus",
            [3] = "corshark",
            [4] = "cormship",
            [5] = "corfship",
            [6] = "corah",
            [7] = "corsala",
            [8] = "corsnap",
            [9] = "corsh",
            [10] = "corch",
            [11] = "cormh",
            [12] = "corsjam",
        }
    

    -- Sea Cons

    elseif name == "armcs" then
        uDef.buildoptions = {
            [1] = "armmex",
            [2] = "armvp",
            [3] = "armap",
            [4] = "armlab",
            [5] = "armeyes",
            [6] = "armdl",
            [7] = "armdrag",
            [8] = "armtide",
            [9] = "armuwgeo",
            [10] = "armfmkr",
            [11] = "armuwms",
            [12] = "armuwes",
            [13] = "armsy",
            [14] = "armnanotcplat",
            [15] = "armasy",
            [16] = "armfrad",
            [17] = "armfdrag",
            [18] = "armtl",
            [19] = "armfrt",
            [20] = "armfhlt",
            [21] = "armbeamer",
            [22] = "armclaw",
            [23] = "armferret",
            [24] = "armjuno",
            [25] = "armguard",
        }

    elseif name == "corcs" then
        uDef.buildoptions = {
            [1] = "cormex",
            [2] = "corvp",
            [3] = "corap",
            [4] = "corlab",
            [5] = "coreyes",
            [6] = "cordl",
            [7] = "cordrag",
            [8] = "cortide",
            [9] = "corfmkr",
            [10] = "coruwms",
            [11] = "coruwes",
            [12] = "corsy",
            [13] = "cornanotcplat",
            [14] = "corasy",
            [15] = "corfrad",
            [16] = "corfdrag",
            [17] = "cortl",
            [18] = "corfrt",
            [19] = "cormadsam",
            [20] = "corfhlt",
            [21] = "corhllt",
            [22] = "cormaw",
            [23] = "coruwgeo",
            [24] = "corjuno",
            [30] = "corpun"
        }

    elseif name == "armacsub" then
        uDef.buildoptions = {
            [1] = "armtide",
            [2] = "armuwageo",
            [3] = "armveil",
            [4] = "armarad",
            [5] = "armpb",
            [7] = "armasy",
            [8] = "armguard",
            [9] = "armfhlt",
            [10] = "armhasy",
            [11] = "armfmkr",
            [12] = "armason",
            [13] = "armuwfus",
            [17] = "armfdrag",
            [18] = "armsy",
            [19] = "armuwmme",
            [20] = "armatl",
            [21] = "armkraken",
            [22] = "armfrt",
            [23] = "armuwes",
            [24] = "armuwms",
            [25] = "armhaapuw",
            [26] = "armvp",
            [27] = "armlab",
            [28] = "armap",
            [29] = "armferret",
            [30] = "armcir",
            [31] = "armsd",
            [32] = "armnanotcplat",
            [33] = "armamd",
        }

    elseif name == "coracsub" then
        uDef.buildoptions = {
            [1] = "cortide",
            [2] = "coruwmme",
            [3] = "corshroud",
            [4] = "corarad",
            [5] = "corvipe",
            [6] = "corsy",
            [7] = "corasy",
            [8] = "corhasy",
            [9] = "corfhlt",
            [10] = "corpun",
            [11] = "corason",
            [12] = "coruwfus",
            [13] = "corfmkr",
            [14] = "corfdrag",
            [15] = "corfrt",
            [16] = "coruwes",
            [17] = "coruwms",
            [18] = "coruwageo",
            [19] = "corhaapuw",
            [20] = "coratl",
            [21] = "corsd",
            [22] = "corvp",
            [23] = "corlab",
            [24] = "corsy",
            [25] = "corasy",
            [26] = "cornanotcplat",
            [27] = "corfdoom",
            [28] = "cormadsam",
            [29] = "corerad",
            [30] = "corfmd",
        }
    end

    -- T3 Gantries
    if name == "armshltx" then
        uDef.footprintx = 15
        uDef.footprintz = 15
        uDef.collisionvolumescales = "225 150 205"
        uDef.yardmap = "ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee"
        uDef.objectname = "Units/ARMSHLTXBIG.s3o"
        uDef.script = "Units/techsplit/ARMSHLTXBIG.cob"
        uDef.featuredefs.armshlt_dead.object = "Units/armshltxbig_dead.s3o"
        uDef.featuredefs.armshlt_dead.footprintx = 11
        uDef.featuredefs.armshlt_dead.footprintz = 11
        uDef.featuredefs.armshlt_dead.collisionvolumescales = "155 95 180"
        uDef.customparams.buildinggrounddecalsizex = 18
        uDef.customparams.buildinggrounddecalsizez = 18
    end 

    if name == "corgant" then
        uDef.footprintx = 15
        uDef.footprintz = 15
        uDef.collisionvolumescales = "245 131 245"
        uDef.yardmap = "oooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo"
        uDef.objectname = "Units/CORGANTBIG.s3o"
        uDef.script = "Units/techsplit/CORGANTBIG.cob"
        uDef.featuredefs.dead.object = "Units/corgant_dead.s3o"
        uDef.featuredefs.dead.footprintx = 15
        uDef.featuredefs.dead.footprintz = 15
        uDef.featuredefs.dead.collisionvolumescales = "238 105 238"
        uDef.customparams.buildinggrounddecalsizex = 18
        uDef.customparams.buildinggrounddecalsizez = 18
    end

    if name == "leggant" then
        uDef.footprintx = 15
        uDef.footprintz = 15
        uDef.collisionvolumescales = "245 135 245"
        uDef.yardmap = "oooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo yooeeeeeeeeeooy"
        uDef.objectname = "Units/LEGGANTBIG.s3o"
        uDef.script = "Units/techsplit/LEGGANTBIG.cob"
        uDef.featuredefs.dead.object = "Units/leggant_dead.s3o"
        uDef.featuredefs.dead.footprintx = 15
        uDef.featuredefs.dead.footprintz = 15
        uDef.featuredefs.dead.collisionvolumescales = "145 90 160"
        uDef.customparams.buildinggrounddecalsizex = 18
        uDef.customparams.buildinggrounddecalsizez = 18
    end

    -- Remove lolmech from T3 cons
    if name == "armhaca" or name == "armhack" or name == "armhacv" then
        uDef.buildoptions[24] = ""
    end

    if name == "armhacs" then
        uDef.buildoptions[13] = ""
    end

    if name == "corhaca" or name == "corhack" or name == "corhacv" then
        uDef.buildoptions[25] = ""
        uDef.buildoptions[26] = ""
    end

    if name == "corhacs" then
        uDef.buildoptions[15] = ""
        uDef.buildoptions[16] = ""
    end

    if name == "leghaca" or name == "leghack" or name == "leghacv" then
        uDef.buildoptions[33] = ""
        uDef.buildoptions[34] = ""
    end

    -- remove hovers from com
    if name == "corcom" or name == "armcom" or name == "legcom" then
        uDef.buildoptions[26] = ""
        uDef.buildoptions[27] = ""

    -- T2 labs are priced as t1.5 but require more BP
    elseif name == "armaap" or name == "armasy" or name == "armalab" or name == "armavp"
    or name == "coraap"  or name == "corasy" or name == "coralab" or name == "coravp"
    then
        uDef.metalcost = uDef.metalcost - 1300
        uDef.energycost = uDef.energycost - 5000
        uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100
    
    -- T2 cons are priced as t1.5
    elseif name == "armack" or name == "armacv" or name == "armaca" or name == "armacsub"
    or name == "corack" or name == "coracv" or name == "coraca" or name == "coracsub"
    or name == "legack" or name == "legacv" or name == "legaca"
    then
        uDef.metalcost = uDef.metalcost - 200
        uDef.energycost = uDef.energycost - 2000
        uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
    
    -- Hover cons are priced as t2
    elseif name == "armch" or name == "corch" or name == "legch"
    then
        uDef.metalcost = uDef.metalcost * 2
        uDef.energycost = uDef.energycost * 2
        uDef.buildtime = uDef.buildtime * 2
        uDef.customparams.techlevel = 2
    end

    ----------------------------------------------
    -- T2 mexes upkeep increased, health decreased
    if name == "armmoho" or name == "cormoho" or name == "armuwmme" or name == "coruwmme"
    or name == "legmoho"
    then
        uDef.energyupkeep = 40
        uDef.health = uDef.health - 1200
    elseif name == "cormexp" then
        uDef.energyupkeep = 40
    end

    

    -------------------------------
    -- T3 mobile jammers have radar

    if name == "armaser" or name == "corspec" or name == "legajamk"
    or name == "armjam" or name == "coreter" or name == "legavjam"
    then
        uDef.metalcost = uDef.metalcost + 100
        uDef.energycost = uDef.energycost + 1250
        uDef.buildtime = uDef.buildtime + 3800
        uDef.radardistance = 2500
        uDef.sightdistance = 1000
    end

    if name == "armantiship" or name == "corantiship" then
        uDef.radardistancejam = 450
    end

    ----------------------------
    -- T2 ship jammers get radar

    if name == "armsjam" or name == "corsjam" then
        uDef.metalcost = uDef.metalcost + 90
        uDef.energycost = uDef.energycost + 1050
        uDef.buildtime = uDef.buildtime + 3000
        uDef.radarDistance = 2200
        uDef.sightdistance = 900
    end

    -----------------------------------
    -- Pinpointers are T3 radar/jammers

    if name == "armtarg" or name == "cortarg" or name == "legtarg"
    or name == "armfatf" or name == "corfatf"
    then
        uDef.radardistance = 5000
        uDef.sightdistance = 1200
        uDef.radardistancejam = 900
    end
    
    -----------------------------
    -- Correct Tier for Announcer

    if name == "armch" or name == "armsh" or name == "armanac" or name == "armah" or name == "armmh"
    or name == "armcsa" or name == "armsaber" or name == "armsb" or name == "armseap" or name == "armsfig" or name == "armsehak" or name == "armhvytrans"
    or name == "corch" or name == "corsh" or name == "corsnap" or name == "corah" or name == "cormh" or name == "corhal"
    or name == "corcsa" or name == "corcut" or name == "corsb" or name == "corseap" or name == "corsfig" or name == "corhunt" or name == "corhvytrans"
    then
        uDef.customparams.techlevel = 2
    
    elseif name == "armsnipe" or name == "armfboy" or name == "armaser" or name == "armdecom" or name == "armscab"
    or name == "armbull" or name == "armmerl" or name == "armmanni" or name == "armyork" or name == "armjam"
    or name == "armserp" or name == "armbats" or name == "armepoch" or name == "armantiship" or name == "armaas"
    or name == "armhawk" or name == "armpnix" or name == "armlance" or name == "armawac" or name == "armdfly" or name == "armliche" or name == "armblade" or name == "armbrawl" or name == "armstil"
    or name == "corsumo" or name == "cordecom" or name == "corsktl" or name == "corspec"
    or name == "corgol" or name == "corvroc" or name == "cortrem" or name == "corsent" or name == "coreter" or name == "corparrow"
    or name == "corssub" or name == "corbats" or name == "corblackhy" or name == "corarch" or name == "corantiship"
    or name == "corape" or name == "corhurc" or name == "cortitan" or name == "corvamp" or name == "corseah" or name == "corawac" or name == "corcrwh"
    then
        uDef.customparams.techlevel = 3
    end		


    -----------------------------------------
    -- Hovers, Sea Planes and Amphibious Labs

    if name == "armch" then
        uDef.buildoptions = {
            [1] = "armadvsol",
            [2] = "armmoho",
            [3] = "armbeamer",
            [4] = "armhlt",
            [5] = "armguard",
            [6] = "armferret",
            [7] = "armcir",
            [8] = "armjuno",
            [9] = "armpb",
            [10] = "armarad",
            [11] = "armveil",
            [12] = "armfus",
            [13] = "armgmm",
            [14] = "armhavp",
            [15] = "armlab",
            [16] = "armsd",
            [17] = "armmakr",
            [18] = "armestor",
            [19] = "armmstor",
            [20] = "armageo",
            [21] = "armckfus",
            [22] = "armdl",
            [23] = "armdf",
            [24] = "armvp",
            [25] = "armsy",
            [26] = "armap",
            [27] = "armavp",
            [28] = "armasy",
            [29] = "armhasy",
            [30] = "armtl",
            [31] = "armason",
            [32] = "armdrag",
            [33] = "armfdrag",
            [34] = "armuwmme",
            [35] = "armguard",
            [36] = "armnanotc",
            [37] = "armamd",
        }

    elseif name == "corch" then
        uDef.buildoptions = {
            [1] = "coradvsol",
            [2] = "cormoho",
            [3] = "corvipe",
            [4] = "corhllt",
            [5] = "corpun",
            [6] = "cormadsam",
            [7] = "corerad",
            [8] = "corjuno",
            [9] = "corfus",
            [10] = "corarad",
            [11] = "corshroud",
            [12] = "corsd",
            [13] = "corvp",
            [14] = "corhavp",
            [15] = "coravp",
            [16] = "cormakr",
            [17] = "corestor",
            [18] = "cormstor",
            [19] = "corageo",
            [20] = "cordl",
            [21] = "coruwmme",
            [22] = "cordrag",
            [23] = "corfdrag",
            [24] = "corason",
            [25] = "corlab",
            [26] = "corap",
            [27] = "corsy",
            [28] = "corasy",
            [29] = "corhlt",
            [30] = "cortl",
            [31] = "corhasy",
            [32] = "corpun",
            [33] = "corfmd",
        }
    end
    -- Seaplane Platforms removed, become T2 air labs. 
    -- T2 air labs have sea variants
    -- Made by hover cons and enhanced ship cons 
    -- Enhanced ships given seaplanes instead of static AA
    -- Tech Split Balance
	if name == "corthud" then 
		uDef.speed = 54
		uDef.weapondefs.arm_ham.range = 300
		uDef.weapondefs.arm_ham.predictboost = 0.8
		uDef.weapondefs.arm_ham.damage = {
			default = 150,
			subs = 50,
			vtol = 15,
		}
		uDef.weapondefs.arm_ham.reloadtime = 1.73
		uDef.weapondefs.arm_ham.areaofeffect = 51
	end

	if name == "armwar" then
		uDef.speed = 56
		uDef.weapondefs.armwar_laser.range = 290
	end

	if name == "corstorm" then
		uDef.speed = 42
		uDef.weapondefs.cor_bot_rocket.accuracy = 150
		uDef.weapondefs.cor_bot_rocket.range = 600
		uDef.weapondefs.cor_bot_rocket.reloadtime = 5.5
		uDef.weapondefs.cor_bot_rocket.damage.default = 198
		uDef.health = 250
	end

	if name == "armrock" then
		uDef.health =  240
        uDef.speed =  48
        uDef.weapondefs.arm_bot_rocket.reloadtime = 5.4
		uDef.weapondefs.arm_bot_rocket.range = 575
		uDef.weapondefs.arm_bot_rocket.damage.default = 190
	end

	if name == "armhlt" then
		uDef.health = 4640
		uDef.metalcost = 535
		uDef.energycost = 5700
		uDef.buildtime = 13700
		uDef.weapondefs.arm_laserh1.range = 750
		uDef.weapondefs.arm_laserh1.reloadtime = 2.9
		uDef.weapondefs.arm_laserh1.damage = {
			commanders = 801,
			default = 534,
			vtol = 48,
		}
	end

	if name == "corhlt" then
		uDef.health = 4640
		uDef.metalcost = 580
		uDef.energycost = 5700
		uDef.buildtime = 13800
		uDef.weapondefs.cor_laserh1.range = 750
		uDef.weapondefs.cor_laserh1.reloadtime = 1.8
		uDef.weapondefs.cor_laserh1.damage = {
			commanders = 540,
			default = 360,
			vtol = 41,
		}
	end

	if name == "armart" then
		uDef.speed = 65
		uDef.turnrate = 210
		uDef.maxacc = 0.018
		uDef.maxdec = 0.081
		uDef.weapondefs.tawf113_weapon.accuracy = 150
		uDef.weapondefs.tawf113_weapon.range = 830
		uDef.weapondefs.tawf113_weapon.damage = {
			default = 182,
			subs = 61,
			vtol = 20,
		}
		uDef.weapons[1].maxangledif = 120
	end

	if name == "corwolv" then
		uDef.speed = 62
		uDef.turnrate = 250
		uDef.maxacc = 0.015
		uDef.maxdec = 0.0675
		uDef.weapondefs.corwolv_gun.accuracy = 150
		uDef.weapondefs.corwolv_gun.range = 850
		uDef.weapondefs.corwolv_gun.damage = {
			default = 375,
			subs = 95,
			vtol = 38,
		}
		uDef.weapons[1].maxangledif = 120
	end

	if name == "armmart" then
		uDef.metalcost = 400
		uDef.energycost = 5500
		uDef.buildtime = 7500
		uDef.speed = 47
		uDef.turnrate = 120
		uDef.maxacc = 0.005
		uDef.health = 750
		uDef.weapondefs.arm_artillery.accuracy = 75
		uDef.weapondefs.arm_artillery.areaofeffect = 60
		uDef.weapondefs.arm_artillery.hightrajectory = 1
		uDef.weapondefs.arm_artillery.range = 1050
		uDef.weapondefs.arm_artillery.reloadtime = 3.05
        uDef.weapondefs.arm_artillery.weaponvelocity = 500
		uDef.weapondefs.arm_artillery.damage = {
			default = 488,
			subs = 163,
			vtol = 49,
		}
		uDef.weapons[1].maxangledif = 120
	end

	if name == "cormart" then
		uDef.metalcost = 600
		uDef.energycost = 6600
		uDef.buildtime = 6500
		uDef.speed = 45
		uDef.turnrate = 100
		uDef.maxacc = 0.005
		uDef.weapondefs.cor_artillery = {
			accuracy = 75,
			areaofeffect = 75,
			avoidfeature = false,
			cegtag = "arty-heavy",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-large-bomb",
			gravityaffected = "true",
			mygravity = 0.1,
			hightrajectory = 1,
			impulsefactor = 0.123,
			name = "PlasmaCannon",
			noselfdamage = true,
			range = 1150,
			reloadtime = 5,
			soundhit = "xplomed4",
			soundhitwet = "splsmed",
			soundstart = "cannhvy2",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 349.5354,
			damage = {
				default = 1200,
				subs = 400,
				vtol = 120,
			},
		}
		uDef.weapons[1].maxangledif = 120
	end

	if name == "armfido" then
		uDef.speed = 74
		uDef.weapondefs.bfido.range = 500
		uDef.weapondefs.bfido.weaponvelocity = 400
	end

	if name == "cormort" then
		uDef.metalcost = 400
		uDef.health = 800
		uDef.speed = 47
		uDef.weapondefs.cor_mort.range = 650
		uDef.weapondefs.cor_mort.damage = {
			default = 250,
			subs = 83,
			vtol = 25,
		}
		uDef.weapondefs.cor_mort.reloadtime = 3
		uDef.weapondefs.cor_mort.areaofeffect = 64
	end

	if name == "corhrk" then
		uDef.turnrate = 600
		uDef.weapondefs.corhrk_rocket.range = 900
		uDef.weapondefs.corhrk_rocket.weaponvelocity = 600
		uDef.weapondefs.corhrk_rocket.flighttime = 22
		uDef.weapondefs.corhrk_rocket.reloadtime = 8
		uDef.weapondefs.corhrk_rocket.turnrate = 30000
		uDef.weapondefs.corhrk_rocket.weapontimer = 4
		uDef.weapondefs.corhrk_rocket.damage = {
			default = 1200,
			subs = 400,
			vtol = 120,
		}
		uDef.weapondefs.corhrk_rocket.areaofeffect = 128
		uDef.weapons[1].maxangledif = 120
		uDef.weapons[1].maindir = "0 0 1"
	end

	if name == "armsptk" then
		uDef.metalcost = 500
		uDef.speed = 43
		uDef.health = 450
		uDef.turnrate = 600
		uDef.weapondefs.adv_rocket.range = 775
		uDef.weapondefs.adv_rocket.trajectoryheight = 1
		uDef.weapondefs.adv_rocket.customparams.overrange_distance = 800
		uDef.weapondefs.adv_rocket.weapontimer = 8
		uDef.weapondefs.adv_rocket.flighttime = 4
		uDef.weapons[1].maxangledif = 120
		uDef.weapons[1].maindir = "0 0 1"
	end

	if name == "corshiva" then
		uDef.speed = 55
		uDef.weapondefs.shiva_gun.range = 475
		uDef.weapondefs.shiva_gun.areaofeffect = 180
		uDef.weapondefs.shiva_gun.weaponvelocity = 372
		uDef.weapondefs.shiva_rocket.areaofeffect = 96
		uDef.weapondefs.shiva_rocket.range = 900
		uDef.weapondefs.shiva_rocket.reloadtime = 14
		uDef.weapondefs.shiva_rocket.damage.default = 1500
	end

	if name == "armmar" then
		uDef.health = 3920
		uDef.weapondefs.armmech_cannon.areaofeffect = 48
		uDef.weapondefs.armmech_cannon.range = 275
		uDef.weapondefs.armmech_cannon.reloadtime = 1.25
		uDef.weapondefs.armmech_cannon.damage = {
			default = 525,
			vtol = 134,
		}
	end

	if name == "corban" then
		uDef.speed = 69
		uDef.turnrate = 500
		uDef.weapondefs.banisher.areaofeffect = 180
		uDef.weapondefs.banisher.range = 400
	end

	if name == "armcroc" then
		uDef.turnrate = 270
		uDef.weapondefs.arm_triton.reloadtime = 1.5
		uDef.weapondefs.arm_triton.damage = {
			default = 250,
			subs = 111,
			vtol = 44
		}
		uDef.weapons[2] = {
			def = "",
		}
	end

    --Tech Split Hotfixes 3
    
    if name == "armhack" or name == "armhacv" or name == "armhaca" then
        uDef.buildoptions[40] = "armnanotc" 
    end

    if name == "armhacs" then
        uDef.buildoptions[41] = "armnanotcplat"
    end

    if name == "corhack" or name == "corhacv" or name == "corhaca" then
        uDef.buildoptions[40] = "cornanotc"
    end

    if name == "corhacs" then
        uDef.buildoptions[41] = "cornanotcplat"
    end

	if name == "correap" then 
		uDef.speed = 76
		uDef.turnrate = 250
		uDef.weapondefs.cor_reap.areaofeffect = 92
		uDef.weapondefs.cor_reap.damage = {
			default = 150,
			vtol = 48,
		}
		uDef.weapondefs.cor_reap.range = 305
	end

	if name == "armbull" then
		uDef.health = 6000
		uDef.metalcost = 1100
		uDef.weapondefs.arm_bull.range = 400
		uDef.weapondefs.arm_bull.damage = {
			default = 600,
			subs = 222,
			vtol = 67
		}
		uDef.weapondefs.arm_bull.reloadtime = 2
		uDef.weapondefs.arm_bull.areaofeffect = 96
	end

	if name == "corsumo" then
		uDef.weapondefs.corsumo_weapon.range = 750
		uDef.weapondefs.corsumo_weapon.damage = {
			commanders = 350,
            default = 700,
			vtol = 165,
		}
		uDef.weapondefs.corsumo_weapon.reloadtime = 1
	end

	if name == "corgol" then 
		uDef.speed = 37
		uDef.weapondefs.cor_gol.damage = {
			default = 1600,
			subs = 356,
			vtol = 98,
		}
		uDef.weapondefs.cor_gol.reloadtime = 4
		uDef.weapondefs.cor_gol.range = 700
	end

	if name == "armguard" then 
		uDef.health = 6000
		uDef.metalcost = 800
		uDef.energycost = 8000
		uDef.buildtime = 16000
		uDef.weapondefs.plasma.areaofeffect = 150
		uDef.weapondefs.plasma.range = 1000
		uDef.weapondefs.plasma.reloadtime = 2.3
		uDef.weapondefs.plasma.weaponvelocity = 550 
		uDef.weapondefs.plasma.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
		uDef.weapondefs.plasma_high.areaofeffect = 150
		uDef.weapondefs.plasma_high.range = 1000
		uDef.weapondefs.plasma_high.reloadtime = 2.3
		uDef.weapondefs.plasma_high.weaponvelocity = 700
		uDef.weapondefs.plasma_high.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
	end

	if name == "corpun" then
		uDef.health = 6400
		uDef.metalcost = 870
		uDef.energycost = 8700
		uDef.buildtime = 16400
		uDef.weapondefs.plasma.areaofeffect = 180
		uDef.weapondefs.plasma.range = 1020
		uDef.weapondefs.plasma.reloadtime = 2.3
		uDef.weapondefs.plasma.weaponvelocity = 550
		uDef.weapondefs.plasma.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
		uDef.weapondefs.plasma_high.areaofeffect = 180
		uDef.weapondefs.plasma_high.range = 1020
		uDef.weapondefs.plasma_high.reloadtime = 2.3
		uDef.weapondefs.plasma_high.weaponvelocity = 700
		uDef.weapondefs.plasma_high.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
	end

    if name == "armpb" then
        uDef.health = 3360
        uDef.weapondefs.armpb_weapon.range = 500
        uDef.weapondefs.armpb_weapon.reloadtime = 1.2
    end

    if name == "corvipe" then
        uDef.health = 3600
        uDef.weapondefs.vipersabot.areaofeffect = 96
        uDef.weapondefs.vipersabot.edgeeffectiveness = 0.8
        uDef.weapondefs.vipersabot.range = 480
        uDef.weapondefs.vipersabot.reloadtime = 3
    end




-- Legion Update



--T2 labs
if name == "legalab" then
    uDef.buildoptions = {
        [1] = "legack",
        [2] = "legadvaabot",
        [3] = "legstr",
        [4] = "legshot",
        [5] = "leginfestor",
        [6] = "legamph",
        [7] = "legsnapper",
        [8] = "legbart",
        [9] = "leghrk",
        [10] = "legaspy",
        [11] = "legaradk",
    }
end

if name == "legavp" then
    uDef.buildoptions = {
        [1] = "legacv",
        [2] = "legch",
        [3] = "legavrad",
        [4] = "legsh",
        [5] = "legmrv",
        [6] = "legfloat",
        [7] = "legaskirmtank",
        [8] = "legamcluster",
        [9] = "legvcarry",
        [10] = "legner",
        [11] = "legmh",
        [12] = "legah"
    }
end

-- Placeholder: Legion T2 air is cor seaplanes
if name == "legaap" then
    uDef.buildoptions = {
        [1] = "legaca",
        [2] = "corhunt",
        [3] = "corcut",
        [4] = "corsb",
        [5] = "corseap",
        [6] = "corsfig",
        [7] = "corhvytrans",
    }
end

if name == "legaap" or name == "legasy" or name == "legalab" or name == "legavp"
then
        uDef.metalcost = uDef.metalcost - 1300
        uDef.energycost = uDef.energycost - 5000
        uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100
end

if name == "legch"
then
    uDef.metalcost = uDef.metalcost * 2
    uDef.energycost = uDef.energycost * 2
    uDef.buildtime = uDef.buildtime * 2
    uDef.customparams.techlevel = 2
end


-- T1 Cons


if name == "legck" then
    uDef.buildoptions = {
        [1]  = "legsolar",
        [2]  = "legwin",
        [3]  = "leggeo",
        [4]  = "legmstor",
        [5]  = "legestor",
        [6]  = "legmex",
        [7]  = "legeconv",
        [9]  = "leglab",
        [10] = "legalab",
        [11] = "legvp",
        [12] = "legap",
        [13] = "legnanotc",
        [14] = "legeyes",
        [15] = "legrad",
        [16] = "legdrag",
        [17] = "leglht",
        [18] = "legrl",
        [19] = "legctl",
        [20] = "legjam",
        [21] = "corsy",
        [22] = "legadvsol",
        [23] = "legmext15",
        [24] = "legcluster",
        [25] = "legrhapsis",
        [26] = "legmg",
        [27] = "legdtr",
        [28] = "leghive",
        [29] = "legjuno",
    }
end

if name == "legca" then
    uDef.buildoptions = {
        [1]  = "legsolar",
        [2]  = "legwin",
        [3]  = "leggeo",
        [4]  = "legmstor",
        [5]  = "legestor",
        [6]  = "legmex",
        [7]  = "legeconv",
        [9]  = "leglab",
        [10] = "legaap",
        [11] = "legvp",
        [12] = "legap",
        [13] = "legnanotc",
        [14] = "legeyes",
        [15] = "legrad",
        [16] = "legdrag",
        [17] = "leglht",
        [18] = "legrl",
        [19] = "legctl",
        [20] = "legjam",
        [21] = "corsy",
        [22] = "legadvsol",
        [23] = "legmext15",
        [24] = "legcluster",
        [25] = "legrhapsis",
        [26] = "legmg",
        [27] = "legdtr",
        [28] = "leghive",
        [29] = "legjuno",
    }
end

if name == "legcv" then
    uDef.buildoptions = {
        [1]  = "legsolar",
        [2]  = "legwin",
        [3]  = "leggeo",
        [4]  = "legmstor",
        [5]  = "legestor",
        [6]  = "legmex",
        [7]  = "legeconv",
        [9]  = "leglab",
        [10] = "legavp",
        [11] = "legvp",
        [12] = "legap",
        [13] = "legnanotc",
        [14] = "legeyes",
        [15] = "legrad",
        [16] = "legdrag",
        [17] = "leglht",
        [18] = "legrl",
        [19] = "legctl",
        [20] = "legjam",
        [21] = "corsy",
        [22] = "legadvsol",
        [23] = "legmext15",
        [24] = "legcluster",
        [25] = "legrhapsis",
        [26] = "legmg",
        [27] = "legdtr",
        [28] = "leghive",
        [29] = "legjuno",
    }
end

if name == "legotter" then 
    uDef.buildoptions = {
        [1]  = "legsolar",
        [2]  = "legwin",
        [3]  = "leggeo",
        [4]  = "legmstor",
        [5]  = "legestor",
        [6]  = "legmex",
        [7]  = "legeconv",
        [9]  = "leglab",
        [10] = "legavp",
        [11] = "legvp",
        [12] = "legap",
        [13] = "legnanotc",
        [14] = "legeyes",
        [15] = "legrad",
        [16] = "legdrag",
        [17] = "leglht",
        [18] = "legrl",
        [19] = "legctl",
        [20] = "legjam",
        [21] = "corsy",
        [22] = "legadvsol",
        [23] = "legmext15",
        [24] = "legcluster",
        [25] = "legrhapsis",
        [26] = "legmg",
        [27] = "legdtr",
        [28] = "leghive",
        [29] = "legtide",
        [30] = "legtl",
        [31] = "legfrad", 
        [32] = "corasy",
        [33] = "legjuno",
    }
end
--------------------------
-- Legion Air Placeholders

if name == "legch" then 
    uDef.buildoptions = {
        [1] = "legadvsol",
        [2] = "legmoho",
        [3] = "legapopupdef",
        [4] = "legmg",
        [5] = "legrhapsis",
        [6] = "leglupara",
        [7] = "legjuno",
        [8] = "leghive",
        [9] = "legfus",
        [10] = "legarad",
        [11] = "legajam",
        [12] = "legsd",
        [13] = "leglab",
        [14] = "legavp",
        [15] = "leghavp",
        [16] = "legcluster",
        [17] = "legeconv",
        [18] = "legageo",
        [19] = "legrampart",
        [20] = "legmstor",
        [21] = "legestor",
        [22] = "legcluster",
        [24] = "legmg",
        [25] = "legdl",
        [26] = "legvp",
        [27] = "legap",
        [28] = "corsy",
        [29] = "legnanotc",
        [30] = "coruwmme",
        [31] = "legtl",
        [32] = "corasy",
    }
end

if name == "legacv" then
    uDef.buildoptions = {
        [1] = "legadvsol",
        [2] = "legmoho",
        [3] = "legapopupdef",
        [4] = "legmg",
        [5] = "legrhapsis",
        [6] = "leglupara",
        [7] = "legjuno",
        [8] = "leghive",
        [9] = "legfus",
        [10] = "legarad",
        [11] = "legajam",
        [12] = "legsd",
        [13] = "leglab",
        [14] = "legavp",
        [15] = "leghavp",
        [16] = "legcluster",
        [17] = "legeconv",
        [18] = "legageo",
        [19] = "legrampart",
        [20] = "legmstor",
        [21] = "legestor",
        [22] = "legcluster",
        [24] = "legmg",
        [25] = "legdl",
        [26] = "legvp",
        [27] = "legap",
        [28] = "corsy",
        [29] = "legnanotc",
    }
end

if name == "legack" then
    uDef.buildoptions = {
        [1] = "legadvsol",
        [2] = "legmoho",
        [3] = "legapopupdef",
        [4] = "legmg",
        [5] = "legrhapsis",
        [6] = "leglupara",
        [7] = "legjuno",
        [8] = "leghive",
        [9] = "legfus",
        [10] = "legarad",
        [11] = "legajam",
        [12] = "legsd",
        [13] = "leglab",
        [14] = "legalab",
        [15] = "leghalab",
        [16] = "legcluster",
        [17] = "legeconv",
        [18] = "legageo",
        [19] = "legrampart",
        [20] = "legmstor",
        [21] = "legestor",
        [22] = "legcluster",
        [24] = "legmg",
        [25] = "legdl",
        [26] = "legvp",
        [27] = "legap",
        [28] = "corsy",
        [29] = "legnanotc",
    }
end

if name == "legaca" then 
    uDef.buildpic = "CORCSA.DDS"
    uDef.objectname = "Units/CORCSA.s3o"
    uDef.script = "Units/CORCSA.cob"
    uDef.buildoptions = {
        [1] = "legadvsol",
        [2] = "legmoho",
        [3] = "legapopupdef",
        [4] = "legmg",
        [5] = "legrhapsis",
        [6] = "leglupara",
        [7] = "legjuno",
        [8] = "leghive",
        [9] = "legfus",
        [10] = "legarad",
        [11] = "legajam",
        [12] = "legsd",
        [13] = "leglab",
        [14] = "legaap",
        [15] = "leghaap",
        [16] = "legcluster",
        [17] = "legeconv",
        [18] = "legageo",
        [19] = "legrampart",
        [20] = "legmstor",
        [21] = "legestor",
        [22] = "legcluster",
        [24] = "legmg",
        [25] = "legdl",
        [26] = "legvp",
        [27] = "legap",
        [28] = "corsy",
        [29] = "legnanotc",
    }
end 


    return uDef
end

return {
    techsplitTweaks = techsplitTweaks,
}