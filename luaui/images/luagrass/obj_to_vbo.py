import sys
import math

normals_up = False

if len(sys.argv) <2:
	sys.argv.append("fir_tree_small_1()tree_fir_tall_5.obj")
	#sys.argv.append("cube_sphere.obj")

objdata = {'vn' : [], 'vt' : [], 'v' : [], 't' : {}, 'bt' : {}}
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

def dot(a,b):
	return sum([a[i] * b[i] for i in range(len(a))])

def cross(a,b):
	c = [a[1] * b[2] - a[2] * b[1],
		 a[2] * b[0] - a[0] * b[2],
		 a[0] * b[1] - a[1] * b[0]]
	return c

def add(a,b):
	return [a[i] + b[i] for i in range(len(a))]

for objline in open(sys.argv[1]).readlines():
	objitems = objline.strip().split()
	if objitems[0] in objdata:
		objdata[objitems[0]].append(list(map(float,objitems[1:])))
	if objitems[0] == 'f':
		# http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-13-normal-mapping/
		for whichvert,objitem in enumerate(objitems[1:4]):
			
			vertexorder = [1,2,3]
			if whichvert == 0:
				vertexorder = [1, 2, 3]
			elif whichvert ==1:
				vertexorder = [2, 3, 1]
			else:
				vertexorder = [3, 1, 2]
			
			v0, vt0, vn0 = tuple(map(int, objitems[vertexorder[0]].split('/')))
			v1, vt1, vn1 = tuple(map(int, objitems[vertexorder[1]].split('/')))
			v2, vt2, vn2 = tuple(map(int, objitems[vertexorder[2]].split('/')))
			
			v0 = objdata['v'][v0 - 1]
			v1 = objdata['v'][v1 - 1]
			v2 = objdata['v'][v2 - 1]
			
			vt0 = objdata['vt'][vt0 - 1]
			vt1 = objdata['vt'][vt1 - 1]
			vt2 = objdata['vt'][vt2 - 1]
			
			vn0 = objdata['vn'][vn0 - 1]
			vn1 = objdata['vn'][vn1 - 1]
			vn2 = objdata['vn'][vn2 - 1]
			
			deltapos1 = subtr(v1, v0)
			deltapos2 = subtr(v2, v0)
			
			deltauv1 = subtr(vt1, vt0)
			deltauv2 = subtr(vt2, vt0)
			
			r = 1.0 / (deltauv1[0] * deltauv2[1] - deltauv1[1] * deltauv2[0])
			
			tangent = scalarmult(subtr(scalarmult(deltapos1, deltauv2[1]), scalarmult(deltapos2, deltauv1[1])), r)
			
			bitangent = scalarmult(subtr(scalarmult(deltapos2, deltauv1[0]), scalarmult(deltapos1, deltauv2[0])), r)
			
			tangent = normalize(tangent)
			bitangent = normalize(bitangent)
			
			vi, vti, vni = tuple(map(int,objitem.split('/')))
			k = (vi, vti, vni)
			if k in objdata['t']:
				objdata['t'][k] += [tangent]
			else:
				objdata['t'][k] = [tangent]
for k in list(objdata['t'].keys()): # : the Gram-Schmidt processor re
	newt = [0,0,0]
	oldts = objdata['t'][k]
	for t in oldts:
		for i in [0,1,2]:
			newt[i] += t[i]
	newt = normalize(newt)
	N = objdata['vn'][k[2]-1]
	reT = normalize(subtr(newt, scalarmult( N, dot(newt, N))))
	objdata['t'][k] = reT
	objdata['bt'][k] = normalize(cross(N,reT))
	
for objline in open(sys.argv[1]).readlines():
	objitems = objline.strip().split()
	if objitems[0] == 'f':
		for whichvert, objitem in enumerate(objitems[1:4]):
			vi, vti, vni = tuple(map(int,objitem.split('/')))
			k = (vi, vti, vni)
			if normals_up:
				vn = [0,1,0]
			else:
				vn = objdata['vn'][vni-1]
			if vi-1 not in indexarray or True:
				outfile.write(listoffloats_to_line(objdata['v'][vi-1] + objdata['vn'][vni-1] + objdata['t'][k] + objdata['bt'][k] + objdata['vt'][vti-1][0:2] + [0,0] + [0]))
				numverts += 1
			indexarray.append(vi-1)
			numindices += 1
			
			
outfile.write('\n}\nlocal indexArray = {%s}\nlocal numIndices = %d\n local numVerts = %d\n  return {VBOData = VBOData, VBOLayout = VBOLayout, indexArray = indexArray, numVerts = numVerts, numIndices = numIndices}\n'%(listofints_to_line(indexarray),numindices,numverts))


outfile.close()
			
			
		
