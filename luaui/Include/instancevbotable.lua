
if not LuaVBOTableNewLocationMessageShown then
	local msg = "A user widget is including LuaUI/Include/instancevbotable.lua directly, please change it to use gl.InstanceVBOTable instead."
	Spring.Log('UserWidget', LOG.DEPRECATED, msg)
	LuaVBOTableNewLocationMessageShown = true
end

makeInstanceVBOTable   = InstanceVBOTable.makeInstanceVBOTable
clearInstanceTable     = InstanceVBOTable.clearInstanceTable
makeVAOandAttach       = InstanceVBOTable.makeVAOandAttach
locateInvalidUnits     = InstanceVBOTable.locateInvalidUnits
pushElementInstance    = InstanceVBOTable.pushElementInstance
popElementInstance     = InstanceVBOTable.popElementInstance
getElementInstanceData = InstanceVBOTable.getElementInstanceData
uploadAllElements      = InstanceVBOTable.uploadAllElements
uploadElementRange     = InstanceVBOTable.uploadElementRange
compactInstanceVBO     = InstanceVBOTable.compactInstanceVBO
drawInstanceVBO        = InstanceVBOTable.drawInstanceVBO
makeCircleVBO          = InstanceVBOTable.makeCircleVBO
makePlaneVBO           = InstanceVBOTable.makePlaneVBO
makePlaneIndexVBO      = InstanceVBOTable.makePlaneIndexVBO
makePointVBO           = InstanceVBOTable.makePointVBO
makeRectVBO            = InstanceVBOTable.makeRectVBO
makeRectIndexVBO       = InstanceVBOTable.makeRectIndexVBO
makeConeVBO            = InstanceVBOTable.makeConeVBO
makeCylinderVBO        = InstanceVBOTable.makeCylinderVBO
makeBoxVBO             = InstanceVBOTable.makeBoxVBO
makeSphereVBO          = InstanceVBOTable.makeSphereVBO
MakeTexRectVAO         = InstanceVBOTable.MakeTexRectVAO

