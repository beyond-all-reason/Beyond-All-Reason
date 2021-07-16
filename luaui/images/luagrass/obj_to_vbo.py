import sys
import math

normals_up = False

if len(sys.argv) <2:
	sys.argv.append("fir_tree_small_1()tree_fir_tall_5.obj")

objdata = {'vn' : [], 'vt' : [], 'v' : [], 't' : [], 'bt' : []}
numverts = 0
numindices = 0
indexarray = []

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

def listofints_to_line(lof):
	return '\t' + ','.join('%d'%(f) for f in lof) + ',\n'

def subtr(a,b):
	return [a[i] - b[i] for i in range(len(a))]

def scalarmult(a,b):
	return [a[i]*b for i in range(len(a))]

def normalize(a):
	length = math.sqrt(sum([a[i]*a[i] for i in range(len(a))]))
	return scalarmult(a, 1.0 / length)

for objline in open(sys.argv[1]).readlines():
	objitems = objline.strip().split()
	if objitems[0] in objdata:
		objdata[objitems[0]].append(list(map(float,objitems[1:])))
	if objitems[0] == 'f':
		
		# http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
		v0, vt0, vn0 = tuple(map(int,objitems[1].split('/')))
		v1, vt1, vn1 = tuple(map(int,objitems[2].split('/')))
		v2, vt2, vn2 = tuple(map(int,objitems[3].split('/')))

		v0 = objdata['v'][v0-1]
		v1 = objdata['v'][v1-1]
		v2 = objdata['v'][v2-1]
		
		vt0 = objdata['vt'][vt0-1]
		vt1 = objdata['vt'][vt1-1]
		vt2 = objdata['vt'][vt2-1]
		
		vn0 = objdata['vn'][vn0-1]
		vn1 = objdata['vn'][vn1-1]
		vn2 = objdata['vn'][vn2-1]
		
		deltapos1 = subtr(v1, v0)
		deltapos2 = subtr(v2, v0)
		
		deltauv1 = subtr(vt1, vt0)
		deltauv2 = subtr(vt2, vt0)
		
		r = 1.0 / (deltauv1[0] * deltauv2[1] - deltauv1[1] * deltauv2[0])
		
		tangent = scalarmult(subtr( scalarmult(deltapos1, deltauv2[1]), scalarmult(deltapos2, deltauv1[1])) , r)

		bitangent = scalarmult(subtr( scalarmult(deltapos2, deltauv1[0]), scalarmult(deltapos1, deltauv2[0])) , r)
		
		tangent = normalize(tangent)
		bitangent = normalize(bitangent)

		
		for objitem in objitems[1:4]:
			vi, vti, vni = tuple(map(int,objitem.split('/')))
			if normals_up:
				vn = [0,1,0]
			else:
				vn = objdata['vn'][vni-1]
			if vi-1 not in indexarray:
				outfile.write(listoffloats_to_line(objdata['v'][vi-1] + objdata['vn'][vni-1] + tangent + bitangent + objdata['vt'][vti-1][0:2] + [0,0] + [0]))
				numverts += 1
			indexarray.append(vi-1)
			numindices += 1
			
			
outfile.write('\n}\nlocal indexArray = {%s}\nlocal numIndices = %d\n local numVerts = %d\n  return {VBOData = VBOData, VBOLayout = VBOLayout, indexArray = indexArray, numVerts = numVerts, numIndices = numIndices}\n'%(listofints_to_line(indexarray),numindices,numverts))


outfile.close()
			
			
		
