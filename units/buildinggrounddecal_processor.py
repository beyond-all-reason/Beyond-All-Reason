import os
import sys

def hasdecaltag(line):
	decaltags = ['buildinggrounddecaldecayspeed', 'buildinggrounddecalsizex','buildinggrounddecalsizey', 'buildinggrounddecaltype', 'usebuildinggrounddecal']
	for decaltag in decaltags:
		if decaltag in line.lower():
			return True
	return False


def movetags(filename):
	fln = open(filename).readlines()
	decallines = []
	for i in range(len(fln)-1, 0, -1):
		if hasdecaltag(fln[i]):
			decallines.append(fln.pop(i))
	if len(decallines) == 5 :
		for i in range(len(fln)):
			if 'customparams = {' in fln[i]:
				for k in range(len(decallines)):
					fln.insert(i+k+1, '\t' + decallines[k])
				flnout = open(filename,'w')
				flnout.write(''.join(fln))
				flnout.close()
				print (''.join(fln))

				break
	elif len(decallines) == 0:
		pass
	else:
		print ("Warning, found not 4 lines", decallines)
		

for root,dirs, files in os.walk(os.getcwd()):
	for file in files:
		if file.endswith('.lua'):
			path = os.path.join(root,file)
			print (path)
			movetags(path)