#!/usr/bin/env python

from s3o import *
import vertex_cache
import sys
from Tkinter import *
import tkFileDialog
import math
import os

howtoemit=('''const unsigned int count = piece->GetVertexCount();

	if (count == 0) {
		pos = mat.GetPos();
		dir = mat.Mul(float3(0.0f, 0.0f, 1.0f)) - pos;
	} else if (count == 1) {
		pos = mat.GetPos();
		dir = mat.Mul(piece->GetVertexPos(0)) - pos;
	} else if (count >= 2) {
		float3 p1 = mat.Mul(piece->GetVertexPos(0));
		float3 p2 = mat.Mul(piece->GetVertexPos(1));

		pos = p1;
		dir = p2 - p1;
	} else {
		return false;
	}\	//! we use a 'right' vector, and the positive x axis points to the left
	pos.x = -pos.x;
	dir.x = -dir.x;

	return true;
''')

##if there are zero vertices, the emit direction is 0,0,1, the emit position is the origin of the piece
##if there is 1 vertex, the emit dir is the vector from the origin to the the position of the first vertex the emit position is the origin of the piece
## if there is more than one, then the emit vector is the vector pointing from v[0] to v[1], and the emit position is v[0]
def fix_zero_normals_piece(piece):
	badnormals=0
	fixednormals=0
	if len(piece.indices)>0:
		
		for v_i in range(len(piece.vertices)):
			vertex=piece.vertices[v_i] 
			#print (vertex[1])
			if vectorlength(vertex[1])<0.01: #nearly 0 normal
				badnormals+=1
				if v_i not in piece.indices:
					#this is some sort of degenerate vertex, just replace it's normal with [0,1,0]
					piece.vertices[v_i]=(vertex[0],(0.0,1.0,0.0),vertex[2])
					fixednormals+=1
				else:
					for f_i in range(0,len(piece.indices) ,3):
						if v_i in piece.indices[f_i:min(len(piece.indices),f_i+3)]:
							newnormal = vectorcross(vectorminus(piece.vertices[piece.indices[f_i+1]][0],piece.vertices[piece.indices[f_i]][0]),vectorminus(piece.vertices[piece.indices[f_i+2]][0],piece.vertices[piece.indices[f_i]][0]))
							if vectorlength(newnormal)<0.001:
								piece.vertices[v_i]=(vertex[0],(0.0,1.0,0.0),vertex[2])
							else:
								piece.vertices[v_i]=(vertex[0],normalize(newnormal),vertex[2])
							fixednormals+=1
							break
	if badnormals>0:
		print '[WARN]','Bad normals:',badnormals,'Fixed:',fixednormals
		if badnormals!=fixednormals:
			print '[WARN]','NOT ALL ZERO NORMALS fixed!!!!!' #this isnt possible with above code anyway :/
	# for child in piece.children:
		# fix_zero_normals_piece(child)

def recursively_optimize_pieces(piece):
    if type(piece.indices) == type ([]) and len(piece.indices)>4:
		optimize_piece(piece)
		fix_zero_normals_piece(piece)
    for child in piece.children:
        recursively_optimize_pieces(child)

def chunks(l, n):	
    """ Yield successive n-sized chunks from l.
    """
    for i in range(0, len(l), n):
        yield tuple(l[i:i + n])


def optimize_piece(piece):
    remap = {}
    new_indices = []
    print '[INFO]','Optimizing:',piece.name
    for index in piece.indices:
        vertex = piece.vertices[index]
        if vertex not in remap:
            remap[vertex] = len(remap)
        new_indices.append(remap[vertex])

    new_vertices = [(index, vertex) for vertex, index in remap.items()]
    new_vertices.sort()
    new_vertices = [vertex for index, vertex in new_vertices]

    if piece.primitive_type == "triangles" and len(new_indices) > 0:
        tris = list(chunks(new_indices, 3))
        acmr = vertex_cache.average_transform_to_vertex_ratio(tris)

        tmp = vertex_cache.get_cache_optimized_triangles(tris)
        acmr_new = vertex_cache.average_transform_to_vertex_ratio(tmp)
        if acmr_new < acmr:
            new_indices = []
            for tri in tmp:
                new_indices.extend(tri)

    vertex_map = []
    remapped_indices = []
    for index in new_indices:
        try:
            new_index = vertex_map.index(index)
        except ValueError:
            new_index = len(vertex_map)
            vertex_map.append(index)

        remapped_indices.append(new_index)

    new_vertices = [new_vertices[index] for index in vertex_map]
    new_indices = remapped_indices

    piece.indices = new_indices
    piece.vertices = new_vertices


def sizeof_fmt(num):
    for x in ['bytes', 'KB', 'MB', 'GB']:
        if abs(num) < 1024.0:
            return "%3.1f %s" % (num, x)
        num /= 1024.0
    return "%3.1f%s" % (num, 'TB')



class App:

	def __init__(self, master):
		self.initialdir=os.getcwd()
		master.title('OBJ <--> S3O - By Beherith - Thanks to Muon\'s wonderful s3o library!')
		frame = Frame(master)
		objtos3oframe = Frame(master, bd=1, relief = SUNKEN)
		s3otoobjframe = Frame(master, bd=3, relief = SUNKEN)
		opts3oframe   = Frame(master, bd=3, relief = SUNKEN)
		swaptexframe   = Frame(master, bd=3, relief = SUNKEN)
		frame.pack()
		objtos3oframe.pack(side=TOP,fill=X)
		s3otoobjframe.pack(side=TOP,fill=X)
		opts3oframe.pack(side=TOP,fill=X)
		swaptexframe.pack(side=TOP,fill=X)
		Button(frame, text="QUIT", fg="red", command=frame.quit).pack(side=TOP)
		
		self.prompts3ofilename=IntVar()
		Button(opts3oframe , text='Optimize s3o', command=self.optimizes3o).pack(side=LEFT)
		Label(opts3oframe,text='Removes redundant vertices and performs vertex cache optimization').pack(side=LEFT)
		
		Button(swaptexframe , text='Override texture', command=self.swaptex).pack(side=LEFT)
		Label(swaptexframe,text='Tex1:').pack(side=LEFT)
		self.tex1=StringVar()
		Entry(swaptexframe,width=20,textvariable=self.tex1).pack(side=LEFT)
		Label(swaptexframe,text='Tex2:').pack(side=LEFT)
		self.tex2=StringVar()
		Entry(swaptexframe,width=20,textvariable=self.tex2).pack(side=LEFT)
		
		Button(objtos3oframe , text='Convert OBJ to S3O', command=self.openobj).pack(side=LEFT)
		Checkbutton(objtos3oframe,text='Prompt output filename', variable=self.prompts3ofilename).pack(side=LEFT)
		
		
		Button(s3otoobjframe , text='Convert S3O to OBJ', command=self.opens3o).pack(side=LEFT)		
		self.optimize_for_wings3d=IntVar()
		self.optimize_for_wings3d.set(1)
		
		Checkbutton(s3otoobjframe,text='Optimize for Wings3d', variable=self.optimize_for_wings3d).pack(side=LEFT)

		self.promptobjfilename=IntVar()

		Checkbutton(s3otoobjframe,text='Prompt output filename', variable=self.promptobjfilename).pack(side=LEFT)
		
		self.transform=IntVar()
		Checkbutton(objtos3oframe,text='Transform UV coords:', variable=self.transform).pack(side=LEFT)
		
		Label(objtos3oframe,text='U=').pack(side=LEFT)
		self.transformA=StringVar()
		Entry(objtos3oframe,width=4,textvariable=self.transformA).pack(side=LEFT)
		self.transformA.set('1')
		
		Label(objtos3oframe,text='* U +').pack(side=LEFT)
		self.transformB=StringVar()
		Entry(objtos3oframe,width=4,textvariable=self.transformB).pack(side=LEFT)
		self.transformB.set('0')
		
		Label(objtos3oframe,text='    V=').pack(side=LEFT)
		self.transformC=StringVar()
		Entry(objtos3oframe,width=4,textvariable=self.transformC).pack(side=LEFT)
		self.transformC.set('1')
		
		Label(objtos3oframe,text='* V +').pack(side=LEFT)
		self.transformD=StringVar()
		Entry(objtos3oframe,width=4,textvariable=self.transformD).pack(side=LEFT)
		self.transformD.set('0')
		Label(frame,wraplength=600, justify=LEFT, text ='Instructions and notes:\n1. Converting S3O to OBJ:\n Open an s3o file, and the obj file will be saved with the same name and an .obj extension\n The name of each object in the .obj file will reflect the naming and pieces of the s3o file. All s3o data is retained, and is listed as a series of parameters in the object\'s name.\nExample:\no base,ox=-0.00,oy=0.00,oz=0.00,p=,mx=-0.00,my=4.00,mz=0.00,r=17.50,h=21.00,t1=tex1.png,t2=tex2.png\n ALL s3o info is retained, including piece hierarchy, piece origins, smoothing groups, vertex normals, and even degenerate pieces with no geometry used as emit points and vectors. These emit pieces will be shown as triangles with their correct vertex ordering.\n2. Converting OBJ to S3O:\n The opened .obj file will be converted into s3o. If the piece names contain the information as specified in the above example, the entire model hierarchy will be correctly converted. If it doesnt, then the program will convert each object as a child piece of an empty base object.').pack(side=BOTTOM)

	def openobj(self):
		self.objfile = tkFileDialog.askopenfilename(initialdir= self.initialdir, filetypes = [('Object file','*.obj'),('Any file','*')],multiple = True)
		self.objfile = string2list(self.objfile) 
		for file in self.objfile:
			if 'obj' in file.lower():
				self.initialdir=file.rpartition('/')[0]
				if self.prompts3ofilename.get()==1:
					outputfilename=tkFileDialog.asksaveasfilename(initialdir= self.initialdir,filetypes = [('Spring Model file (S3O)','*.s3o'),('Any file','*')])
					if '.s3o' not in outputfilename.lower():
						outputfilename+='.s3o'
				else:
					outputfilename=file.lower().replace('.obj','.s3o')
				transform=self.transform.get()
				a=b=c=d=0
				if transform==1:
					try:
						a=float(self.transformA.get())
						b=float(self.transformB.get())
						c=float(self.transformC.get())
						d=float(self.transformD.get())
						print '[INFO]','Using an UV space transform U=%.3f * U + %.3f  V=%.3f * V + %.3f'%(a,b,c,d)
					except ValueError:
						print '[WARN]','Failed to parse transformation parameters, ignoring transformation!'
						transform=0
				OBJtoS3O(file, transform,outputfilename,a,b,c,d)
	def opens3o(self):
		self.s3ofile = tkFileDialog.askopenfilename(initialdir= self.initialdir,filetypes = [('Spring Model file (S3O)','*.s3o'),('Any file','*')], multiple = True)
		self.s3ofile = string2list(self.s3ofile) 
		for file in self.s3ofile:
			if 's3o' in file.lower():
				self.initialdir=file.rpartition('/')[0]
				if self.promptobjfilename.get()==1:
					outputfilename=tkFileDialog.asksaveasfilename(initialdir= self.initialdir,filetypes = [('Object file','*.obj'),('Any file','*')])
					if '.obj' not in outputfilename.lower():
						outputfilename+='.obj'
				else:
					outputfilename=file.lower().replace('.s3o','.obj')
				S3OtoOBJ(file,outputfilename,self.optimize_for_wings3d.get()==1)
	def optimizes3o(self):
		self.s3ofile = tkFileDialog.askopenfilename(initialdir= self.initialdir,filetypes = [('Spring Model file (S3O)','*.s3o'),('Any file','*')], multiple = True)
		self.s3ofile = string2list(self.s3ofile) 
		for file in self.s3ofile:
			if 's3o' in file.lower():
				self.initialdir=file.rpartition('/')[0]
				optimizeS3O(file)
	def swaptex(self):
		self.s3ofile = tkFileDialog.askopenfilename(initialdir= self.initialdir,filetypes = [('Spring Model file (S3O)','*.s3o'),('Any file','*')], multiple = True)
		self.s3ofile = string2list(self.s3ofile) 
		for file in self.s3ofile:
			if 's3o' in file.lower():
				self.initialdir=file.rpartition('/')[0]
				swaptex(file,self.tex1.get(),self.tex2.get())
def string2list(input_string):
	if '{' not in input_string:# and input_string.count(':')>1:
		return input_string
	input_string = input_string.lstrip('{')
	input_string = input_string.rstrip('}')
	output = input_string.split('} {')
	return output
def S3OtoOBJ(filename,outputfilename,optimize_for_wings3d=True):
	if '.s3o' in filename.lower():
		data=open(filename,'rb').read()
		model=S3O(data)
		model.S3OtoOBJ(outputfilename,optimize_for_wings3d)
		print '[INFO]',"Succesfully converted", filename,'to',outputfilename
def OBJtoS3O(objfile,transform,outputfilename,a,b,c,d):
	if '.obj' in objfile.lower():
		data = open(objfile).readlines()
		if transform==1:
			for line in range(len(data)):
				if data[line][0:2]=='vt':
					s=data[line].split(' ')
					data[line]=' '.join([s[0],str(float(s[1])*a+b),str(float(s[2])*c+d)])
		isobj=True
		model = S3O(data,isobj)
		recursively_optimize_pieces(model.root_piece)
		optimized_data = model.serialize()
		output_file=open(outputfilename,'wb')
		output_file.write(optimized_data)
		output_file.close()
	#	if (self.tex1.get()!='' and self.tex2.get()!=''):
	#		swaptex(outputfilename, self.tex1.get(),self.tex2.get())
		print '[INFO]',"Succesfully converted", objfile,'to',outputfilename
		
def swaptex(filename,tex1,tex2):
	datafile=open(filename,'rb')
	data=datafile.read()
	model=S3O(data)
	model.texture_paths=[tex1,tex2]
	datafile.close()
	print '[INFO]','Changed texture to',tex1,tex2
	output_file=open(filename,'wb')
	output_file.write(model.serialize())
	output_file.close()
	print '[INFO]',"Succesfully optimized", filename
def optimizeS3O(filename):
	datafile=open(filename,'rb')
	data=datafile.read()
	model=S3O(data)
	pre_vertex_count=countvertices(model.root_piece)
	recursively_optimize_pieces(model.root_piece)
	optimized_data = model.serialize()
	datafile.close()
	print '[INFO]','Number of vertices before optimization:',pre_vertex_count,' after optimization:',countvertices(model.root_piece)
	output_file=open(filename,'wb')
	output_file.write(optimized_data)
	output_file.close()
	print '[INFO]',"Succesfully optimized", filename
def countvertices(piece):
	numverts=len(piece.vertices)
	for child in piece.children:
		numverts+=countvertices(child)
	return numverts
root = Tk()
app = App(root)
root.mainloop()