import sys
import os
import copy
import math
from s3o import S3O,S3OPiece

from Tkinter import *
# from ttk import *
import tkFileDialog
import tkFont
import collections
import random
PieceInfo = collections.namedtuple('Pieceinfo', 'name pname vol verts children emptychildren d')
# severities: wreck, heap, destroy

class VerticalScrolledFrame(Frame):
	"""A pure Tkinter scrollable frame that actually works!
	* Use the 'interior' attribute to place widgets inside the scrollable frame
	* Construct and pack/place/grid normally
	* This frame only allows vertical scrolling

	"""
	def __init__(self, parent, *args, **kw):
		Frame.__init__(self, parent, *args, **kw)			

		# create a canvas object and a vertical scrollbar for scrolling it
		vscrollbar = Scrollbar(self, orient=VERTICAL, width=24)
		vscrollbar.pack(fill=Y, side=RIGHT, expand=FALSE)
		canvas = Canvas(self, bd=0, highlightthickness=0,
						yscrollcommand=vscrollbar.set)
		canvas.pack(side=LEFT)#, fill=BOTH, expand=TRUE)
		vscrollbar.config(command=canvas.yview)
		self.vscrollbar=vscrollbar
		# reset the view
		canvas.xview_moveto(0)
		canvas.yview_moveto(0)
		self.canvas=canvas

		# create a frame inside the canvas which will be scrolled with it
		self.interior = interior = Frame(canvas)#,bg='red', bd=5)
		interior_id = canvas.create_window(0, 0, window=interior,
										   anchor=NW)

		# track changes to the canvas and frame width and sync them,
		# also updating the scrollbar
		def _configure_interior(event):
			# update the scrollbars to match the size of the inner frame
			size = (interior.winfo_reqwidth(), interior.winfo_reqheight())
			canvas.config(scrollregion="0 0 %s %s" % size)
			#print '_configure_interior', size, interior.winfo_reqwidth(),interior.winfo_reqheight()
			if interior.winfo_reqwidth() != canvas.winfo_width():
				# update the canvas's width to fit the inner frame
				# canvas.config(width=interior.winfo_reqwidth())
				canvas.config(width=800)
			if interior.winfo_reqheight() != canvas.winfo_height(): #uncommenting this makes it expand to full, but scrolling still does not work
				# update the canvas's width to fit the inner frame
				canvas.config(height=min(interior.winfo_reqheight(),900))
			
		interior.bind('<Configure>', _configure_interior)

		def _configure_canvas(event):
			if interior.winfo_reqwidth() != canvas.winfo_width():
				# update the inner frame's width to fill the canvas
				canvas.itemconfigure(interior_id, width=canvas.winfo_width())#, height=canvas.winfo_height())
			#print '_configure_canvas', interior.winfo_reqwidth(),canvas.winfo_width(),interior.winfo_reqheight(),canvas.winfo_width()
		canvas.bind('<Configure>', _configure_canvas)

class App:

	def __init__(self, master):
		# root = Tk.__init__(self, *args, **kwargs)
		self.initialdir=os.getcwd()
		master.title('Dr. Killinger - By Beherith - Thanks to Muon\'s wonderful s3o library!')
		self.frame = Frame(master)#, bg='yellow', bd=10)
		self.topframe = Frame(self.frame, bd=1, relief = SUNKEN)
		self.bottomframe = Frame(self.frame)#, bd=5, bg='green', relief = SUNKEN)
		self.bottomframe.pack(side=RIGHT, fill=BOTH,expand=1)
		self.VSF = VerticalScrolledFrame(self.bottomframe)
		self.severitiesframe =Frame(self.VSF.interior,width=750)#, bg='blue',bd=10)
		#self.VSF.interior.pack(side=TOP)#,fill=BOTH,expand=1) #THIS MAKES IT ALL GO TO SHIT DO NOT UNCOMMENT
		self.VSF.pack(fill=BOTH)
		self.frame.pack(side=TOP,fill=BOTH, expand = 1)
		self.topframe.pack(side=LEFT,fill=BOTH)
		self.severitiesframe.pack(side=BOTTOM,fill=BOTH,expand=1)
		
		self.validflags=['SHATTER','EXPLODE_ON_HIT','FALL','SMOKE','FIRE','BITMAPONLY','NO_CEG_TRAIL','NO_HEATCLOUD']
		#self.validflags=['SHATTER','EXPLODE','FALL','SMOKE','FIRE','NONE','NO_CEG_TRAIL','NO_HEATCLOUD']
		self.menuframe=Frame(self.topframe,bd=3,relief=SUNKEN)
		self.treeframe=Frame(self.topframe,bd=2,relief=SUNKEN)
		self.menuframe.pack(side=TOP,fill=Y)
		self.treeframe.pack(side=TOP,fill=Y)
		self.outputbasedir='output'
		#=========MENUFRAME STUFF:
		Button(self.menuframe, text="QUIT", fg="red", command=self.frame.quit).pack(side=TOP)
		Button(self.menuframe, text="Load mod",  command=self.loadmod).pack(side=TOP)
		Button(self.menuframe, text="Load unit", command=self.loadunit).pack(side=TOP)
		Button(self.menuframe, text="Write bos", command=self.writebos).pack(side=TOP)
		Button(self.menuframe, text="Next unit", command=self.nextunit).pack(side=TOP)
		Button(self.menuframe, text="Prev unit", command=self.prevunit).pack(side=TOP)
		Button(self.menuframe, text="Wreck unit", command=self.wreckunit).pack(side=TOP)
		Button(self.menuframe, text="Wreck unit S3O only", command=self.wreckunits3o).pack(side=TOP)
		Button(self.menuframe, text="AUTO CONFIG", command=self.autoconf).pack(side=TOP)
		self.tex1=StringVar()
		self.tex2=StringVar()
		Entry(self.menuframe,width=25,textvariable=self.tex1).pack(side=TOP)
		Entry(self.menuframe,width=25,textvariable=self.tex2).pack(side=TOP)
		self.labelvar=StringVar()
		Label(self.menuframe,textvariable=self.labelvar).pack(side=TOP)
		self.labelvar.set('This is my magic murder bag')
		
		##========================
		
		##TREEFRAME:
		self.treefont=tkFont.Font(family='Courier New',size=8)
		self.treelabeltext=StringVar()
		
		self.treelabeltext.set('Tree goes here')
		self.treelabel=Label(self.treeframe, textvariable=self.treelabeltext, justify=LEFT, font=self.treefont)
		self.treelabel.pack(side=LEFT)
		
		##============================
		
		##==severityframe;
		self.makeseverityframes()
		#======
		
		#==== common objects:
		self.unitname=''
		self.modpath=''
		self.unitdefpath=''
		self.bospath=''
		self.s3opath=''
		self.s3o=0
		self.bos=0
		self.unitdef=0
		self.piecelist=[]
		self.killscript=[]
		self.keeplist=[]
		
		self.severitylevels=[25,50,99,-1]
		self.piecetree=[]#((piece.name, parentname, piecevol, indices, len(piece.children)), #emptychildren,depth)'name pname vol indices children emptychildren depth'
		#=====
		#self.loadunit(os.getcwd()+'/units/armjuno.lua')
	def makeseverityframes(self):
		self.wreckframe=Frame(self.severitiesframe,bd=3,relief=SUNKEN,width=750)
		self.wreckframe.pack(side=TOP,fill=X)
		Label(self.wreckframe, text='Wreck').pack(side=LEFT)		
		
		self.heapframe=Frame(self.severitiesframe,bd=3,relief=SUNKEN,width=750)
		self.heapframe.pack(side=TOP,fill=X)
		Label(self.heapframe, text='Heap').pack(side=LEFT)		
		
		self.destroyframe=Frame(self.severitiesframe,bd=3,relief=SUNKEN,width=750)
		self.destroyframe.pack(side=TOP,fill=X)
		Label(self.destroyframe, text='Destroy').pack(side=LEFT)
		
		self.annihilateframe=Frame(self.severitiesframe,bd=3,relief=SUNKEN,width=750)
		self.annihilateframe.pack(side=TOP,fill=X)
		Label(self.annihilateframe, text='SelfD').pack(side=LEFT)
		self.uiframes=[self.wreckframe,self.heapframe,self.destroyframe,self.annihilateframe]
		
		self.severitiesframe.pack(side=BOTTOM,fill=BOTH,expand=1)
	def deleteseverityframes(self):
		self.wreckframe.pack_forget()
		self.wreckframe.destroy()
		self.heapframe.pack_forget()
		self.heapframe.destroy()
		self.destroyframe.pack_forget()
		self.destroyframe.destroy()
		self.annihilateframe.pack_forget()
		self.annihilateframe.destroy()
	def loadmod(self):
		print 'vscrollbar.get',self.VSF.vscrollbar.get()
		self.VSF.canvas.yview_moveto(20)
		return
	def loadunit(self, default=''):
		self.deleteseverityframes()
		self.makeseverityframes()
		self.piecelist=[]
		self.killscript=[]
		self.keeplist=[]
		self.piecetree=[]
		self.severitylevels=[25,50,99,-1]
		self.bos=0
		self.s3o=0
		if default=='':
			self.unitdefpath=tkFileDialog.askopenfilename(initialdir= self.initialdir,filetypes = [('Spring Model def (Lua)','*.lua'),('Any file','*')], multiple = False)
		else:
			self.unitdefpath=default
		print 'loading',self.unitdefpath
		if '.lua' in self.unitdefpath:
			self.modpath=self.unitdefpath.partition('units')[0]
			self.unitname=self.unitdefpath.rpartition('/')[2].partition('.')[0]
			self.labelvar.set(self.unitname.upper())
			self.bospath=self.modpath+'scripts/Units/'+self.unitname+'.bos'
			self.s3opath=self.modpath+'objects3d/Units/'+self.unitname+'.s3o'
			self.outputdir=self.modpath+self.outputbasedir
			try:
				self.s3o=S3O(open(self.s3opath,'rb').read())
				try:
					self.bos=open(self.bospath,'r').readlines()
				except:
					print 'Could not open .bos file, using blank instead'
					self.bos=[]
				self.unitdef=open(self.unitdefpath,'r').readlines()
				if 'Arm' in self.s3o.texture_paths[0]:
					self.tex1.set("Arm_wreck_color.dds")
					self.tex2.set("Arm_wreck_other.dds")
				else:
					self.tex1.set("Core_color_wreck.dds")
					self.tex2.set("Core_other_wreck.dds")
			except:
				raise
			print 'loaded',self.unitname,'successfully'
			self.updatetree(self.s3o,self.piecelist)
			print self.piecelist
			self.killscript=self.loadbos(self.bos)
			print self.killscript
			self.createui(self.killscript)
			self.keeplist=copy.deepcopy(self.piecelist)
		return
	def updatetree(self,model,pl):
		namejust=20
		treestr='NAME          volume (elmos) #tris  ox   oy   oz\n'+self.recursepiecetree(model.root_piece,0,(0,0,0),pl,'root')
		self.treelabeltext.set(treestr)
	def createui(self,killtable):
		
		i=0
		for ctype in killtable:
			
			sevframe=Frame(self.uiframes[i])
			sevframe.pack(side=TOP,fill=X)
			sev=self.severitylevels[i]
			if 'severity' in ctype:
				sev=ctype['severity']
			ctype['severity']=StringVar()
			ctype['severity'].set(str(sev))
			
			Label(sevframe, text='Severity <=').pack(side=LEFT)
			Entry(sevframe,width=4,textvariable=ctype['severity']).pack(side=LEFT)
			
			for piece in self.piecelist:
				if piece in ctype:
					self.makerow(i,piece,ctype[piece])
				else:
					self.makerow(i,piece,[])
			i+=1
	def writebos(self):
		print 'Writing BOS file'
		wholebos=''.join(self.bos)
		nokilledbos=''
		if 'Killed(severity' in wholebos:
			nokilledbos=wholebos.partition('Killed(severity')[0]
		else:
			print 'WARNING! Killed(severity not in bos file!', wholebos
			return 
		nokilledbos+='Killed(severity, corpsetype)\n{\n'
		i=0
		for sevlevel in self.killscript:
			if int(sevlevel['severity'].get())>-1:
				nokilledbos+='	if( severity <= %i )\n	{\n		corpsetype = %i ;\n'%(int(sevlevel['severity'].get()),min(i+1,3))
				nokilledbos+=self.writebospieces(sevlevel)+'		return(0);\n	}\n'
			else:
				
				nokilledbos+='	corpsetype = 3 ;\n'
				nokilledbos+=self.writebospieces(sevlevel)
			i+=1
		nokilledbos+='}\n'
		#print nokilledbos
		outf=open(self.outputdir+'/'+self.unitname+'.bos','w')
		outf.write(nokilledbos)
		outf.close()
		
	
	def writebospieces(self,sevlevel):
		s=''
		for piece in self.piecelist:
			flags=[]
			for flag in sevlevel[piece].iterkeys():
				if flag in self.validflags and sevlevel[piece][flag].get()==1:
					flags.append(flag)
			if sevlevel[piece]['explode'].get()==1:
				s+='		explode '+piece+' type '+' | '.join(flags)+';\n'
		return s
		
	def makerow(self, sevlevel, piece, flags):
		#print sevlevel
		rowframe=Frame(self.uiframes[sevlevel],width=700)
		rowframe.pack(side=TOP,fill=X)
		explode=IntVar()
		if flags!=[]:
			explode.set(1)
		self.killscript[sevlevel][piece]={}
		self.killscript[sevlevel][piece]['explode']=explode
		Checkbutton(rowframe, variable=explode).pack(side=LEFT)
		Label(rowframe,text=piece.ljust(12),font=self.treefont).pack(side=LEFT)
		
		
		for flag in self.validflags:
			val=IntVar()
			val.set(0)
			if flag in flags:
				val.set(1)
				#print flag,piece,'should be set'
			self.killscript[sevlevel][piece][flag]=val
			Checkbutton(rowframe,text=flag, variable=val).pack(side=LEFT)
		
	def loadbos(self, boslines):
		bospiecelist=[]
		killtable=[{},{},{},{}]
		l=0
		killedindex=0
		for line in boslines:

			#strip comments:
			line=uncomment(line)
			if line[0:5]=='piece' and bospiecelist==[]:
	
				if ';' not in line:
					line+=uncomment(boslines[l+1])+uncomment(boslines[l+2])+uncomment(boslines[l+3]) #wow this is ugly, i cant write parsers for shit.
					line=line.partition(';')[0]+';'
				print line
				bospiecelist=[p.strip() for p in (line.partition('piece')[2].partition(';')[0]).split(',')]
				print 'bospiecelist',bospiecelist
			if 'Killed' in line:
				killedindex= -1
				for i in range(l+1,len(boslines)):
					line=uncomment(boslines[i])
					if 'corpsetype' in line and 'return' not in line: #lets hope to got that corpsetype always precedes explodes
						print line
						killedindex+=1	
					if 'explode' in line:
						p=delimit(line,'explode','type')
						flags=[x.strip() for x in delimit(line,'type',';').split('|')]
						print p,killedindex, flags
						# if 'EXPLODE_ON_HIT' in flags and 'EXPLODE' not in flags:
							# del flags[flags.index('EXPLODE_ON_HIT')]
							# flags.append('EXPLODE')
						for flag in flags:
							if flag not in self.validflags:
								del flags[flags.index(flag)]
								
						killtable[killedindex][p.lower()]=flags
						
				break

			l+=1	
		if len(bospiecelist)!=len(self.piecelist):
			print 'WARNING: the bos piece list does not match the s3o piece list!', bospiecelist, self.piecelist
			
		return killtable

	def saveunit(self): #wtf should this even do?
		return
	def nextunit(self):
		oldunitname=self.unitname
		unitlist=sorted(os.listdir(self.modpath+'units'))
		newunitname=''
		for unit_index in range(len(unitlist)):
			unitname=unitlist[unit_index].partition('.')[0]
			#print 'oldunitname', oldunitname, 'unitname',unitname
			if unitname==oldunitname:
				newunitname=unitlist[unit_index+1]
		self.loadunit(self.modpath+'units/'+newunitname)
		return
	def prevunit(self):
		oldunitname=self.unitname
		unitlist=sorted(os.listdir(self.modpath+'units'))
		newunitname=''
		for unit_index in range(len(unitlist)):
			unitname=unitlist[unit_index].partition('.')[0]
			print 'oldunitname', oldunitname, 'unitname',unitname
			if unitname==oldunitname:
				newunitname=unitlist[unit_index-1]
		self.loadunit(self.modpath+'units/'+newunitname)
		return
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
				S3OtoOBJ(file,outputfilename)
	####################################################
	# RULES:
	# Wreck:
		# only 1 piece may fly off, and that piece is the leaf-est non-empty piece. and only if it has 2 or more pieces.
		# everything else is bitmaponly
	#heap:
		#the base is the only thing that does not fall off, 50% (the smallest 50%) of the pieces fall, with random smoke and fire.
	#destroyed:
		# all but the base falls off, with random smoke and fire, 50% of the pieces explode on hit
	#selfd:
		#everything falls off, with random smoke and fire, everything explodes on hit		
		#stuff with 60 indices or less may shatter 
	#######################################
	
	def autoconf(self):
		global PieceInfo #'name pname vol verts children emptychildren d'
		self.keeplist=[]
		
		leafest=self.getleafname()
		
		#sevlevel WRECK
		for piece in self.piecetree: #'name pname vol indices children emptychildren depth'
			if piece.name==leafest:
				self.clearpiece(0,piece.name)
				self.setflags(0,piece.name,['FALL','SMOKE','FIRE'])
			else:
				self.clearpiece(0,piece.name)
				self.setflags(0,piece.name,['BITMAPONLY'])
				self.keeplist.append(piece.name)
		#sevlevel HEAP
		for piece in self.piecetree:# 'name pname vol indices children emptychildren depth'
			if piece.pname=='root' and piece.vol >8*8*8:
				self.clearpiece(1,piece.name)
				self.setflags(1,piece.name,['BITMAPONLY'])
			else:
				self.clearpiece(1,piece.name)
				if piece.vol<32*32*32:
					if len(self.piecetree)>3:
						r=random.random()
						if r>0.33:
							self.setflags(1,piece.name,['FALL','SMOKE','FIRE'])
						elif r>0.66:
							self.setflags(1,piece.name,['FALL','SMOKE'])
						else:
							self.setflags(1,piece.name,['FALL'])
					else:
						self.setflags(1,piece.name,['FALL','SMOKE','FIRE'])
				else:
					self.setflags(0,piece.name,['BITMAPONLY'])

		#sevlevel DESTROY
		for piece in self.piecetree:# 'name pname vol indices children emptychildren depth'
			r=random.random()
			self.clearpiece(2,piece.name)
			if piece.verts!=0 and piece.verts<60:
				
				if piece.vol<32*32*32:
					self.setflags(2,piece.name,['SHATTER'])
				else:
					self.setflags(2,piece.name,['BITMAPONLY'])
			elif piece.pname=='root':
				if piece.vol<32*32*32:
					self.setflags(2,piece.name,['FALL','SMOKE','FIRE'])
				else:
					self.setflags(2,piece.name,['BITMAPONLY'])
			else:
				if piece.vol<32*32*32:
					if r<0.25:
						self.setflags(2,piece.name,['FALL','SMOKE'])
					elif r<0.5:
						self.setflags(2,piece.name,['FALL','SMOKE','FIRE','EXPLODE_ON_HIT'])
					elif r<0.75:
						self.setflags(2,piece.name,['FALL','FIRE','SMOKE'])
					else:
						self.setflags(2,piece.name,['FALL','SMOKE','EXPLODE_ON_HIT'])
				else:
					self.setflags(2,piece.name,['BITMAPONLY'])
		#sevlevel SELFD
		for piece in self.piecetree: # 'name pname vol indices children emptychildren depth'
			r=random.random()
			self.clearpiece(3,piece.name)
			if piece.verts!=0 and piece.verts<60:
				
				if piece.vol<32*32*32:
					self.setflags(3,piece.name,['SHATTER'])
				else:
					self.setflags(3,piece.name,['BITMAPONLY'])
			elif piece.pname=='root':
				if piece.vol<32*32*32:
					self.setflags(3,piece.name,['FALL','SMOKE','FIRE','EXPLODE_ON_HIT'])
				else:
					self.setflags(3,piece.name,['BITMAPONLY'])
			else:	
				if r<0.5:
					self.setflags(3,piece.name,['FALL','SMOKE','FIRE','EXPLODE_ON_HIT'])
				else:
					self.setflags(3,piece.name,['FALL','FIRE','EXPLODE_ON_HIT'])

		

	def getleafname(self):
		leafest=''
		maxdepth=0
		if len(self.piecetree)<=2:
			return ''
		for piece in self.piecetree:
			if piece.d>maxdepth and piece.emptychildren==piece.children and piece.verts!=0:
				leafest=piece.name.lower()
				maxdepth=piece.d
		return leafest
	def clearpiece(self,sevlevel,piece):	
		self.killscript[sevlevel][piece]['explode'].set(0)
		for flag in self.validflags:
			self.killscript[sevlevel][piece][flag].set(0)
	def setflags(self,sevlevel,piece,flags):
		self.killscript[sevlevel][piece]['explode'].set(1)
		for flag in flags:
			self.killscript[sevlevel][piece][flag].set(1)
	
	def wreckunit(self):
		self.destroy(0,0.05+random.random()/10,0.5,random.random()*100)
		self.writebos()
		self.wreckeds3o.texture_paths=(self.tex1.get(),self.tex2.get())
		optimized_data = self.wreckeds3o.serialize()
		output_file=open(self.outputdir+'/'+self.unitname+'_dead.s3o','wb')
		output_file.write(optimized_data)
		output_file.close()
		for i in range(len(self.unitdef)):
			if 'object' in self.unitdef[i] and self.unitname.lower()+'_dead' in self.unitdef[i].lower():
				if '.s3o' not in self.unitdef[i].lower():
					self.unitdef[i]= self.unitdef[i].lower().replace('_dead', '_dead.s3o')
			elif 'object' in self.unitdef[i] and 'x' in self.unitdef[i].lower():
				
				line=self.unitdef[i].lower()
				parts=line.split('\"')
				heapname=parts[1]
				print 'heapname',heapname
				xindex=heapname.index('x')
				try:
					int(heapname[xindex-1])
					int(heapname[xindex+1])
					if 'cor' in heapname: 
						if 'Arm' in self.s3o.texture_paths[0]:
							heapname=heapname.replace('cor','arm')
					else:
						if 'Arm' in self.s3o.texture_paths[0]:
							heapname='arm'+heapname+'.s3o'
						else:
							heapname='cor'+heapname+'.s3o'
							
					print 'newheapname',heapname
					self.unitdef[i]= '\"'.join([parts[0],heapname,parts[2]])
				except:
					print 'this is not a heap!'
					pass
					

		luaf=open(self.outputdir+'/'+self.unitname+'.lua','w')
		luaf.write(''.join(self.unitdef))
		luaf.close() 
		print 'Successfully written, validating S30'
		valid=S3O(open(self.outputdir+'/'+self.unitname+'_dead.s3o','rb').read())
		#valid.S3OtoOBJ(self.outputdir+'/'+self.unitname+'_dead.obj')
		print 'validation OK!'
		return
	def wreckunits3o(self):
		self.destroy(0,0.05+random.random()/10,0.5,random.random()*100)
		self.wreckeds3o.texture_paths=(self.tex1.get(),self.tex2.get())
		optimized_data = self.wreckeds3o.serialize()
		output_file=open(self.modpath+'objects3d/Units/'+self.unitname+'_dead.s3o','wb')
		output_file.write(optimized_data)
		output_file.close()
		print 'Successfully written, validating S30'
		valid=S3O(open(self.modpath+'objects3d/Units/'+self.unitname+'_dead.s3o','rb').read())
		#valid.S3OtoOBJ(self.outputdir+'/'+self.unitname+'_dead.obj')
		print 'validation OK!'
		return
	def destroy(self, twist, shear, deform,shearang): #destroy(0,0.05+random.random()/10,0.5,random.random()*100)
		#global base
		self.wreckeds3o=copy.deepcopy(self.s3o)
		self.wreckeds3o.root_piece.vertices=[]
		self.wreckeds3o.root_piece.indices=[]
		self.wreckeds3o.root_piece.children=[]
		self.wreckeds3o.root_piece.primitive_type='triangles'
		self.grab(copy.deepcopy(self.s3o.root_piece),self.wreckeds3o.root_piece,twist, shear, deform,(0,0,0),shearang)

		# self.rootPiece=0
	def grab(self, piece, base, twist, shear, deform,offsets,shearang):
		print 'grabbing', piece.name,'#verts',len(piece.vertices),'#index',len(piece.indices)
		if piece.primitive_type!='triangles' and len(piece.vertices)!=0:
			print 'Piece cant be grabbed, as its not empty and has non triangles!',piece.primitive_type,len(piece.vertices)
		else:		
			if len(self.keeplist)>0 and piece.name.lower() in self.keeplist:
				vert_cnt=len(base.vertices)
				for vi in piece.indices:
					base.indices.append(vert_cnt+vi)
					if vert_cnt+vi>len(base.vertices)+len(piece.vertices)	:
						print 'index error in grab','#baseindex',len(base.indices),'vi',vi,'vcnt',vert_cnt,'#basevertex',len(base.vertices),'#pvertex',len(piece.vertices)
					# base.numvertices+=piece.numvertices	
				# base.vertexTableSize+=piece.vertexTableSize
				offsets=(offsets[0]+piece.parent_offset[0],offsets[1]+piece.parent_offset[1],offsets[2]+piece.parent_offset[2])
				for vt in piece.vertices:
					v=[[vt[0][0],vt[0][1],vt[0][2]],[vt[1][0],vt[1][1],vt[1][2]],[vt[2][0],vt[2][1]]]
					v[0][0]+=offsets[0]
					v[0][1]+=offsets[1]
					v[0][2]+=offsets[2]
					v[0][0]+=deform*(math.sin(v[0][0])+math.cos(v[0][2])+math.sin(v[0][1]+2.3))
					v[0][1]+=min( 1 ,max(0,v[0][1]/10))*deform*(math.sin(v[0][0]+4)+math.cos(v[0][2]+7)+math.sin(v[0][1]+1))
					v[0][2]+=deform*(math.sin(v[0][0]+2)+math.cos(v[0][2]+3)+math.sin(v[0][1]-11))
					v[0][0]+=shear*(v[0][0])*math.sin(shearang)
					v[0][1]+=shear*(v[0][1])*math.cos(shearang)
					#print v.uv.u,v.uv.v,'|',
					base.vertices.append(copy.deepcopy(v))
					#print vt, v
		for c in piece.children:
			print len(base.vertices)
			self.grab(c,base,twist, shear, deform,offsets,shearang)
	def recursepiecetree(self, piece, depth,offset,pl,parentname): # we need the name offset by depth, the volume, the #triangles and the pos
		global PieceInfo
		namejust=20
		piecevol=piecevolume(piece)
		indices=len(piece.indices)
		s='%s %10.1f %5i %4.2f %4.2f %4.2f\n'%((' '*depth+piece.name.lower()).ljust(17),piecevol, indices, piece.parent_offset[0]+offset[0], piece.parent_offset[1]+offset[1], piece.parent_offset[2]+offset[2])
		emptyChildren=0
		for child in piece.children:
			if len(child.indices)==0:
				emptyChildren+=1
		self.piecetree.append(PieceInfo(name=piece.name.lower(), pname=parentname, vol=piecevol, verts=indices, children=len(piece.children), emptychildren=emptyChildren,d=depth))
		print s
		pl.append(piece.name.lower())
		for child in piece.children:
			s+=self.recursepiecetree(child, depth+1, (piece.parent_offset[0]+offset[0], piece.parent_offset[1]+offset[1], piece.parent_offset[2]+offset[2]),pl,piece.name.lower())
		return s
		
def delimit(s,l,r):
	return s.partition(l)[2].partition(r)[0].strip()
def uncomment(l):
	return l.partition('//')[0].strip()

def piecevolume(piece):
	if len(piece.vertices)>0:
		xs=[x[0][0] for x in piece.vertices]
		ys=[x[0][1] for x in piece.vertices]
		zs=[x[0][2] for x in piece.vertices]
		#print xs
		return (max(xs)-min(xs))* (max(ys)-min(ys))* (max(zs)-min(zs))
	else:
		return 0

root = Tk()
app = App(root)
root.mainloop()
validflags=['SHATTER','EXPLODE_ON_HIT','FALL','SMOKE','FIRE','BITMAPONLY','NO_CEG_TRAIL','NO_HEATCLOUD']
#				1			2			4		8		16		32				64			128

#flagrules:
# EXPLODE(engine)=EXPLODE_ON_HIT(BOS)  
# EXPLODE causes it to do 50 damage on impact!
#all pieces bounce with p=0.66
#void CUnitScript::Explode(int piece, int flags)
#flag processing order
#1. noheatcloud = obvious no heatcloud at site of explosion, heatcloudtex is bitmaps/explo.tga
#2. NONE: no stuff falls off, return NONE(engine) = BITMAPONLY(BOS)
#3. SHATTER: shatters, return
#4. !! at this point, FALL IS TURNED ON!
#5. SMOKE is smoke, checked for particle saturation, uses projectileDrawer->smoketrailtex
#6. fire is fire, checked for particle saturation
#7. nocegtrail is passed, does not seem to be mutually exclusive with fire or smoke...
	#if a unit has no custom ceg trails defined, such as: unitDef->pieceCEGTags is empty, then NO_CEG_TRAIL is flagged on, which means NO_CEG_TRAIL will always be on!
#UPDATE:
#if FIRE and hasvertices: rotate it and translate it (obvious since there is no need to rotate if it has no vertices)
	#FIRE does nothing on empty pieces
# if nocegtrail and age%8!=0 and SMOKE: make a new smoke instance (gotta test this out)

##DRAW:
# if NOCEGTRAIL and SMOKE: default smoke drawn
# if FIRE: draw projectileDrawer->explofadetex

#EXTENSIONS:
# if we dont want to explode all stuff at once, we can add a delay to it, even explode some pieces multiple times...
# pieces that get exploded and fall off MUST be hidden in the same frame as they are exploded, or else it looks funny
# bugs: units that dont finish their killscripts are put on a 'pause'
# they seem to be paralyzed, and somehow health bars are messing up
# units that are waiting on killscript stop dead in their tracks, and they wreck continues sliding after they finish the script
# units seem to return a corpsetype of 1 no matter what, if there are sleeps in the killscript...
# attacking units seem to retain their targets of dying units while the killscript executes, they do not fire, just target them like neutral units (and move to acquire target)

#classes we will use:
# BITMAPONLY - this class is for EVERYTHING that doesnt fall or otherwise do stuff
# EXPLODE_ON_HIT
# FALL
# FALL|SMOKE
# FALL|FIRE|SMOKE
# FALL|EXPLODE_ON_HIT|SMOKE|
# FALL|EXPLODE_ON_HIT|FIRE|SMOKE
# 

#SEVERITY:
#selfd severity is at least 200.


#wierd glowy bug:
# changes on zoom level!
# caused by: 	explode lfire type FALL | SMOKE | FIRE | BITMAP3;
#not caused by FALL|SMOKE;
#caused by FIRE;
#CAUSED BY 0 tags!;
#IT IS CAUSED BY EMPTY (0 geometry) PIECES BEING EXPLODED!
#solution? NO FIRE ON EMPTY!

#SCRIPTOR WILL NOT EAT AN explode piece type ; with NO FLAGS
'''
	LuaPushNamedNumber(L, "SHATTER", PF_Shatter);
	LuaPushNamedNumber(L, "EXPLODE", PF_Explode);
	LuaPushNamedNumber(L, "EXPLODE_ON_HIT", PF_Explode);
	LuaPushNamedNumber(L, "FALL",  PF_Fall);
	LuaPushNamedNumber(L, "SMOKE", PF_Smoke);
	LuaPushNamedNumber(L, "FIRE",  PF_Fire);
	LuaPushNamedNumber(L, "NONE",  PF_NONE); // BITMAP_ONLY
	LuaPushNamedNumber(L, "NO_CEG_TRAIL", PF_NoCEGTrail);
	LuaPushNamedNumber(L, "NO_HEATCLOUD", PF_NoHeatCloud);
	'''