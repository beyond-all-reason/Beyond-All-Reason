import sys
from s3o import *
import os
import math

import optparse

#mode 1:
#convert s3o to obj ignoring the empty pieces

#mode 2:
#fuse the s3o and the ovb file, copying the terms into the s3o uv[0]

parser = optparse.OptionParser()
# parser.add_option('-d', '--dir', help='working directory for s3o files', default="S:\\baremake\\etc\\Tools\\OBJtoS3O_Converter\\objects3d_input")
parser.add_option('-i', '--indir', help='working directory for s3o files', default=os.getcwd())
parser.add_option('-o', '--outdir', help='working directory for s3o files', default=os.getcwd())
parser.add_option('-u','--unitdefdir', help='working directory for s3o files', default='units')
parser.add_option('--scriptdir', help='working directory for s3o files', default='scripts')
parser.add_option('-s', '--s3o', help='s3o key', default='')
# parser.add_option('-b', '--ovb', help='ovb file name', default="S:\\SVN\\branches\\BAR\\objects3d")
parser.add_option('-f', '--fuse', help='fuse ovb and s3o', default=False, action='store_true')
parser.add_option('--groundplate', help='add a ground plate to the obj', default=True, action='store_true')
parser.add_option('--separate', help='separate the object so that pieces are occluded separately', default=False, action='store_true')
parser.add_option('-p', '--ignorepieces', help='ignore these piece names and set them to 0.8, comma separated list of piece names', default = '')
parser.add_option('--forceall', help = 'Forces all .s3o in indir to be processed, even if their unitdefs cant be parsed. In which case they are counted as non-buildings and non-flying units.', default = False, action = 'store_true')
separatelist=(['armacsub','armacv','armemp','armmship','armmmkr','armmls','armuwmmm','armvader','armcv','armbeaver','armcroc','armst',
				'armplat','armmh','armmerl','armsolar','armtship','armthovr','armgeo','armamb','armfatf','armfmkr','armck',
				'corsolar','corcs','cormls','cortoast','packo','armpb','armrecl','corvroc','cormship','coracsub','corgant','corlab','cormh','cormoho','cormexp','corvp'])
				#optionally: coravp

#Todo:
#no ground plates for AIRCRAFT!
#get spinny bits and turn off their AO
#figure out a way to deal with fully occluded pieces like the ones inside of units like nano turrets
#remove '*vN.s3o' markings from s3o files
#disregard bitches, aquire currency
#implement a 'piecewise' operator

(opts, args) = parser.parse_args()
print opts
ignorepieces=opts.ignorepieces.split(',')
def delimit(str,a,b):
	return str.partition(a)[2].partition(b)[0]
if not opts.fuse:
	#load s3o file
	for file in os.listdir(opts.indir):
		if '.s3o' in file and opts.s3o in file:
			basename=file.rpartition('.')[0]
			print '=========================working on',basename,'==============================='

			if opts.groundplate:
				#check if the unit has a unitdef and if that unit is not a flying unit.
				#also, make bigger plates for buildings :)
				flying=False
				building=False
				if opts.unitdefdir!= '':
					try:
						luaunitdeflines=open(opts.unitdefdir+'\\'+basename+'.lua').readlines()
						for line in luaunitdeflines:
							if 'acceleration' in line.lower() and float(delimit(line,'=',','))<0.001:
								building=True
								print basename,'is a building'
							if 'canfly' in line.lower() and 'true' in delimit(line.lower(),'=',','):
								flying=True
								print basename,'can fly'
					except:
						print '========================Failed to parse unitdef for',file
						pass
						if opts.forceall:
							print 'Forceall is enabled, will count this as nonflying building'
							building= False
							flying = False
						else:
							continue
				mys3o=S3O(open(opts.indir+'\\'+file,'rb').read())
				objfile=opts.indir+'\\'+basename+'.obj'
				mys3o.S3OtoOBJ(objfile,False)
				print basename, 'flying:',flying,'building:',building
				if not flying:		
					objfilehandle=open(objfile)
					objlines=objfilehandle.readlines()
					objfilehandle.close()
					vertex_cnt=0
					vnormal_cnt=0
					uv_cnt=0
					boundingbox=[0,0,0,0,0,0] #xmin, xmax, ymin, ymax, zmin, zmax
					def bind(coords,boundingbox):
						for axis in range(3):
							boundingbox[2*axis  ]=min(boundingbox[2*axis  ],coords[axis])
							boundingbox[2*axis+1]=max(boundingbox[2*axis+1],coords[axis])
						return boundingbox
					for line in objlines:
						if line[0:2]=='v ':
							boundingbox=bind([float(f) for f in line[2:].strip().split(' ')],boundingbox)
							vertex_cnt+=1
						if line[0:3]=='vn ':
							vnormal_cnt+=1
						if line[0:3]=='vt ':
							uv_cnt+=1
					for axis in range(3): #expand the bounding box by 1 in each direction.
						xz_expand=1
						if building and axis !=1: #dont expand y axis
							xz_expand=12
						boundingbox[2*axis  ]=boundingbox[2*axis  ]-xz_expand
						boundingbox[2*axis+1]=boundingbox[2*axis+1]+xz_expand
					for vertex in ([(boundingbox[0],boundingbox[2],boundingbox[4]),
									(boundingbox[0],boundingbox[2],boundingbox[5]),
									(boundingbox[1],boundingbox[2],boundingbox[5]),
									(boundingbox[1],boundingbox[2],boundingbox[4])]):
						objlines.append('v %f %f %f\n'%vertex)
					for i in range(4):
						objlines.append('vn %f %f %f\n'%(0,1,0))
						objlines.append('vt %f %f\n'%(0,0))
					objlines.append('f '+' '.join(['%i/%i/%i'%(vertex_cnt+i,uv_cnt+i,vnormal_cnt+i) for i in [1,2,3]])+'\n')
					objlines.append('f '+' '.join(['%i/%i/%i'%(vertex_cnt+i,uv_cnt+i,vnormal_cnt+i) for i in [3,4,1]])+'\n')
					objfilehandle=open(objfile,'w')
					objfilehandle.write(''.join(objlines))
					objfilehandle.close()
				if opts.separate or basename.lower() in separatelist:
					print 'Separating', basename,'into pieces for AO bake to avoid excessive darkening on hidden pieces'
					objfilehandle=open(objfile)
					objlines=objfilehandle.readlines()
					objfilehandle.close()
					piececount=-1
					for line_index in range(len(objlines)):
						oldline=objlines[line_index]
						if 'v ' == oldline[0:2]:
							oldline=oldline.split(' ') #we are only gonna replace the Y coords with origY+piececount*100
							objlines[line_index]='v %s %f %s'%(oldline[1],float(oldline[2])+100.0*piececount,oldline[3])
						if 'o '== oldline [0:2]:
							piececount+=1
							
							

					objfilehandle=open(objfile,'w')
					objfilehandle.write(''.join(objlines))
					objfilehandle.close()
				# mys3o=S3O(open(opts.s3o,'rb').read())
	# mys3o.S3OtoOBJ(opts.s3o.rpartition('.')[0]+'.obj',False)
else:
	#perform the fusing:
	aovalues={}
	def parse_ovb_triplet(line):
		line=line.strip().replace('\"','').strip('<>/').split(' ')	
		vertex=[]
		for coord in line[1:]:
			vertex.append(float(coord.partition('=')[2]))
		return vertex
		
	for file in os.listdir(opts.indir):
		basename=file.rpartition('.')[0]
		if '.ovb' not in file or opts.s3o not in file:
			continue
		print 'Working on:',file
		vertdata=[]
		aodata=[]
		ovbfile=open(opts.indir+'\\'+file).readlines()
		aobins=[0 for i in range(256)]
		vcount=0

			
		for line in ovbfile:
			if '<VPos' in line:
				vertdata.append(parse_ovb_triplet(line))
			if '<VCol' in line:
				aodata.append(parse_ovb_triplet(line))
		aomax=0
		for ao in aodata:
			aobins[int(sum(ao)/3)]+=1
			aomax=max(aomax,aobins[int(sum(ao)/3)])

		for aoval in range(256): #just display it
			print aoval, 'O'*int(80*aobins[aoval]/aomax)
		print aomax, aobins
		# ao

		olds3ofile = open(opts.indir+'\\'+file.partition('.')[0]+'.s3o','rb')
		olds3o= S3O(olds3ofile.read())
		olds3ofile.close()
		for i in range(len(aodata)):
			aodata[i]=sum(aodata[i])/3.0
		
		def recursefoldaoterm(piece, vertex_offset, ignore_these):
			#global ignorepieces
			print 'folding ao terms for',piece.name, 'current offset=',vertex_offset
			ignore=False
			if piece.name.lower() in ignore_these:
				print 'ignoring',piece.name
				ignore=True	
			folded_vert_indices=[]
			for vertex_i in range(len(piece.indices)):
				if piece.indices[vertex_i] in folded_vert_indices:
					#print 'already did',piece.indices[vertex_i]
					continue
				else:
					folded_vert_indices.append(piece.indices[vertex_i])
					vertex=piece.vertices[piece.indices[vertex_i]]
					#print vertex_offset,len(folded_vert_indices), vertex_i, len(aodata), vertex
					
					#dont use the entire range, because rounding errors might screw us over later, use only the range from 5-250
					vertex_ao_value=aodata[len(folded_vert_indices)-1+vertex_offset]
					if ignore:
						vertex_ao_value=200
					newuv=(math.floor(vertex[2][0]*16384.0)/16384.0+1/16384.0*((vertex_ao_value+5)/266.0), vertex[2][1])
					# print newuv, vertex
					vertex=(vertex[0],vertex[1],newuv)
					piece.vertices[piece.indices[vertex_i]]=vertex
			print 'finished folding ao terms for',piece.name,'unique vertex count=',len(folded_vert_indices)
			vertex_offset+=len(folded_vert_indices)
			for child in piece.children:
				childoffset=recursefoldaoterm(child,vertex_offset,ignore_these)
				print 'in child, vertex offset=',vertex_offset,'child_offset=',childoffset
				vertex_offset= childoffset
			return vertex_offset
		
		#parse bos for spin pieces
		ignorepieces=[]
		if opts.scriptdir!='':
			try:
				boslines=open(opts.scriptdir+'\\'+basename+'.bos').readlines()
				for line in boslines:
					if 'spin' in line.partition('//')[0] and ('x-axis' in line or 'z-axis' in line) and 'stop-spin' not in line:
						piecename=delimit(line,'spin','around').strip().lower()
						if piecename not in ignorepieces:
							print 'ignoring',piecename,'because of spin in line',line,'at #',boslines.index(line)
							ignorepieces.append(piecename)
			except:
				print 'failed to open .BOS file for unit',basename
				pass
		recursefoldaoterm(olds3o.root_piece,0,ignorepieces)
		news3ofile=open(opts.outdir+'\\'+file.partition('.')[0]+'.s3o','wb')
		news3ofile.write(olds3o.serialize())
		news3ofile.close()
		