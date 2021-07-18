import sys

normals_up = False
if len(sys.argv) <2:
	sys.argv.append("grassx4_2.obj")

objdata = {'vn' : [], 'vt' : [], 'v' : []}
numverts = 0

outfile = open(sys.argv[1]+'.lua','w')
outfile.write("""local VBOLayout= {  {id = 0, name = "position", size = 3},
      {id = 1, name = "normal", size = 3},
      {id = 2, name = "stangent", size = 3},
      {id = 3, name = "ttangent", size = 3},
      {id = 4, name = "texcoords0", size = 2},
      {id = 5, name = "texcoords1", size = 2},
      {id = 6, name = "pieceindex", size = 1},} --khm, this should be unsigned int
local VBOData = { """)

def listoffloats_to_line(lof):
	return '\t' + ','.join("0" if f == 0 else '%.4f'%f for f in lof) + ',\n'

for objline in open(sys.argv[1]).readlines():
	objitems = objline.strip().split()
	if objitems[0] in objdata:
		objdata[objitems[0]].append(list(map(float,objitems[1:])))
	if objitems[0] == 'f':
		for objitem in objitems[1:4]:
			vi, vti, vni = tuple(map(int,objitem.split('/')))
			if normals_up:
				vn = [0,1,0]
			else:
				vn = objdata['vn'][vni-1]
			outfile.write(listoffloats_to_line(objdata['v'][vi-1] + vn + [0,0,0] + [0,0,0] + objdata['vt'][vti-1][0:2] + [0,0] + [0]))
			numverts += 1
			
outfile.write('\n}\nlocal numVerts = %d\n'%numverts)
outfile.close()
			
			
		
