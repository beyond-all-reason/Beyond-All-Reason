function widget:GetInfo()
  return {
    name      = "gui_transport_weight_limit",
    desc      = "Hilight's with unit transport can lift",
    author    = "nixtux",
    date      = "Apr 24, 2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local unitstodraw = {}
local transID = nil

local validTrans = {}

function widget:Initialize()
        for i=1,#UnitDefs do
                local unitDefID = UnitDefs[i]
                if unitDefID.transportSize and unitDefID.transportSize > 0 then
                    validTrans[i] = true
                end
        end
end

function widget:GameFrame(n)
    local unitcount = 0
	if (n % 2 == 1) then
    unitstodraw = {}
	local _,cmdID,_ = Spring.GetActiveCommand()
	local selectedUnits = Spring.GetSelectedUnits()
	if #selectedUnits == 1 then
		if validTrans[Spring.GetUnitDefID(selectedUnits[1])] then
        		transID = selectedUnits[1]
		end
        elseif #selectedUnits > 1 then
                for _,unitID in pairs(selectedUnits) do
                    
                    local unitdefID = Spring.GetUnitDefID(unitID)
                    if validTrans[unitdefID] then
                       transID = unitID
                       unitcount = unitcount + 1
                       if unitcount > 1 then 
                           transID = nil
                           return end
                    end
                end
        else
		transID = nil
		return
	end

        
        if transID then
        local TransDefID = Spring.GetUnitDefID(transID)
        local udTrans = UnitDefs[TransDefID]
	local transMassLimit = udTrans.transportMass
        local transCapacity = udTrans.transportCapacity
        local transportSize = udTrans.transportSize
	if cmdID == CMD_LOAD_UNITS then
		local visibleUnits = Spring.GetVisibleUnits()
		if #visibleUnits then
                        for i=1, #visibleUnits do
                        local unitID = visibleUnits[i]
                        local visableID = Spring.GetUnitDefID(unitID)
			local isinTrans = Spring.GetUnitIsTransporting(transID)
                        if #isinTrans >= transCapacity then
                            return
                        end
			if transID and transID ~= visableID then
				local ud = UnitDefs[visableID]
				local passengerMass = ud.mass
                                local passengerX = ud.xsize/2
                                if (passengerMass <= transMassLimit) and (passengerX <= transportSize) and not ud.cantBeTransported and not Spring.IsUnitIcon(unitID) then 
                                    local x, y, z = Spring.GetUnitBasePosition(unitID)
                                    if (x) then
                                         unitstodraw[unitID] = {pos = {x,y,z},size = (passengerX*24)}
                                    end
                                end
                               end
                            end
			end
		end
	end
    end
end

function widget:DrawWorldPreUnit()
    gl.LineWidth(6)
    gl.Color(0, 0.8, 0, 0.37)
    for unitID,_ in pairs(unitstodraw) do
        local pos = unitstodraw[unitID].pos
        local size = unitstodraw[unitID].size
        gl.DrawGroundCircle(pos[1], pos[2], pos[3], size, 3)
    end
    gl.Color(1,1,1,1)
    gl.LineWidth(1)
end
