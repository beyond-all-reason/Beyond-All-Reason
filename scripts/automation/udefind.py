import string
import re

def udefind(file):
	unitdefcpp = file.read()
	atea = open("all_tags_ever_appearing.txt", "r")
	tags = atea.readlines()
	#Remove newlines
	for cnt in xrange(len(tags)):
		tags[cnt] = tags[cnt][:-1]
	def findone(tag, data):
		#found = string.find(data, tag)
		#if found == -1:
		#	return False
		#else:
		#	return True
		pattern = re.compile(tag, re.IGNORECASE)
		match = re.search(pattern, data)
		if match == None:
			return False
		return True
	
	for tag in tags:
		if findone(tag, unitdefcpp):
			print "FOUND " + str(tag)
		else:
			print "NOTFOUND " + str(tag)

file = open("F:\\Downloads\\spring\\rts\\Sim\\Units\\UnitDef.cpp", "r")
udefind(file)
