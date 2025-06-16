local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges LOS",
		desc = "Shows LOS ranges of all ally units. (GL4)",
		author = "Beherith GL4, Borg_King",
		date = "2021.06.18",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer = 0,
		enabled = true
	}
end

-------   Configurables: -------------------
local rangeColor = { 0.9, 0.9, 0.9, 0.24 } -- default range color
local opacity = 0.08
local useteamcolors = false
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)

local circleSegments = 62 -- To ensure its only 2 warps per instance
local rangecorrectionelmos = 16 -- how much smaller they are drawn than truth due to LOS mipping
--------- End configurables ------

local minSightDistance = 100
local gaiaTeamID = Spring.GetGaiaTeamID()

------- GL4 NOTES -----
--only update every 15th frame, and interpolate pos in shader!
--Each instance has:
-- startposrad
-- endposrad
-- color
-- TODO: draw ally ranges in diff color!
-- 172 vs 123 preopt
-- TODO 2023.07.06:
	-- X Use drawpos
	-- X Stencil outlines too
	-- X remove debug code
	-- X validate options!
	-- X The only actual param needed per unit is its los range :D
	-- X refactor the opacity

-- Compute shader visibility culling:
-- Pass 1. compute :
	-- Inputs: Take SUniformsBuffer and the losrangeVBO
	-- Calculates: Which of the units are in view, and which are not. 
	-- Outputs: a VBO of vec4's of {posx, posz, losrange, index} for each unit that is in view.
		-- note that we cant selectively output stuff we want, because no sorting is possible in compute shaders.
	-- the indices are in the same order as in the losrangeVBO, so we can use them to index into the losrangeVBO.

-- Pass 2. compute :
	-- inputs: Takes the VBO from pass 1, 
	-- Calculates overlappedness of the los ranges. 
	-- Outputs: a new VBO which is #maxunits size indicating overlappedness
	-- in LOSRANGEVBO index order

-- Pass 3. vertex shader:
	-- inputs: Takes the VBO from pass 2, and the losrangeVBO
	-- draws stuff based on the VBO from pass 2, and the losrangeVBO

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local circleShader = nil
local circleInstanceVBO = nil

local shaderConfig = {
	EXAMPLE_DEFINE = 1.0,
	--USE_STIPPLE = 1.5;
}

local shaderSourceCache = {
	shaderName = 'LOS Ranges GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los.frag.glsl",
	shaderConfig = shaderConfig,
	uniformInt = {
		heightmapTex = 0,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
}

local counterSSBO

local visibilitySSBO 

--- CMP Visibility shader
--- 
local visibilityComputeShader 
local cmpVisSrc = [[
#version 430 core
#line 40000
//layout (location = 1) in vec4 radius_params; //x is startradius, rest is unused, we need to get pos from drawpos
//layout (location = 2) in uvec4 instData;

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

struct SUniformsBuffer {
	uint composite; //     u8 drawFlag; u8 unused1; u16 id;

	uint unused2;	uint unused3;	uint unused4;

	float maxHealth; 	float health; 	float unused5; 	float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

struct SensorVBOStruct {
	vec4 radius_params;
	uvec4 instData;
};

layout(std140, binding=2) readonly buffer InputInstanceBuffer {
	SensorVBOStruct inputInstances[];
};

layout(std140, binding=3) writeonly buffer OutputVisibleBuffer {
	SensorVBOStruct visibleInstances[];
};

layout(std140, binding = 4) buffer CounterBuffer {
    uint visibleCount;
};

uniform mat4 viewProjectionMatrix; // view projection matrix for the camera
#line 41000
void main(void)
{
	vec4 in_radius_params = inputInstances[gl_GlobalInvocationID.x].radius_params;
	uvec4 instData = inputInstances[gl_GlobalInvocationID.x].instData;
	vec4 drawPos = uni[instData.x].drawPos;
	float losrange = in_radius_params.x;
	vec4 out_radius_params = vec4(drawPos.xzz, losrange); // x is pos.x, y is pos.z, z is losrange, w is unused

	uint index = gl_GlobalInvocationID.x;
	// check if its in view based on the viewProjectionMatrix
	vec4 posInClipSpace = viewProjectionMatrix * vec4(drawPos.x, drawPos.y, drawPos.z, 1.0);
	bool visible = true;
	if (posInClipSpace.w <= 0.0) {
		// not in view
		visible = false;
	}
	// check if its in the view frustum
	if (abs(posInClipSpace.x) > posInClipSpace.w || abs(posInClipSpace.y) > posInClipSpace.w) {
		// not in view
		visible = false;
	}
	
	if (visible) {
		// increment the visible count
		uint currentCount = atomicAdd(visibleCount, 1);

		visibleInstances[currentCount].radius_params = out_radius_params;
		visibleInstances[currentCount].instData = instData;
	}
}
]]


local coveredSSBO
local overlapComputeShader

local cmpCoveredShader = [[  
#version 430 core

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

struct SensorVBOStruct {
	vec4 radius_params;
	uvec4 instData;
};

layout(std430, binding=2) buffer SensorVBOBuffer {
	SensorVBOStruct visibleInstances[];
};


uniform uint numUnits; // number of units in the visibilitySSBO

// see https://www.khronos.org/opengl/wiki/Compute_Shader

// this came to me in a dream, and I hope it works




# line 50000
void main(void){
	uint index = gl_GlobalInvocationID.x;
	vec4 px_pz_r_v = visibleInstances[index].radius_params;
	vec2 mypos = px_pz_r_v.xy;
	float losrange = px_pz_r_v.z;
	bool bigcovered = false;
	bvec4 smallcovered = bvec4(false);
	float smallRange = px_pz_r_v.z * 0.8; // 80% of the los range

	vec4 smallx = mypos.x + losrange * vec4(0.25, 0.25, -0.25, -0.25);
	vec4 smally = mypos.y + losrange * vec4(0.25, -0.25, 0.25, -0.25);

	for( uint i = 0; i < (numUnits-1); i++ ) {
		if (i == index) i++; // worlds silliest skip hack to avoid branching 
		vec4 px_pz_r_v2 = visibleInstances[i].radius_params;
		float losrange2 = px_pz_r_v2.z;
		if (losrange2 > losrange) {
			// check if the other unit is within the los range of this unit
			vec2 d12 = mypos.xy - px_pz_r_v2.xy;
			float r12 = losrange - losrange2;
			if (dot(d12,d12) < dot(r12,r12)) {
				bigcovered = true; // this unit is covered by another unit
			}
		}
		
		vec4 dcx = px_pz_r_v2.x - smallx;
		vec4 dcy = px_pz_r_v2.y - smally;

		vec4 small_sqrdistances = dcx * dcx + dcy * dcy;

		float minDist = (smallRange - losrange2) * (smallRange - losrange2); // square the distance

		smallcovered = smallcovered || bvec4(lessThan(small_sqrdistances, vec4(minDist))) ;
	}
	
	if (all(smallcovered)) {
		// if all small covered, then we are done
		visibleInstances[index].radius_params.z = 32.0;
	}
	if (bigcovered) {
		// if all small covered, then we are done
		visibleInstances[index].radius_params.z = 40.0;
	}
}
]]

local structSize = 8 -- Is it vec4 or float or bytes? only the god knows. Also, should by like 64 floats aligned or else upload craps out
local numEntries = 32768 -- max number of units we can handle

local function goodbye(reason)
	Spring.Echo("Sensor Ranges LOS widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function initgl4()
	if circleShader then
		circleShader:Finalize()
	end
	if circleInstanceVBO then
		InstanceVBOTable.clearInstanceTable(circleInstanceVBO)
	end
	circleShader = LuaShader.CheckShaderUpdates(shaderSourceCache,0)

	if not circleShader then
		goodbye("Failed to compile losrange shader GL4 ")
	end
	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(circleSegments)
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'radius_params', size = 4 }, -- radius, + 3 unused floats
		{ id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT}, -- instData
	}
	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 128, "losrangeVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)
	local pcache = {}
	for i = 0,  (numEntries * structSize -1) do pcache[i+1] = 0	end

	visibilitySSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	visibilitySSBO:Define(numEntries, {
		{id = 0, name = "visibility", size = structSize},
	})
	visibilitySSBO:Upload(pcache)

	counterSSBO = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	counterSSBO:Define(1, {
		{id = 0, name = "counter", size = 1},
	})
	counterSSBO:Upload({0,0,0,0}) -- At least 4 for some reason

	visibilityComputeShader = LuaShader({
		compute = cmpVisSrc,
		uniformInt = {
			--heightmapTex = 0,
		},
		uniformFloat = {
			--frameTime = 0.016, -- this is a dummy value, we dont use it
		}
	}, "visibilityComputeShader")

	if not visibilityComputeShader:Initialize() then
		goodbye("Failed to initialize visibility compute shader")
	end

	overlapComputeShader = LuaShader({
		compute = cmpCoveredShader,
		uniformInt = {
			--heightmapTex = 0,
		},
		uniformFloat = {
			--frameTime = 0.016, -- this is a dummy value, we dont use it
		}
	}, "overlapComputeShader")

	if not overlapComputeShader:Initialize() then
		goodbye("Failed to initialize overlap compute shader")
	end

end


function widget:DrawGenesis()
	circleInstanceVBO.instanceVBO:BindBufferRange(2)
	visibilitySSBO:BindBufferRange(3)
	counterSSBO:BindBufferRange(4)
	visibilityComputeShader:Activate()
	gl.DispatchCompute(circleInstanceVBO.usedElements, 1, 1) -- 32 is the local size x
	visibilityComputeShader:Deactivate()
	

end


-- Functions shortcuts
local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitTeam = Spring.GetUnitTeam
local glColorMask = gl.ColorMask
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glStencilFunc = gl.StencilFunc
local glStencilOp = gl.StencilOp
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local GL_ALWAYS = GL.ALWAYS
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_KEEP = 0x1E00 --GL.KEEP
local GL_REPLACE = GL.REPLACE
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN

-- Globals
local lineScale = 1
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges

for unitDefID, unitDef in pairs(UnitDefs) do
	-- save perf by excluding low los range units
	if unitDef.sightDistance and unitDef.sightDistance > minSightDistance then
		unitRange[unitDefID] = unitDef.sightDistance - rangecorrectionelmos
	end
end

function widget:ViewResize(newX, newY)
	local vsx, vsy = Spring.GetViewGeometry()
	lineScale = (vsy + 500)/ 1300
end

-- a reusable table, since we will literally only modify its first element.
local instanceCache = {0,0,0,0,0,0,0,0}

local function InitializeUnits()
	--Spring.Echo("Sensor Ranges LOS InitializeUnits")
	InstanceVBOTable.clearInstanceTable(circleInstanceVBO)
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID), true)
		end
	end
	InstanceVBOTable.uploadAllElements(circleInstanceVBO)
end


function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		InitializeUnits()
	end
end

local function CalculateOverlapping()
	local allcircles = circleInstanceVBO.indextoInstanceID
	local totalcircles = 0
	local totaloverlapping = 0
	local inviewcircles = 0
	local inviewoverlapping = 0
	local inviewoverlapsmalls = 0
	local additionalOverlaps = 0

	local circles = {}
	-- cut it down to visible circles only
	for index, unitID in ipairs(allcircles) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local losrange = unitRange[Spring.GetUnitDefID(unitID)]
		local px,py,pz = Spring.GetUnitPosition(unitID)
		local inview = Spring.IsSphereInView(px,py,pz,losrange)
		if px and unitRange[unitDefID] then
			--circles[index] = {px = px, py = py, pz =  pz, losrange = losrange, inview = Spring.IsSphereInView(px,py,pz,losrange),
			--fullycovered = false, topcovered =  false, bottomcovered =  false, leftcovered =  false, rightcovered = false}
			if inview then 
				circles[#circles + 1] = {px, py,  pz,  losrange, Spring.IsSphereInView(px,py,pz,losrange), false,   false,   false,   false,  false}	
				inviewcircles = inviewcircles + 1
			end
			totalcircles = totalcircles + 1
		end
	end
	local rmult = 0.707
	local omult = 0.5

	rmult = 0.8
	omult = 0.25
	for index, circle in ipairs(circles) do
		local px,  pz, losrange = circle[1], circle[3], circle[4]

		-- check for overlap
		local overlaps = false
		for index2, circle2 in ipairs(circles) do
			for o = 0, 4 do 
				local px2, pz2, losrange2 = circle2[1], circle2[3], circle2[4]
				local testrange = losrange
				local ox = 0
				local oz = 0 
				if o > 0 then 
					testrange = losrange * rmult
				end
				if o == 1 then 
					ox = losrange *omult  -- THIS IS INCORRECT! other way around!
					oz = losrange *omult
				elseif o == 2 then 
					ox = -losrange *omult
					oz = losrange * omult
				elseif o == 3 then
					ox = losrange *omult
					oz = -losrange *omult
				elseif o == 4 then
					ox = -losrange *omult
					oz = -losrange *omult
				end
				if losrange2 > testrange then
					if math.diag(px + ox -px2, pz + oz -pz2) < (losrange2 - testrange) then
						circle[6+o] = true -- covered
					end 
				end
			end
		end
		if circle[7] and circle[8] and circle[9] and circle[10] then
			inviewoverlapsmalls = inviewoverlapsmalls + 1
			if not circle[6] then
				additionalOverlaps = additionalOverlaps + 1
			end
		end	
		if circle[6] then
			inviewoverlapping = inviewoverlapping + 1
		end
	end
	Spring.Echo("Sensor Ranges LOS: ",omult, totalcircles, totaloverlapping, inviewcircles, inviewoverlapping, inviewoverlapsmalls, additionalOverlaps)
--[[
	for index, unitID in ipairs(allcircles) do
		--Spring.Echo(px,py,pz)
		if px then
			local unitDefID = Spring.GetUnitDefID(unitID)
			local losrange = unitRange[unitDefID]
			totalcircles = totalcircles + 1
			-- check for overlap
			local overlaps = False
			for index2, unitID2 in ipairs(allcircles) do
				local unitDefID2 = Spring.GetUnitDefID(unitID2)
				local losrange2 = unitRange[unitDefID2]
				--Spring.Echo(losrange2, losrange)
				if losrange2 > losrange then
					local px2, py2, pz2 = Spring.GetUnitPosition(unitID2)
					--Spring.Echo(px-px2, pz-pz2, losrange2, losrange)
					if px2 and (math.diag(px-px2, pz-pz2) < losrange2 - losrange) then
						overlaps = true
					end
				end
			end



			if Spring.IsSphereInView(px,py,pz,losrange) then
				inviewcircles =inviewcircles + 1
				if overlaps then inviewoverlapping = inviewoverlapping + 1 end
			end
			if overlaps then totaloverlapping = totaloverlapping + 1 end
		end
	end
]]--
	return totalcircles, totaloverlapping, inviewcircles, inviewoverlapping, inviewoverlapsmalls
end

function widget:TextCommand(command)
	if string.find(command, "loscircleoverlap", nil, true) then
		Spring.Echo("CalculateOverlapping", CalculateOverlapping())
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if Spring.GetModOptions().disable_fogofwar then
		widgetHandler:RemoveWidget()
		return
	end
	WG.losrange = {}
	WG.losrange.getOpacity = function()
		return opacity
	end
	WG.losrange.setOpacity = function(value)
		opacity = value
	end
	WG.losrange.getUseTeamColors = function()
		return useteamcolors
	end
	WG.losrange.setUseTeamColors = function(value)
		useteamcolors = value
	end
	initgl4()
	widget:ViewResize()
	InitializeUnits()
end

function widget:Shutdown()
	WG.losrange = nil
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, noupload)
	--Spring.Echo("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, noupload)
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	noupload = noupload == true
	if unitRange[unitDefID] == nil or unitTeam == gaiaTeamID then return end

	if (not (spec and fullview)) and (not spIsUnitAllied(unitID)) then -- given units are still considered allies :/
		return
	end -- display mode for specs

	if Spring.GetUnitIsBeingBuilt(unitID) then return end

	instanceCache[1] =  unitRange[unitDefID]
	pushElementInstance(circleInstanceVBO,
		instanceCache,
		unitID, --key
		true, -- updateExisting
		noupload,
		unitID -- unitID for uniform buffers
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- Note that this unit uses its own VisibleUnitsChanged, to handle the case where we go into fullview.
	--InitializeUnits()
end

function widget:VisibleUnitRemoved(unitID)
	if circleInstanceVBO.instanceIDtoIndex[unitID] then
		popElementInstance(circleInstanceVBO, unitID)
	end
end

local updateTimer = Spring.GetTimer()


function widget:DrawWorld()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end
	if circleInstanceVBO.usedElements == 0 then return end
	if opacity < 0.01 then return end

	if Spring.DiffTimers(Spring.GetTimer(), updateTimer) > 2.0 then
		updateTimer = Spring.GetTimer()
		CalculateOverlapping()
	end

	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- clear stencil buffer before starting work
	glColorMask(false, false, false, false) -- disable color drawing
	glStencilTest(true) -- Enable stencil testing
	glDepthTest(false)  -- Dont do depth tests, as we are still pre-unit
	circleShader:Activate()

	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	circleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	circleShader:SetUniform("teamColorMix", useteamcolors and 1 or 0)

	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
	-- Borg_King: Draw solid circles into masking stencil buffer
	--glStencilFunc(GL_ALWAYS, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilFunc(GL_NOTEQUAL, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	glStencilMask(1) -- Only check the first bit of the stencil buffer
	-- As a test, disable the stencil drawing to see overlappiness
	--circleInstanceVBO.VAO:DrawArrays(GL_TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	circleShader:Deactivate()

	circleShader:Activate()

	-- Borg_King: Draw thick ring with partial width outside of solid circle, replacing stencil to 0 (draw) where test passes
	glColorMask(true, true, true, true)	-- re-enable color drawing
	glStencilFunc(GL_NOTEQUAL, 1, 1)
	--glStencilMask(0) -- this is commented out to not double-draw los ring edges
	--glColor(rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
	glLineWidth(rangeLineWidth * lineScale * 1.0)
	--Spring.Echo("glLineWidth",rangeLineWidth * lineScale * 1.0)
	glDepthTest(true)
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	circleShader:Deactivate()
	glStencilMask(255) -- enable all bits for future drawing
	glStencilFunc(GL_ALWAYS, 1, 1) -- reset gl stencilfunc too

	gl.Texture(0, false)
	glStencilTest(false)
	glDepthTest(true)
	--glColor(1.0, 1.0, 1.0, 1.0) --reset like a nice boi
	glLineWidth(1.0)
	gl.Clear(GL.STENCIL_BUFFER_BIT)
	

end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
		useteamcolors = useteamcolors,
	}
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.useteamcolors ~= nil then
		useteamcolors = data.useteamcolors
	end
end
