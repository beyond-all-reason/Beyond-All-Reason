import re

class ctx:
	lines = None
	cur = None
	def __init__(self, oldc, cur):
		self.lines = oldc.lines
		self.cur = cur
class initial_ctx:
	lines = None
	cur = None
	def __init__(self, lines, cur):
		self.lines = lines
		self.cur = cur

def fbi_tags(name, fbi_file):
	unitinfo_re = re.compile(r"\[UNITINFO\]", re.IGNORECASE)
	
	file = fbi_file
	lines = file.readlines()
	match = re.search(unitinfo_re, lines[0])
	if match == None:
		raise RuntimeError("FBI file does not begin with [UNITINFO]?")
	
	ic = initial_ctx(lines, 0)
	c = ctx(ic, 0)
	par = extract_tags(c)
	#par.prt()
	#print "tags: " + str(len(par.tags))
	#print "table_tags: " + str(len(par.table_tags))
	return par

def extract_tags(c):
	tableheader_re = re.compile(r"\[(.*)\]", re.IGNORECASE)
	empty_re = re.compile(r"^\s*$", re.IGNORECASE)
	opening_re = re.compile(r"{", re.IGNORECASE)
	closing_re = re.compile(r"}", re.IGNORECASE)
	tag_re = re.compile(r"(\w.*)=(.*);", re.IGNORECASE)
	comment_re = re.compile(r"// *(.*)", re.IGNORECASE)

	class empty_tag:
		pass

	class opening_tag:
		value = "{"

	class closing_tag:
		value = "}"

	class comment_tag:
		value = None
		def __init__(self, value):
			self.value = value
	
	class normal_tag:
		name = None
		value = None
		def __init__(self, name, value):
			self.name = name
			self.value = value
		def prt(self):
			return "<NT," + str(self.name) + ", " + str(self.value) + ">"

	class table_tag:
		name = None
		tags = None
		table_tags = None
		def __init__(self):
			self.tags = []
			self.table_tags = []
		def prt(self):
			ss = ""
			for tag in self.tags:
				ss += tag.prt()
				ss += "\n"
			ss += "------" + "\n"
			for table_tag in self.table_tags:
				ss += table_tag.name
				ss += "\n"
				for tag in table_tag.tags:
					ss += tag.prt()
					ss += "\n"
			print ss
	
	def parse_empty(c):
		lc = c.cur
		match = re.search(empty_re, c.lines[lc])
		if match == None:
			return None
		lc += 1
		c.cur = lc
		return empty_tag()
	
	def parse_comment(c):
		lc = c.cur
		match = re.search(comment_re, c.lines[lc])
		if match == None:
			return None
		lc += 1
		c.cur = lc
		return comment_tag(match.groups()[0])
	
	def parse_closing(c):
		lc = c.cur
		match = re.search(closing_re, c.lines[lc])
		if match == None:
			return None
		lc += 1
		c.cur = lc
		return closing_tag()
	
	def parse_tag(c):
		lc = c.cur
		match = re.search(tag_re, c.lines[lc])
		if match == None:
			return None
		lc += 1
		c.cur = lc
		tok = normal_tag(match.groups()[0], match.groups()[1])
		return tok
	
	def parse_table(c):
		lc = c.cur
		tok = table_tag()
		#No header? Not a table then
		match = re.search(tableheader_re, c.lines[lc])
		if match == None:
			return None
		#Have header, name is group0
		tok.name = match.groups()[0]
		lc += 1
		#Allow an opening { on next line
		match = re.search(opening_re, c.lines[lc])
		if not match == None:
			lc += 1
		#Tags should follow, until a closing }
		#No nested tables expected or supported
		#Actually they are since I realized I accidentally wrote a relatively decent parser for once >.>
		while True:
			ctx_empty = ctx(c, lc)
			par = parse_empty(ctx_empty)
			if not par == None:
				#Empty
				lc = ctx_empty.cur
				continue
			ctx_comment = ctx(c, lc)
			par = parse_comment(ctx_comment)
			if not par == None:
				#Commant
				lc = ctx_comment.cur
				continue
			ctx_tag = ctx(c, lc)
			par = parse_tag(ctx_tag)
			if not par == None:
				#Tag
				lc = ctx_tag.cur
				tok.tags.append(par)
				continue
			ctx_rectbl = ctx(c, lc)
			par_rt = parse_table(ctx_rectbl)
			if not par_rt == None:
				#Rec tbl
				lc = ctx_rectbl.cur
				tok.table_tags.append(par_rt)
				continue
			ctx_closing = ctx(c, lc)
			par_c = parse_closing(ctx_closing)
			if not par_c == None:
				#Closing
				lc = ctx_closing.cur
				tok.tags = tok.tags
				tok.table_tags = tok.table_tags
				c.cur = lc
				return tok
			print c.lines[lc]
			raise RuntimeError("parse_table: Should not get here.")
		
	par = parse_table(c)
	return par
