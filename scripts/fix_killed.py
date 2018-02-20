#copy into scripts and run
#fear my spaghetti code
import os

def processblock(inbos, k):
	startk=k
	outbos=[]
	mycorpsetype=None
	fixed=False
	
	while (k<len(inbos)):
		if '{' in inbos[k]:
			outbos.append(inbos[k])
			newbos, newk = processblock(inbos,k+1)
			k=newk
			outbos+=newbos
		elif 'corpsetype' in inbos[k]:
			try:
				mycorpsetype= int(inbos[k].partition('=')[2].partition(';')[0])
			except ValueError:
				raise AssertionError('This file already seems to be fixed')
			outbos.append(inbos[k])
		elif 'return' in inbos[k]:
			outbos.append(inbos[k].partition('(')[0]+'(corpsetype)'+inbos[k].partition(')')[2])
			fixed=True
		elif '}' in inbos[k]:
			if not fixed:
				if mycorpsetype == None:
					print 'This is impossible to fix!',inbos[k], inbos[startk:k+1]
					raise AssertionError('This is impossible to fix')
				else:
					outbos.append('	return corpsetype;\n}\n')
			else:
				outbos.append(inbos[k])
				return outbos, k
		else:
			outbos.append(inbos[k])
		# print 'pb',inbos[k]
		k+=1
	# print 'weve reached the end of the line here!'
	return outbos,k
	

for file in os.listdir(os.getcwd()):
	# print file
	if '.bos' in file:
		bosfile=open(file)
		boslines=bosfile.readlines()
		bosfile.close()
		newbosfile=[]
		inkilled=False
		
		#do some sanity checks:
		killcnt=0
		for line in boslines:
			if 'killed' in line.partition('//')[0].lower():
				killcnt+=1
		if killcnt!=1:
			print file,'does not have exactly one Killed function, skipping. It has',killcnt
			continue
		lastcorpsetype=None
		i=0
		try:
			while i <len(boslines):
				line=boslines[i]
				if not inkilled:
					newbosfile.append(boslines[i])
					if 'killed' in boslines[i].partition('//')[0].lower():
					 inkilled=True
				else:
					if '{' in line:
						newbosfile.append(line)
						newstuff, newk = processblock(boslines,i+1)
						newbosfile+=newstuff
						i=newk
						inkilled=False
				i+=1
		except AssertionError:
			print 'Cant fix',file
			continue
				
		print file, 'successful, len(oldfile=)',len(boslines), 'newfile=',len(newbosfile)
		if len(boslines)>len(newbosfile):
			print 'WHOOP WHOOP something went really wrong, aborting'
			break
		bosfile=open(file,'w')
		bosfile.write(''.join(newbosfile))
		bosfile.close()
		# print ''.join(newbosfle)