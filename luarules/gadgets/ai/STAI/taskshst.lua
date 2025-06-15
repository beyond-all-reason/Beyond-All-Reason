TasksHST = class(Module)

function TasksHST:Name()
	return "TasksHST"
end

function TasksHST:internalName()
	return "taskshst"
end

function TasksHST:Init()
	self.DebugEnabled = false
	self.roles = {}
	self.labs = {}
	self:startRolesParams()
	self:startLabsParams()
end



function TasksHST:startLabsParams()
	local M = self.ai.ecohst.Metal
	local E = self.ai.ecohst.Energy
	self.labs.t1postmode={
		{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 1, mtype = 5, max = 3,},
			wave = 1},
		{category = 'rezs',
			economy = function()
				return true
			end,
			numeric = {min = 10,  max = 10,},
			wave = 2},
		{category = 'scouts',
			economy = function()
				return true
			end,
			numeric = {min = 5,max = 10},
			wave = 5},
		{category = 'breaks',
			economy = function()
				return self.ai.ecohst.Metal.full > 0.9 and self.ai.ecohst.Energy.full > 0.5
			end,
			numeric = {max = 40},
			wave = 5},
	}
	self.labs.premode = {
		{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 1, mtype = nil, max = 3,},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 20},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end

			},

		}
	self.labs.amphibiousComplex = {
		{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 1, mtype = nil, max = 3,},
			wave = 1},
		{category = 'amphibious',
			economy = function()
				return true
			end,
			numeric = {min = 0,max = 20},
			wave = 5},
		{category = 'heavyAmphibious',
			economy = function()
				return true
			end,
			numeric = {min = 0,max = 20},
			wave = 5},
		{category = 'wartechs',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = nil,max = 1},
			wave = 1},
				--decoy etc

		}
	self.labs.default = {
			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 1, mtype = 5, max = 2,},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 20},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end

			},

			
			{category = 'scouts',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 10,max = 2},
			wave = 2},


			{category = 'raiders',
			economy = function()
				if E.income > 400 then
					return math.random() > 0.66
				end
				return  ( true)
			end,
			numeric = {min = 1,max = 20},
			wave = 10},


			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 3,mtype = nil,max = 7},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 45},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end,

			},

			{category = 'battles',
			economy = function()
				return true
			end,
			numeric = {min = 3},
			special = function(_,soldier,utype)
				if self.ai.ecohst.Metal.full > 0.5 and type(self.ai.armyhst.battles[soldier]) == 'string' then
					return self.ai.armyhst.battles[soldier] ,self.game:GetTypeByName(self.ai.armyhst.battles[soldier])
				end
				return soldier,utype
			end,
            wave = 5},


			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 3,mtype = 6,max = 7},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 45},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end

			},

			{category = 'artillerys',
			economy = function(_,U)
				--local ut = self.ai.armyhst.unitTable[U]
				--return M.income > ut.techLevel * 400
				return true
			end,
			numeric = {min = 3,mtype = 10,max = 10},
			wave = 2},

			{category = 'rezs',
			economy = function()
				if E.income > 100 then
					return true
				end
			end,
			numeric = {min = 1,  max = 3,},
			wave = 1},

			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 3,mtype = nil,max = 7},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 45},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end

			},

			{category = 'breaks',
			economy = function()
				return self.ai.ecohst.Metal.full > 0.1 and self.ai.ecohst.Energy.full > 0.3
			end,
			numeric = {min = 0,max = 2},
			wave = 2},


			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 3,mtype = nil,max = 7},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 45},
			wave =  function()
				return self.ai.engineerhst.engineerNeeded
			end

			},

			{category = 'antiairs',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 7,max = 8},
			wave = 2},


			{category = 'amptechs',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 7,max = 5},
			wave = 1},
			 --amphibious builders

			{category = 'jammers',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = nil,max = 1},
			wave = 1},


			{category = 'radars',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = nil,max = 1},
			wave = 1},


			{category = 'airgun',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 5,max = 10},
			wave = 5},


			{category = 'bomberairs',
			economy = function()
				return true
			end,
			numeric = {min = 10,mtype = nil,max = 20},
			wave = 10},


			{category = 'fighterairs',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 5,max = 10},
            wave = 5},


			{category = 'paralyzers',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 10,max = 5},
			wave = 3},
			 --have paralyzer weapon


			{category = 'wartechs',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = nil,max = 1},
            wave = 1},
			 --decoy etc

			{category = 'techs',
			economy = function()
				return true
			end,
			numeric = {min = 3,mtype = nil,max = 5},
			wave = 1},

			{category = 'engineers',
			economy = function()
				return true
			end, --help builders and build thinghs
			numeric = {min = 1,max = 45},
			wave = function()
				return self.ai.engineerhst.engineersNeeded
			end,

			},

			{category = 'subkillers',
			economy = function()
				return true
			end,
			numeric = {min = 1,mtype = 7,max = 10},
            wave = 3},
			 -- submarine weaponed

			{category = 'breaks',
			economy = function()
				return self.ai.ecohst.Metal.full > 0.7 and self.ai.ecohst.Energy.full > 0.7
			end,
			numeric = {max = 40},
			wave = 10},


			{category = 'amphibious',
			economy = function()
				return true
			end,
			numeric = {min = 0,mtype = 7,max = 20},
            wave = 5},
			 -- weapon amphibious

			{category = 'spiders',
			economy = function()
				return true
			end,
			numeric = {mtype = nil,max = 15},
			wave = 10},
			 -- all terrain spider


--[[
--
			{category = 'transports',
			economy = function()
				return true
			end,
			1,
			nil,
			nil},

--
			{category = 'spys',
			economy = function()
				return true
			end,
			1,
			nil,
			1},
			 -- spy bot
--
			{category = 'miners',
			economy = function()
				return true
			end,
			1,
			nil,
			nil},

--
			{category = 'antinukes',
			economy = function()
				return true
			end,
			1,
			nil,
			nil},

--
			{category = 'crawlings',
			economy = function()
				return true
			end,
			1,
			nil,
			1},

--
			{category = 'cloakables',
			economy = function()
				return true
			end,
			0,
			0,
			10},
]]
}
end

function TasksHST:startRolesParams()
	local M = self.ai.ecohst.Metal
	local E = self.ai.ecohst.Energy
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------

	self.roles.default = {
		{ 	category = 'factoryMobilities' ,
			economy = function(_,param,name)--ecofunc()
						return M.income > 8 and E.income > 30
					end,
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,},

		{ 	category = '_wind_' ,
			economy = function(_,param,name)--ecofunc()
					return  ((E.full < 0.5 or E.income < E.usage  )  or E.income < 30) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true},

		{ 	category = '_tide_' ,
			economy = function(_,param,name)--ecofunc()
					return ((E.full < 0.5 or E.income < E.usage )  or E.income < 30) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true},

		{ 	category = '_solar_' ,
			economy = function(_,param,name)--ecofunc()
					return ((E.full < 0.5 or E.income < E.usage  )  or E.income < 40 ) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_mstor_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.3  and M.full > 0.75 and M.income > 20 and E.income > 200
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_estor_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.9 and E.income > 400  and M.full > 0.1
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_convs_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > E.usage * 1.25 and E.full > 0.9 and  E.income > 600
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_mex_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_nano_' ,
			economy = function(_,param,name)--ecofunc()
					return (E.full > 0.3  and M.full > 0.3 and M.income > 10 and E.income > 100) or
					(self.ai.tool:countMyUnit({name}) == 0 and (M.income > 10 and E.income > 60 ))
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },

		{ 	category = '_aa1_' ,
			economy = function(_,param,name)--ecofunc()
					return  E.full > 0.1 and E.full < 0.5
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_aa1_'}} ,
	        special = true ,},

		{ 	category = '_flak_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.1 and E.full < 0.5
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_flak_'}} ,
			special = true } , --specialFilter

		{ 	category = '_specialt_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 350 and M.income > 25 
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots,min = 50,neighbours = {'_specialt_'}} ,
	        },

		{ 	category = '_fus_' ,
			economy = function(_,param,name)--ecofunc()
					return ( E.income < E.usage ) or E.full < 0.25
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_'}} ,
			special = true } , --specialFilter

		{ 	category = '_popup1_' ,
			economy = function(_,param,name)--ecofunc()
					return (E.income > 200 and M.income > 25  )
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.trampledCells,min = 50,neighbours = {'_popup2_','_popup1_'}} ,
	        },

		{ 	category = '_popup2_' ,
			economy = function(_,param,name)--ecofunc()
					return  true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots,min = 50,neighbours = {'_popup2_'}} ,
	        },

		{ 	category = '_heavyt_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 500 and M.income > 30 and M.full > 0.1
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots, min = 50 , neighbours = {'_heavyt_','_laser2_'}} ,
	        },

		{ 	category = '_jam_' ,
			economy = function(_,param,name)--ecofunc()
					return M.full > 0.5 and M.income > 50 and E.income > 1000
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 100,neighbours = {'_jam_'}} ,
	        },

		{ 	category = '_radar_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,max = 1000,neighbours = {'_radar_'}} ,
	        },

		{ 	category = '_geo_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 100 and M.income > 15 and E.full > 0.3 and M.full > 0.2
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_silo_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 8000 and M.income > 100 and E.full > 0.5 and M.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_antinuke_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 4000 and M.income > 75
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_sonar_' ,
			economy = function(_,param,name)--ecofunc()
					return M.full > 0.3 and M.income > 15 and E.income > 100
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_sonar_'}} ,
	        },

		{ 	category = '_shield_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 8000 and M.income > 100 and E.full > 0.5 and M.full > 0.5
				end,--economicParameters
	        numeric = 3,--numericalParameter
			location = {categories = {'_nano_'},min = 50,neighbours = {'_shield_'}} ,
			duplicate = false , --duplicateFilter
	        },

-- 		{ 	category = '_juno_' ,			economy = true,true,1},
		{ 	category = '_laser2_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 2000 and M.income > 50 and E.full > 0.5 and M.full > 0.3
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots,min = 50,neighbours = {'_laser2_'}}
	        } ,


		{ 	category = '_lol_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 15000 and M.income > 200 and E.full > 0.8 and M.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50}
			},

		{ 	category = '_plasma_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 5000 and M.income > 100 and E.full > 0.5 and M.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 2 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },

		{ 	category = '_torpedo1_' ,
			economy = function(_,param,name)--ecofunc()
					return (E.income > 20 and M.income > 2 and M.full < 0.5)
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_torpedo1_','_torpedo2_'}}
			},

		{ 	category = '_torpedo2_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 100 and M.income > 15 and M.full > 0.2
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_torpedo2_'}}
			},

	--	{ 	category = '_torpedoground_' ,economy = true,false,false},
		--[[{ 	category = '_aabomb_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.5 and M.full > 0.5
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_heavyt_'},min = 50,neighbours = {'_aabomb_'}} ,
			special = true } , --specialFilter]]

		{ 	category = '_aaheavy_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 5000 and M.income > 100 and E.full > 0.5 and M.full > 0.1
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'factoryMobilities','_heavyt_'},min = 50,neighbours = {'_aaheavy_','_flak_'}} ,
			special = true } , --specialFilter

		{ 	category = '_aa2_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 500 and M.income > 25 and E.full > 0.3 and M.full > 0.1
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 50,neighbours = {'_aa2_'}} ,
			special = true } , --specialFilter

	}
----------------------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------------------
	----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------

	self.roles.expand = {
		{ 	category = '_mex_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },
		
		{ 	category = '_llt_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {min = 50,neighbours = {'_llt_','_popup2_','_popup1_'},list = self.map:GetMetalSpots()} ,
			},

		{ 	category = '_solar_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full < 0.05
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_','_llt_',},himself = true} ,
			special = false } , --specialFilter
			
		{ 	category = '_radar_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_radar_'}} ,
	        },

	}
--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------

	self.roles.eco = {
		{ 	category = 'factoryMobilities' ,
			economy = function(_,param,name)--ecofunc()
					return M.income > 6 and E.income > 30
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },
			{ 	category = '_nano_' ,
			economy = function(_,param,name)--ecofunc()
					return (self.ai.tool:countMyUnit({name}) == 0 )
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_llt_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = 2 , --numericalParameter
			location = {categories = {'_nano_','factoryMobilities'},max = 300,min = 50,neighbours = {'_llt_','_popup2_','_popup1_'}} ,
			},

		{ 	category = '_wind_' ,
			economy = function(_,param,name)--ecofunc()
					return ((E.full < 0.75 or E.income < E.usage * 1.25  )  or E.income < 30) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },

		{ 	category = '_tide_' ,
			economy = function(_,param,name)--ecofunc()
					return ((E.full < 0.75 or E.income < E.usage * 1.25  )  or E.income < 30) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },

		{ 	category = '_solar_' ,
			economy = function(_,param,name)--ecofunc(_,param,name)
					return ((E.full < 0.75 or E.income < E.usage * 1.25  )  or E.income < 50) and self.ai.ecohst.Energy.income < 3000
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_','selfCat','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter

		{ 	category = '_fus_' ,
			economy = function(_,param,name)--ecofunc()
					return ( E.income < E.usage * 1.25) or E.full < 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_nano_','factoryMobilities','selfCat'}} ,
			special = true } , --specialFilter

		{ 	category = '_nano_' ,
			economy = function(_,param,name)--ecofunc()
					return (E.full > 0.3  and M.full > 0.3 and M.income > 10 and E.income > 100) --or
					--(self.ai.tool:countMyUnit({name}) == 0 and (M.income > 10 and E.income > 60 ))
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		{ 	category = '_estor_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.75 and E.income > 400
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_mstor_' ,
			economy = function(_,param,name)--ecofunc()
					return  M.full > 0.75 and M.income > 20 and E.income > 200
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_convs_' ,
			economy = function(_,param,name)--ecofunc()
					local eco = self.ai.ecohst
					return (E.income > E.usage * 1.1 and E.full > 0.9 and  E.income > 200) or (eco.Energy.income - eco.Energy.usage > 100 and self.ai.tool:countFinished({'_convs_'}) == 0)
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },

		{ 	category = '_jam_' ,
			economy = function(_,param,name)--ecofunc()
					return M.full > 0.5 and M.income > 50 and E.income > 1000
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 100,neighbours = {'_jam_'}} ,
	        },

		{ 	category = '_antinuke_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 4000 and M.income > 75
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'_nano_'},min = 50} ,
	        },
		{ 	category = '_popup2_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_fus_','_convs_','factoryMobilities'},min = 50,neighbours = {'_popup2_'}} ,
	        },

	}
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

	self.roles.support = {
		{ 	category = '_radar_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.5
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_radar_'}} ,
	        },

		{ 	category = '_specialt_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 350 and M.income > 25
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots,min = 50,neighbours = {'_specialt_'}} ,
	        },

		{ 	category = '_popup1_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.trampledCells,min = 50,neighbours = {'_popup2_','_popup1_'}} ,
	        },

		{ 	category = '_popup2_' ,
			economy = function(_,param,name)--ecofunc()
					return  true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.trampledCells,min = 50,neighbours = {'_popup2_'}} ,
	        },

		{ 	category = '_heavyt_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 500 and M.income > 30 and M.full > 0.1
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots, min = 50 , neighbours = {'_heavyt_','_laser2_'}} ,
	        },

		{ 	category = '_laser2_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 2000 and M.income > 50 and E.full > 0.5 and M.full > 0.3
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = {min = 50,list = self.ai.maphst.hotSpots,neighbours = {'_laser2_'}} ,
	        },

		{ 	category = '_aa1_' ,
			economy = function(_,param,name)--ecofunc()
					return  E.full > 0.1 and E.income < 500
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {list = self.ai.maphst.hotSpots,min = 50,neighbours = {'_aa1_'}} ,
	        special = true,
	        },

		{ 	category = '_aa2_' ,
			economy = function(_,param,name)--ecofunc()
					return E.income > 500 and M.income > 25 and E.full > 0.5 and M.full > 0.1
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_heavyt_'},min = 50,neighbours = {'_aabomb_'}} ,
			special = true } , --specialFilter

		{ 	category = '_flak_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.1 and E.full < 0.5
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'_mex_'},min = 50,neighbours = {'_flak_'}} ,
			special = true } , --specialFilter
		{ 	category = '_mex_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },
	}
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	self.roles.assist = {
			{ 	category = '_mex_' ,
			economy = function(_,param,name)--ecofunc()
					return false
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },

		}
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	self.roles.nano = {
		{ 	category = '_nano_' ,
			economy = function(_,param,name)--ecofunc()
					return (E.full > 0.25  and M.full > 0.25) --or
					--(self.ai.tool:countMyUnit({name}) == 0 and (M.income > 10 and E.income > 60 ))
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = true , --positional category to search near
	        },

		}
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------

self.roles.metalMaker = {
		{ 	category = '_convs_' ,
			economy = function(_,param,name)--ecofunc()
					local eco = self.ai.ecohst
					return (E.full > 0.9 )
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },
		{ 	category = '_estor_' ,
			economy = function(_,param,name)--ecofunc()
					return E.full > 0.75 and E.income > 400
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_mstor_' ,
			economy = function(_,param,name)--ecofunc()
					return  M.full > 0.75 and M.income > 20 and E.income > 200
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'selfCat','_nano_','factoryMobilities'},himself = true} ,
	        },

		{ 	category = '_targeting_' ,
			economy = function(_,param,name)--ecofunc()
					return  E.income > 5000
				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = 3 , --numericalParameter
			location = {categories = {'selfCat','_nano_'},himself = true} ,
	        },
						}
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
	self.roles.starter = {
		{ 	category = '_mex_' ,
			economy = function(_,param,name)--ecofunc()
					return true
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = 3 , --numericalParameter
			location = true ,
	        },
		{ 	category = '_wind_' ,
			economy = function(_,param,name)--ecofunc()
					return  true --E.income < 40 and (M.income > 6 or self.ai.tool:countMyUnit({'_mex_'}) >= 2)
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {min = 100,categories = {'_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },

		{ 	category = '_tide_' ,
			economy = function(_,param,name)--ecofunc()
					return  true --E.income < 40 and (M.income > 6 or self.ai.tool:countMyUnit({'_mex_'}) >= 2)
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location = {min = 100,categories = {'_nano_','factoryMobilities'},himself = true} ,
	        special = true,
	        },

		{ 	category = '_solar_' ,
			economy = function(_,param,name)--ecofunc()
					return  true --E.income < 40 and (M.income > 6 or self.ai.tool:countMyUnit({'_mex_'}) >= 2)
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = false , --numericalParameter
			location ={min = 100,categories = {'_nano_','factoryMobilities'},himself = true} ,
			special = true } , --specialFilter



		{ 	category = 'factoryMobilities' ,
			economy = function(_,param,name)--ecofunc()
					return M.income > 6 or self.ai.tool:countMyUnit({'_mex_'}) >= 2 and E.income > 40

				end,--economicParameters
			duplicate = true , --duplicateFilter
			numeric = false , --numericalParameter
			location = true ,
	        },
		{ 	category = '_llt_' ,
			economy = function(_,param,name)--ecofunc()
					return self.ai.tool:countMyUnit({'factoryMobilities'}) > 0
				end,--economicParameters
			duplicate = false , --duplicateFilter
			numeric = 1 , --numericalParameter
			location = {categories = {'factoryMobilities'},min = 100,}
	        },list = self.map:GetMetalSpots() ,
		}

end

-- function TasksHST:wrap( theTable, theFunction )
-- 	self:EchoDebug(theTable)
-- 	self:EchoDebug(theFunction)
-- 	return function( tb, ai ,bd)
-- 		return theTable[theFunction](theTable, tb, ai, bd)
-- 	end
-- end
--
-- function map(func, array)
-- 	local new_array = {}
-- 	for i,v in ipairs(array) do
-- 		new_array[i] = func(v)
-- 	end
-- 	return new_array
-- end
--
-- function TasksHST:multiwrap( tables )
-- 	local wrapped = {}
-- 	for i,v in ipairs( table ) do
-- 		wrapped[i] = self:wrap( v[1], v[2] )
-- 	end
-- 	return wrapped
-- end
--
