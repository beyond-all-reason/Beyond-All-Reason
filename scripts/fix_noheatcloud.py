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
	

for root, dir, files in os.walk(os.getcwd()):
	for filename in files:
		if filename.lower().endswith('.bos'):
			fpath = os.path.join(root, filename)
			boslines=open(fpath).readlines()
			fixed = 0
			for i, line in enumerate( boslines):
				if '//' in line:
					line = line.partition('//')[0] + '\n'
				# 	explode body type FIRE | SMOKE | FALL | NOHEATCLOUD;
				if 'explode' in line and ' type ' in line and 'NOHEATCLOUD' not in line:
					lp = line.partition(';')
					
					boslines[i] = ''.join([lp[0], ' | NOHEATCLOUD ', lp[1],lp[2]])
					print (filename,i,line,boslines[i])
					
					fixed = fixed + 1
			if fixed > 0:
				
				bosfile=open(fpath,'w')
				bosfile.write(''.join(boslines))
				bosfile.close()
				# print ''.join(newbosfle)