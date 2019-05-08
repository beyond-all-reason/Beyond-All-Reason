#!/usr/bin/env python

import sys
import struct
import math
import operator



_S3OHeader_struct = struct.Struct("< 12s i 5f 4i")
_S3OPiece_struct = struct.Struct("< 10i 3f")
_S3OVertex_struct = struct.Struct("< 3f 3f 2f")
_S3OChildOffset_struct = struct.Struct("< i")
_S3OIndex_struct = struct.Struct("< i")


def _get_null_terminated_string(data, offset):
	if offset == 0:
		return b""
	else:
		return data[offset:data.index(b'\x00', offset)]


class S3O(object):
	def S3OtoOBJ(self,filename):
		objfile=open(filename,'w')
		objfile.write('# Spring Unit export, Created by Beherith mysterme@gmail.com with the help of Muon \n')
		objfile.write('# arguments of an object \'o\' piecename:\n# Mxyz = midpoint of an s3o\n# r = unit radius\n# h = height\n# t1 t2 = textures 1 and 2\n# Oxyz = piece offset\n# p = parent\n')
		header='mx=%.2f,my=%.2f,mz=%.2f,r=%.2f,h=%.2f,t1=%s,t2=%s'%(
			self.midpoint[0],
			self.midpoint[1],
			self.midpoint[2],
			self.collision_radius,
			self.height,
			self.texture_paths[0].replace('\0',''),
			self.texture_paths[1].replace('\0','')
			)
		obj_vertindex=0
		obj_normal_uv_index=0# obj indexes vertices from 1
		
		self.recurseS3OtoOBJ(self.root_piece,objfile,header,obj_vertindex,obj_normal_uv_index,0,(0,0,0))
		
	def closest_vertex(self, vtable, q,tolerance): #returns the index of the closest vertex pos
		v=vtable[q][0]
		for i in range(len(vtable)):
			v2=vtable[i][0]
			if abs(v2[0]-v[0])<tolerance and abs(v2[1]-v[1])<tolerance and abs(v2[2]-v[2])<tolerance:
				#if i!=q:
					#print i,'matches',q
				return i
		print 'warning, no matching vertex, not even self!'
		return q
	def in_smoothing_group(self,piece, a,b,tolerance,step): #returns wether the two primitives shared a smoothed edge
		shared=0
		for va in range(a,a+step):
			for vb in range(b,b+step):
				v=piece.vertices[piece.indices[va]]
				v2=piece.vertices[piece.indices[vb]]
				if abs(v2[0][0]-v[0][0])<tolerance and abs(v2[0][1]-v[0][1])<tolerance and abs(v2[0][2]-v[0][2])<tolerance:
					if abs(v2[1][0]-v[1][0])<tolerance and abs(v2[1][1]-v[1][1])<tolerance and abs(v2[1][2]-v[1][2])<tolerance:
						shared+=1
		if shared >=3:
			print shared,'shared and normal matching vertices faces',a,b,piece.name
		return shared==2
	def recurseS3OtoOBJ(self, piece,objfile,extraargs,vi,nti,groups,offset): #vi is our current vertex index counter, nti is the normal/texcoord index counter
		#If we dont use shared vertices in a OBJ file in wings, it wont be able to merge vertices, so we need a mapping to remove redundant vertices, normals and texture indices are separate
		parent=''
		oldnti=nti
		
		if piece.parent!=None:
			parent=piece.parent.name
			print 'parentname=',piece.parent.name
		# objfile.write('o %s,ox=%.2f,oy=%.2f,oz=%.2f,p=%s,%s\n'%(
			# piece.name,
			# piece.parent_offset[0],
			# piece.parent_offset[1],
			# piece.parent_offset[2],
			# parent,
			# extraargs))

		vdata_obj=[]#vertex, normal and UV in the piece
		fdata_obj=[]#holds the faces in the piece
		vertexmap={}
		hash={}
		vcount=0
		step=3 #todo: fix for not just triangles
		if piece.primitive_type == 'triangles':
			step=3
		elif piece.primitive_type == 'quads':
			step=4
		print piece.name,'has',piece.primitive_type,step
		if len(piece.indices)>=step and piece.primitive_type!="triangle strips":
			objfile.write('o %s,ox=%.2f,oy=%.2f,oz=%.2f,p=%s,%s\n'%(
				piece.name,
				piece.parent_offset[0],
				piece.parent_offset[1],
				piece.parent_offset[2],
				parent,
				extraargs))
			print 'piece',piece.name,'has more than 3 vert indices'
			for k in range(0,len(piece.indices),step): #iterate over faces
				facestr='f'
				for i in range(step):
					try:
						v=piece.vertices[piece.indices[k+i]]
					except:
						print 'k',k,'i',i,'#index',len(piece.indices),'#vert',len(piece.vertices),'vert[index]',piece.indices[k+i]
						raise
					closest=self.closest_vertex(piece.vertices,piece.indices[k+i],0.1)
					vertexmap[piece.indices[k+i]]=closest
					
					if closest not in hash:
						#print 'closest',closest,'not in hash',hash
						vcount+=1
						hash[closest]=vcount
						vdata_obj.append('v %f %f %f\n'%(v[0][0]+offset[0]+piece.parent_offset[0],v[0][1]+offset[1]+piece.parent_offset[1],v[0][2]+offset[2]+piece.parent_offset[2]))
					vdata_obj.append('vn %f %f %f\n'%(v[1][0],v[1][1],v[1][2]))
					vdata_obj.append('vt %f %f\n'%(v[2][0],v[2][1]))
					nti+=1				
					#if 1==1: #closest>=piece.indices[k+i]: #no matching vert
					
					facestr+=' %i/%i/%i'%(vi+hash[closest],nti,nti)
					
					
				fdata_obj.append(facestr+'\n')
			for l in vdata_obj:
				objfile.write(l)
			#now its time to smooth this bitch!
			#how wings3d processes obj meshes:
			# if no normals are specified, it merges edges correctly, but all edges are soft
			# if normals are specified, but there are no smoothing groups, it will treat each smoothed group as a separate mesh in an object
			# if normals AND smoothing groups are specified, it works as it should
			
			faces={}
		
			for face1 in range(0,len(piece.indices),step):
				#for f2 in range(f1+step,len(piece.indices),step):
				for face2 in range(0,len(piece.indices),step):
					if face1!=face2 and self.in_smoothing_group(piece,face1,face2,0.01,step):
						f1=face1/step
						f2=face2/step
						if f1 in faces and f2 in faces:
							if faces[f2]!=faces[f1]:
								print 'conflicting smoothing groups!',f1,f2,faces[f1],faces[f2], 'resolving with merge!'
								greater=max(faces[f2],faces[f1])
								lesser=min(faces[f2],faces[f1])
								for faceindex in faces.iterkeys():
									if faces[faceindex]==greater:
										faces[faceindex]=lesser
									elif faces[faceindex]>greater:
										faces[faceindex]-=1
								groups-=1
							# else:
								# print 'already in same group, yay!',f1,f2,faces[f1],faces[f2]
						elif f1 in faces:
							faces[f2]=faces[f1]
						elif f2 in faces:
							faces[f1]=faces[f2]
						else:
							groups+=1
							faces[f1]=groups
							faces[f2]=groups
				#if a face shares any two optimized position vertices and has equal normals on that, it is in one smoothing group.
				#does it work for any 1 
			groupids=set(faces.values())
			print 'sets of smoothing groups in piece',piece.name,'are',groupids,groups
			
			nonsmooth_faces=False
			for l in range(len(fdata_obj)):
				if l not in faces:
					nonsmooth_faces=True
			if nonsmooth_faces:
				objfile.write('s off\n')
			for l in range(len(fdata_obj)):
				if l not in faces:
					objfile.write(fdata_obj[l])
			for k in groupids:
				objfile.write('s '+str(k)+'\n')
				for l in range(len(fdata_obj)):
					if l in faces and faces[l]==k:
						objfile.write(fdata_obj[l])
			print 'Optimized vertex count=',vcount,'unoptimized count=',nti-oldnti
		elif piece.primitive_type== "triangle strips":
			print piece.name,'has a triangle strip type, this is unsupported by this application, skipping piece!'
		else:
			print 'empty piece',piece.name,'writing placeholder face with primitive type',piece.primitive_type, '#vertices=',len(piece.vertices),'#indices=',len(piece.indices)
			objfile.write('o %s,ox=%.2f,oy=%.2f,oz=%.2f,p=%s,%s,e=%i\n'%(
				piece.name,
				piece.parent_offset[0],
				piece.parent_offset[1],
				piece.parent_offset[2],
				parent,
				extraargs,
				len(piece.vertices)))
			if len(piece.vertices)==0:
				objfile.write('v %f %f %f\n'%(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2]))
				objfile.write('v %f %f %f\n'%(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],4+offset[2]+piece.parent_offset[2]))
				objfile.write('v %f %f %f\n'%(offset[0]+piece.parent_offset[0],2+offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2]))
				#objfile.write('v 0 0 0\n')
				#objfile.write('v 0 0 1\n')
				objfile.write('f %i/1/1 %i/2/2/ %i/3/3\n'%(vi+1,vi+2,vi+3))
				vcount+=3
			elif len(piece.vertices)==1:
				print 'emit vertices:',piece.vertices,'offset:  %f %f %f\n'%(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2])
				v=piece.vertices[0]
				objfile.write('v %f %f %f\n'%(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2]))
				objfile.write('v %f %f %f\n'%(v[0][0]+offset[0]+piece.parent_offset[0],v[0][1]+offset[1]+piece.parent_offset[1],v[0][2]+offset[2]+piece.parent_offset[2]))
				objfile.write('v %f %f %f\n'%(offset[0]+piece.parent_offset[0],2+offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2]))
				#objfile.write('v 0 0 0\n')
				#objfile.write('v 0 0 1\n')
				objfile.write('f %i/1/1 %i/2/2/ %i/3/3\n'%(vi+1,vi+2,vi+3))
				vcount+=3
			elif len(piece.vertices)==2:
				print 'emit vertices:',piece.vertices,'offset:  %f %f %f\n'%(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2])
				v=piece.vertices[0]
				objfile.write('v %f %f %f\n'%(v[0][0]+offset[0]+piece.parent_offset[0],v[0][1]+offset[1]+piece.parent_offset[1],v[0][2]+offset[2]+piece.parent_offset[2]))
				v=piece.vertices[1]
				objfile.write('v %f %f %f\n'%(v[0][0]+offset[0]+piece.parent_offset[0],v[0][1]+offset[1]+piece.parent_offset[1],v[0][2]+offset[2]+piece.parent_offset[2]))
				v=piece.vertices[0]
				objfile.write('v %f %f %f\n'%(v[0][0]+offset[0]+piece.parent_offset[0],2+v[0][1]+offset[1]+piece.parent_offset[1],v[0][2]+offset[2]+piece.parent_offset[2]))
				
				
				#objfile.write('v 0 0 0\n')
				#objfile.write('v 0 0 1\n')
				objfile.write('f %i/1/1 %i/2/2/ %i/3/3\n'%(vi+1,vi+2,vi+3))
				vcount+=3
			else:
				print piece.name,': failed to write as it looks invalid'
			#print 'empty piece',piece.name,'writing placeholder face with primitive type',piece.primitive_type
		vi=vi+vcount
		for child in piece.children:
			(vi,nti)=self.recurseS3OtoOBJ(child,objfile,'',vi,nti,groups,(offset[0]+piece.parent_offset[0],offset[1]+piece.parent_offset[1],offset[2]+piece.parent_offset[2]))
		return (vi,nti)
	def __init__(self, data, isobj=False):
		if not isobj:
			header = _S3OHeader_struct.unpack_from(data, 0)

			magic, version, radius, height, mid_x, mid_y, mid_z, \
			root_piece_offset, collision_data_offset, tex1_offset, \
			tex2_offset = header

			assert(magic == b'Spring unit\x00')
			assert(version == 0)
			assert(collision_data_offset == 0)

			self.collision_radius = radius
			self.height = height
			self.midpoint = (mid_x, mid_y, mid_z)

			self.texture_paths = (_get_null_terminated_string(data, tex1_offset),
								  _get_null_terminated_string(data, tex2_offset))
			self.root_piece = S3OPiece(data, root_piece_offset)
		else:
			objfile=data
			self.collision_radius=0
			self.height=0
			self.midpoint=[0,0,0]
			self.texture_paths=['Arm_color.dds'+b'\x00','Arm_other.dds'+b'\x00']
			self.root_piece=S3OPiece('',(0,0,0))
			self.root_piece.parent = None
			self.root_piece.name = 'empty_root_piece'+b'\x00'
			self.root_piece.primitive_type = 'triangles' #triangles
			self.root_piece.parent_offset =(0,0,0)
			self.root_piece.vertices = []
			self.root_piece.indices = []
			self.root_piece.children = []
			i=0				
			verts=[]
			normals=[]
			uvs=[]
			warn=0
			piecedict={}
			calcheight=0
			while(i<len(objfile)):
				print '.',
				if objfile[i][0]=='o':
					piece=S3OPiece('',(0,0,0))
					piece.parent=self.root_piece
					piece.parent_offset=(0,0,0)
					piece.name=''
					params=objfile[i].partition(' ')[2].strip().split(',')
					emittype=10000000
					piece.parent_offset=(0,0,0)
					for p in params:
						if '=' in p:
							try:
								kv=p.partition('=')
								if kv[0]=='t1':
									self.texture_paths[0]=kv[2]+b'\x00'
								if kv[0]=='t2':
									self.texture_paths[1]=kv[2]+b'\x00'
								if kv[0]=='h':
									self.height=float(kv[2])
								if kv[0]=='r':
									self.collision_radius=float(kv[2])
								if kv[0]=='mx':
									self.midpoint[0]=float(kv[2])
								if kv[0]=='my':
									self.midpoint[1]=float(kv[2])
								if kv[0]=='mz':
									self.midpoint[2]=float(kv[2])
								if kv[0]=='ox':
									piece.parent_offset=(float(kv[2]),piece.parent_offset[1],piece.parent_offset[2])
								if kv[0]=='oy':
									piece.parent_offset=(piece.parent_offset[0],float(kv[2]),piece.parent_offset[2])
								if kv[0]=='oz':
									piece.parent_offset=(piece.parent_offset[0],piece.parent_offset[1],float(kv[2]))
								if kv[0]=='e':
									emittype=int(kv[2])
								if kv[0]=='p':
									piece.parent=kv[2]+b'\x00'
								print kv
							except ValueError:
								print 'Failed to parse parameter',p,'in',objfile[i]
					piece.name=objfile[i].partition(' ')[2].strip().partition(',')[0][0:20]+b'\x00' #why was I limiting piece names to 10 length?
					piece.primitive_type='triangles' #tris
					
					piece.children=[]
					piece.indices=[]
					piece.vertices=[]
					
					i+=1
					while (i<len(objfile) and objfile[i][0]!='o'):
						part=objfile[i].partition(' ')
						if part[0]=='v':# and len(verts)<emittype:
							v=map(float,part[2].split(' '))
							verts.append((v[0],v[1],v[2]))
						elif part[0]=='vn':# and len(verts)<emittype:
							vn=map(float,part[2].split(' '))
							lensqr=vn[0]**2+vn[1]**2+vn[2]**2
							if lensqr>0.0002 and math.fabs(lensqr-1.0) > 0.001:
								sqr=math.sqrt(lensqr)
								vn[0]/=sqr
								vn[1]/=sqr
								vn[2]/=sqr
							normals.append((vn[0],vn[1],vn[2]))
						elif part[0]=='vt':# and len(verts)<emittype:
							vt=map(float,part[2].split(' '))
							uvs.append((vt[0],vt[1]))
						elif part[0]=='f' and emittype ==10000000: #only add faces if its not an emit type primitive( meaning it should have no geometry)
							face=part[2].split(' ')
							if len(face)>3:
								warn=1
							for triangle in range(len(face)-2):	
								for face_index in range(triangle,triangle+3):
									faceindexold=face_index
									if face_index==triangle: #trick when tesselating, It uses the first vert of the face for every triangle of a polygon
										face_index=0
									face_index=face[face_index].split('/')
									v=(0,0,0)
									vn=(0,0,0)
									vt=(0,0)
									if face_index[0]!='':
										try:
											v=verts[int(face_index[0])-1] #-1 is needed cause .obj indexes from 1
											calcheight=max(calcheight,math.ceil(v[1]))
										except IndexError:
											print 'indexing error! while converting piece',piece.name
											print objfile[i]
											print 'wanted index:', face_index[0],'len(verts)=',len(verts)
									if face_index[1]!='':
										vt=uvs[int(face_index[1])-1]
									if face_index[2]!='':
										vn=normals[int(face_index[2])-1]
									if emittype!=10000000:
										if int(faceindexold)<emittype:
											v=verts[int(face_index[0])-1]
											piece.vertices.append((v,vn,vt))
									else:
										piece.vertices.append((v,vn,vt))
									#print len(piece.vertices),piece.vertices[-1]
									piece.indices.append(len(piece.indices))
						i+=1
					self.root_piece.children.append(piece)
					piecedict[piece.name]=piece
				else:
					i+=1
				if self.height==0:
					self.height=calcheight
				if self.collision_radius==0:
					self.collision_radius=math.ceil(calcheight/2)
				#self.midpoint[1]=math.ceil(self.collision_radius-3)
			#if the parents are specified, we need to rebuild the hierarchy!
			#we need to rebuild post loading, because we cant be sure that the external modification of the obj file retained the piece order
			newroot=self.root_piece
			for pieceindex in range(len(self.root_piece.children)):
				piece=self.root_piece.children[pieceindex]
				parentname=piece.parent
				if type(parentname)==type(''):
					print piece.name,'has a parent called:',parentname
					if parentname== b'\x00':
						newroot=piecedict[piece.name]
						print 'the new root piece is',piece.name
					elif parentname in piecedict:
						print 'assigning',piece.name,'to', piece.parent
						piecedict[parentname].children.append(piece)
						piece.parent=piecedict[parentname]
					else:
						print 'parent name',parentname,'not in piece dict!',piecedict,'adding it to the root piece'
						newroot.children.append(piece)
			print newroot
			self.root_piece=newroot
			#now that we have the hiearchy set up right, its time to calculate offsets!
			self.adjustobjtos3ooffsets(self.root_piece,0,0,0)
			#now that we have the hiearchy set up right, its time to calculate offsets!
			
			if warn==1:
				print 'Warning: one or more faces had more than 3 vertices, so triangulation was used. This can produce bad results with concave polygons'
	def adjustobjtos3ooffsets(self,piece,curx,cury,curz):
		#print 'adjusting offsets of',piece.name,': current:',curx,cury,curz,'parent offsets:',piece.parent_offset
		for i in range(len(piece.vertices)):
			
			v=piece.vertices[i]
			
			v=((v[0][0]-curx-piece.parent_offset[0],v[0][1]-cury-piece.parent_offset[1],v[0][2]-curz-piece.parent_offset[2]),v[1],v[2])
			#print 'offset:',v[0],piece.vertices[0][0]
			piece.vertices[i]=v
		for child in piece.children:
			self.adjustobjtos3ooffsets(child,curx+piece.parent_offset[0],cury+piece.parent_offset[1],curz+piece.parent_offset[2])
	def serialize(self):
		encoded_texpath1 = self.texture_paths[0] + b'\x00'
		encoded_texpath2 = self.texture_paths[1] + b'\x00'

		tex1_offset = _S3OHeader_struct.size
		tex2_offset = tex1_offset + len(encoded_texpath1)
		root_offset = tex2_offset + len(encoded_texpath2)

		args = (b'Spring unit\x00', 0, self.collision_radius, self.height,
			   self.midpoint[0], self.midpoint[1], self.midpoint[2],
			   root_offset, 0, tex1_offset, tex2_offset)

		header = _S3OHeader_struct.pack(*args)

		data = header + encoded_texpath1 + encoded_texpath2
		data += self.root_piece.serialize(len(data))

		return data


class S3OPiece(object):
	# def __init__(self, data, offset, parent, i):
		# for l in data:
			# if l[0]=='o':
				
	def __init__(self, data, offset, parent=None):
		if data!='':
			piece = _S3OPiece_struct.unpack_from(data, offset)

			name_offset, num_children, children_offset, num_vertices, \
			vertex_offset, vertex_type, primitive_type, num_indices, \
			index_offset, collision_data_offset, x_offset, y_offset, \
			z_offset = piece

			self.parent = parent
			self.name = _get_null_terminated_string(data, name_offset)
			self.primitive_type = ["triangles",
								   "triangle strips",
								   "quads"][primitive_type]
			self.parent_offset = (x_offset, y_offset, z_offset)

			self.vertices = []
			for i in range(num_vertices):
				current_offset = vertex_offset + _S3OVertex_struct.size * i
				vertex = _S3OVertex_struct.unpack_from(data, current_offset)

				position = vertex[:3]
				normal = vertex[3:6]
				texcoords = vertex[6:]

				self.vertices.append((position, normal, texcoords))

			self.indices = []
			for i in range(num_indices):
				current_offset = index_offset + _S3OIndex_struct.size * i
				index, = _S3OIndex_struct.unpack_from(data, current_offset)
				self.indices.append(index)

			self.children = []
			for i in range(num_children):
				cur_offset = children_offset + _S3OChildOffset_struct.size * i
				child_offset, = _S3OChildOffset_struct.unpack_from(data, cur_offset)
				self.children.append(S3OPiece(data, child_offset,self))
		
	def serialize(self, offset):
		name_offset = _S3OPiece_struct.size + offset
		encoded_name = self.name + b'\x00'

		children_offset = name_offset + len(encoded_name)
		child_data = b''
		# HACK: make an empty buffer to put size in later
		for i in range(len(self.children)):
			child_data += _S3OChildOffset_struct.pack(i)

		vertex_offset = children_offset + len(child_data)
		vertex_data = b''
		for pos, nor, uv in self.vertices:
			vertex_data += _S3OVertex_struct.pack(pos[0], pos[1], pos[2],
												  nor[0], nor[1], nor[2],
												  uv[0], uv[1])

		index_offset = vertex_offset + len(vertex_data)
		index_data = b''
		for index in self.indices:
			vertex_data += _S3OIndex_struct.pack(index)

		primitive_type = {"triangles": 0,
						  "triangle strips": 1,
						  "quads": 2}[self.primitive_type]

		args = (name_offset, len(self.children), children_offset,
				len(self.vertices), vertex_offset, 0, primitive_type,
				len(self.indices), index_offset, 0) + self.parent_offset

		piece_header = _S3OPiece_struct.pack(*args)

		child_offsets = []

		data = piece_header + encoded_name + child_data + vertex_data + index_data

		serialized_child_data = b''
		for child in self.children:
			child_offset = offset + len(data) + len(serialized_child_data)
			child_offsets.append(child_offset)
			serialized_child_data += child.serialize(child_offset)

		child_data = b''
		for child_offset in child_offsets:
			child_data += _S3OChildOffset_struct.pack(child_offset)

		data = piece_header + encoded_name + child_data + vertex_data + \
			   index_data + serialized_child_data

		return data
