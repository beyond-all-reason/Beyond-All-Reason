import sys
import os
import fbi_tags

def listall(dir):
	fbionly = []
	alltags = {}
	for x in os.listdir(dir):
		if not os.path.isdir(x) and os.path.splitext(x)[1] == ".fbi":
			fbionly.append(x)
	for x in fbionly:
		file = open(os.path.join(dir, x), "r")
		print "processing: " + str(x)
		par = fbi_tags.fbi_tags(None, file)
		file.close()
		for y in par.tags:
			alltags[y.name.lower()] = None
	print "Total tag number: " + str(len(alltags))
	print "||||||"
	xkeys = alltags.keys()
	xkeys.sort()
	for x in xkeys:
		print x

listall("../../units")
