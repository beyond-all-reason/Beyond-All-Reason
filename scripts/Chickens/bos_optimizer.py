import argparse

import re
import os
import bos2cob

LINEAR_CONSTANT = 65536.000000
ANGULAR_CONSTANT = 182.00000

parser = argparse.ArgumentParser()
parser.add_argument("-b", "--bosfile", type = str, help= "The bos file to optimize")#, default = "../units/armcrus.bos")
parser.add_argument("-d", "--directory", type = str, help= "the directory of bos files to work on") #, default = '../units/')

args = parser.parse_args()

def decomment_lines(inlines):
	outlines = []
	incomment = False
	for line in inlines:
		line = line.rstrip().partition('//')[0]
		if '/*' in line and '*/' in line:
			line = line.partition("/*")[0] + line.partition("*/")[2]
			outlines.append(line)
		elif '/*' in line:
			line = line.partition("/*")[0]
			incomment = True
			outlines.append((line))
		elif '*/' in line:
			line = line.partition('*/')[2]
			incomment = False
			outlines.append(line)
		elif not incomment:
			outlines.append(line)

	return outlines

def assemble_bos(bosfile): # recursive?
	output = []
	boslines = open(bosfile).readlines()
	boslines = decomment_lines(boslines)
	for line in boslines:
		if line.lower().startswith ('#include '):
			includefile = line.split('"')[1]
			output += assemble_bos(includefile)
		else:
			output.append(line)
	return output

def get_defined_tokens(boslines):
	tokens = {}
	for line in boslines:
		if line.lower().startswith("#define"):
			line = line.strip().split()
			try:
				k = line[1]
				v = line[2]

				if k in tokens:
					if tokens[k] != v:
						print ("Key already in tokens with different value:", k, v, tokens[k])
				else:
					tokens[k] = v
			except ValueError:
				print ("Cannot parse value for token key", line, k,v)
			except IndexError:
				print ("Cannot find value!", line)

	return tokens

### REGEXES
def token_replacer(expression, tokens):
	cwords = CWORDS.findall(expression)
	for cword in cwords:
		if cword in tokens:
			expression = expression.replace(cword,tokens[cword])
	return expression

def linang_replacer(expression):
	for RE in [LINEAR, ANGULAR]:
		for lin in RE.findall(expression):
			newval = "%.6f"%(tofloat(lin))
			expression = expression.replace(lin, newval)
	return expression

def tofloat(const_match):
	try:
		if '[' in const_match:
			return float(const_match.strip('[]')) * LINEAR_CONSTANT
		if '<' in const_match:
			return float(const_match.strip('<>')) * ANGULAR_CONSTANT
	except:
		print ("Failed to parse linear constant",const_match)
		return 0.0

def performmath(expression):
	origexpression = expression

	resultstr = ''
	result = ''
	if expression.endswith(';'):
		resultstr += ';'
		expression = expression[0:-1]
	try:
		expression = expression.strip()
		if expression[-1] in '+-*/':
			resultstr += expression[-1]
			expression = expression[0:-1]
		openbrackets = expression.count('(')
		closebrackets = expression.count(')')
		delta = openbrackets - closebrackets
		if delta>0 and expression.startswith('('*(delta)):
			result = '('*delta + str(int(float(eval(expression[delta:]))))
		elif delta<0 and expression.endswith(')'*(delta)):
			result = str(int(float(eval(expression[0:delta])))) + ')'*delta
		else:
			result = str(int(float(eval(expression))))
		#print ("Success! ",expression, '=', result)
	except:
		print ("[info] Failed to eval() expression", expression)
		#raise
		return origexpression
	return ' '+ result +' '+ resultstr+ ' '

test_num = re.compile(r"<-?\d*\.?\d*>")
print (test_num.findall("<0.1>, <.1>, <-90>, <6.> 90 <7  > 90.0"))

ANGULAR = re.compile(r"<-?\d*\.?\d*>")
LINEAR = re.compile(r"\[-?\d*\.?\d*\]")
TURN = re.compile(r"turn +[A-z_-]+ +to +[xyzXZY]-axis +(.*) +speed +(.*).*;")
MOVE = re.compile(r"move +[A-z_-]+ +to +[xyzXZY]-axis +(.*) +speed +(.*).*;")
CWORDS = re.compile(r"[A-z_]+")

valid_mathexpression = re.compile(r" [0-9\.\-\+\*/\)\( ]+[\-\+\*\/][0-9\.\-\+\*/\)\( ]+[ \;]")


def optimize_bos(bosfile):
	reload(bos2cob)
	parsedlines = assemble_bos(bosfile)
	tokens = get_defined_tokens(parsedlines)

	optimizedbos = []
	for line in parsedlines:
		for RE in [TURN, MOVE]:
			if RE.search(line):
				turns =  RE.findall(line)
				for turn in turns[0]:
					line = line.replace(turn, linang_replacer(token_replacer(turn, tokens)))

		line = linang_replacer(line)

		if valid_mathexpression.search(line):
			for expr in valid_mathexpression.findall(line):
				line = line.replace(expr, performmath(expr))
		optimizedbos.append(line)
	optimizedname = bosfile.lower().replace(".bos", "_optimized.bos")
	intermediate = open(optimizedname,'w')
	intermediate.write('\n'.join(optimizedbos))
	intermediate.close()

	bos2cob.main(optimizedname, bosfile.lower().replace('.bos','.cob'))

	return optimizedname

if args.bosfile:
	optimize_bos(args.bosfile)
if args.directory:
	os.chdir(args.directory)
	for file in os.listdir(os.getcwd()):
		if (not file.lower().endswith(".bos")) or "_optimized" in file:
			continue
		print (file)
		try:
			optimize_bos(file)
		except:
			print("Failed to optimize", file)
			raise

# TODO:
# maths - compile- replace-compare-benchmark