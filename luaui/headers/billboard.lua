local glMultMatrix    = gl.MultMatrix
local glGetMatrixData = gl.GetMatrixData
local GL_MODELVIEW    = GL.MODELVIEW

local billboardM = {}
  billboardM[4]  = 0
  billboardM[8]  = 0
  billboardM[12] = 0
  billboardM[13] = 0
  billboardM[14] = 0
  billboardM[15] = 0
  billboardM[16] = 1

function CreateBillboard()
  billboardM[1],billboardM[5],billboardM[9],_,billboardM[2],billboardM[6],billboardM[10],_,billboardM[3],billboardM[7],billboardM[11]  = glGetMatrixData(GL_MODELVIEW)
end

function UseBillboard()
  glMultMatrix(billboardM)
end

gl.BillboardFixed = UseBillboard
gl.CreateBillboard = CreateBillboard

