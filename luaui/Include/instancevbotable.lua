local dest = widget or gadget

if not LuaVBOTableNewLocationMessageShown then
	local info = dest.GetInfo()
	local name = info and info.name or 'unknown'
	local msg = "A user widget (" .. name .. ") is including LuaUI/Include/instancevbotable.lua directly, please change it to use gl.InstanceVBOTable instead."
	Spring.Log('UserWidget', LOG.DEPRECATED, msg)
	LuaVBOTableNewLocationMessageShown = true
end

local InstanceVBOTable = gl.InstanceVBOTable

dest.makeInstanceVBOTable   = InstanceVBOTable.makeInstanceVBOTable
dest.clearInstanceTable     = InstanceVBOTable.clearInstanceTable
dest.makeVAOandAttach       = InstanceVBOTable.makeVAOandAttach
dest.locateInvalidUnits     = InstanceVBOTable.locateInvalidUnits
dest.pushElementInstance    = InstanceVBOTable.pushElementInstance
dest.popElementInstance     = InstanceVBOTable.popElementInstance
dest.getElementInstanceData = InstanceVBOTable.getElementInstanceData
dest.uploadAllElements      = InstanceVBOTable.uploadAllElements
dest.uploadElementRange     = InstanceVBOTable.uploadElementRange
dest.compactInstanceVBO     = InstanceVBOTable.compactInstanceVBO
dest.drawInstanceVBO        = InstanceVBOTable.drawInstanceVBO
dest.makeCircleVBO          = InstanceVBOTable.makeCircleVBO
dest.makePlaneVBO           = InstanceVBOTable.makePlaneVBO
dest.makePlaneIndexVBO      = InstanceVBOTable.makePlaneIndexVBO
dest.makePointVBO           = InstanceVBOTable.makePointVBO
dest.makeRectVBO            = InstanceVBOTable.makeRectVBO
dest.makeRectIndexVBO       = InstanceVBOTable.makeRectIndexVBO
dest.makeConeVBO            = InstanceVBOTable.makeConeVBO
dest.makeCylinderVBO        = InstanceVBOTable.makeCylinderVBO
dest.makeBoxVBO             = InstanceVBOTable.makeBoxVBO
dest.makeSphereVBO          = InstanceVBOTable.makeSphereVBO
dest.MakeTexRectVAO         = InstanceVBOTable.MakeTexRectVAO

