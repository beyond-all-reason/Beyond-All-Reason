import re

def split():
	file = open("out/udef_infolog.txt", "rb")
	udef = file.readlines()
	cnt = 0
	curfile = None
	while True:
		match = re.search(r"######", udef[cnt][:-1])
		if match != None:
			break
		match = re.search(r"\|\|\|\|\|\| (.*)", udef[cnt][:-1])
		if match != None:
			name = match.groups()[0]
			print name
			curfile = open("out/" + name + ".lua", "w")
			cnt += 1
			continue
		curfile.write(udef[cnt])
		cnt += 1
split()
