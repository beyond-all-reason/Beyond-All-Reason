import re

#list of names or none
def sidedata_buildOptions(name, sidedata_file):
	header_re = re.compile(r"(\[" + name + "\])", re.IGNORECASE)
	canbuild_re = re.compile(r"canbuild\d*=(.*);", re.IGNORECASE)
	
	def canbuild_lines(cnt, lines):
		#scan lines for canbuild until nonmatching then return
		list = []
		while True:
			match = re.search(canbuild_re, lines[cnt])
			if match == None:
				break
			cnt += 1
			list.append(match.groups()[0])
		return list
		
	file = sidedata_file
	lines = file.readlines()
	for cnt in xrange(len(lines)):
		line = lines[cnt]
		match = re.search(header_re, line)
		if match == None:
			continue
		#match.groups()
		next_line = lines[cnt+1]
		match = re.search(r"{", next_line)
		if match == None:
			raise RuntimeError("Line after header is not '{'")
		cb_names = canbuild_lines(cnt+2, lines)
		return cb_names
	return None

def compose_buildOptions(name):
	sidedata_bo = sidedata_buildOptions(name)
	if sidedata_bo == None:
		raise RuntimeError("Failed to parse sidedata for buildoptions")
	
	list = []
	list.append("[\"buildOptions\"] = {")
	for cnt in xrange(len(sidedata_bo)):
		list.append("[" + str(cnt) + "] = [[" + sidedata_bo[cnt] + "]],")
	list.append("},")
	return list

#import sys
#if len(sys.argv) < 2:
#	raise RuntimeError("argv length")
#file = open("../../gamedata/sidedata.tdf", "r")
#compose_buildOptions(sys.argv[1], file)
