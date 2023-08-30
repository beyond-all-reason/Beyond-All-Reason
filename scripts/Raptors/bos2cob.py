# written by ashdnazg https://github.com/ashdnazg/bos2cob
# released under the GNU GPL v3 license

import sys
import sys
import os.path
from glob import glob
import struct
import cob_file

LINEAR_SCALE = 65536
ANGULAR_SCALE = 182

OPCODES = {
	'MOVE'        : 0x10001000,
	'TURN'        : 0x10002000,
	'SPIN'        : 0x10003000,
	'STOP_SPIN'   : 0x10004000,
	'SHOW'        : 0x10005000,
	'HIDE'        : 0x10006000,
	'CACHE'       : 0x10007000,
	'DONT_CACHE'  : 0x10008000,
	'MOVE_NOW'    : 0x1000B000,
	'TURN_NOW'    : 0x1000C000,
	'SHADE'       : 0x1000D000,
	'DONT_SHADE'  : 0x1000E000,
	'DONT_SHADOW' : 0x1000E000,
	'EMIT_SFX'    : 0x1000F000,

	'WAIT_FOR_TURN'  : 0x10011000,
	'WAIT_FOR_MOVE'  : 0x10012000,
	'SLEEP'          : 0x10013000,

	'PUSH_CONSTANT'    : 0x10021001,
	'PUSH_LOCAL_VAR'   : 0x10021002,
	'PUSH_STATIC'      : 0x10021004,
	'CREATE_LOCAL_VAR' : 0x10022000,
	'POP_LOCAL_VAR'    : 0x10023002,
	'POP_STATIC'       : 0x10023004,
	'POP_STACK'        : 0x10024000,

	'ADD'         : 0x10031000,
	'SUB'         : 0x10032000,
	'MUL'         : 0x10033000,
	'DIV'         : 0x10034000,
	'MOD'         : 0x10034001,
	'BITWISE_AND' : 0x10035000,
	'BITWISE_OR'  : 0x10036000,
	'BITWISE_XOR' : 0x10037000,
	'BITWISE_NOT' : 0x10038000,

	'RAND'           : 0x10041000,
	'GET_UNIT_VALUE' : 0x10042000,
	'GET'            : 0x10043000,

	'SET_LESS'             : 0x10051000,
	'SET_LESS_OR_EQUAL'    : 0x10052000,
	'SET_GREATER'          : 0x10053000,
	'SET_GREATER_OR_EQUAL' : 0x10054000,
	'SET_EQUAL'            : 0x10055000,
	'SET_NOT_EQUAL'        : 0x10056000,
	'LOGICAL_AND'          : 0x10057000,
	'LOGICAL_OR'           : 0x10058000,
	'LOGICAL_XOR'          : 0x10059000,
	'LOGICAL_NOT'          : 0x1005A000,

	'START_SCRIPT'    : 0x10061000,
	'CALL_SCRIPT'     : 0x10062000,
	'REAL_CALL'       : 0x10062001,
	'LUA_CALL'        : 0x10062002,
	'JUMP'            : 0x10064000,
	'RETURN'          : 0x10065000,
	'JUMP_NOT_EQUAL'  : 0x10066000,
	'SIGNAL'          : 0x10067000,
	'SET_SIGNAL_MASK' : 0x10068000,

	'EXPLODE'    : 0x10071000,
	'PLAY_SOUND' : 0x10072000,

	'SET'         : 0x10082000,
	'ATTACH_UNIT' : 0x10083000,
	'DROP_UNIT'   : 0x10084000,
}
for key in OPCODES:
	OPCODES[key] = struct.pack("<L", OPCODES[key])

def get_num(num):
	return struct.pack("<L", num)

def get_signed_num(num):
	return struct.pack("<l", num)

#case insensitive index
def index(iterable, s):
	l = s.lower()
	for i, v in enumerate(iterable):
		if v.lower() == l:
			return i
	return -1

OPS = {
	'+' : OPCODES['ADD'],
	'-' : OPCODES['SUB'],
	'*' : OPCODES['MUL'],
	'/' : OPCODES['DIV'],
	'&' : OPCODES['BITWISE_AND'],
	'|' : OPCODES['BITWISE_OR'],
	'<' : OPCODES['SET_LESS'],
	'>' : OPCODES['SET_GREATER'],
	'==' : OPCODES['SET_EQUAL'],
	'<=' : OPCODES['SET_LESS_OR_EQUAL'],
	'>=' : OPCODES['SET_GREATER_OR_EQUAL'],
	'!=' : OPCODES['SET_NOT_EQUAL'],
	'&&' : OPCODES['LOGICAL_AND'],
	'||' : OPCODES['LOGICAL_OR'],
	'AND' : OPCODES['LOGICAL_AND'],
	'OR' : OPCODES['LOGICAL_OR'],
}

OPS_PRECEDENCE = {
	'*' : 1,
	'/' : 1,
	'+' : 2,
	'-' : 2,
	'<' : 3,
	'>' : 3,
	'<=' : 3,
	'>=' : 3,
	'==' : 4,
	'!=' : 4,
	'&' : 5,
	'|' : 6,
	'&&' : 7,
	'AND' : 7,
	'||' : 8,
	'OR' : 8,
}

UNARY_OPS = {
	'NOT' : OPCODES['LOGICAL_NOT'],
	'!' : OPCODES['LOGICAL_NOT'],
}

BOS_EXT = 'bos'
COB_EXT = 'cob'

PRINTED_NODES = {'keyword', 'symbol', 'integerConstant', 'floatConstant', 'identifier',
				 'argumentList', 'staticVarDec', 'pieceDec', 'localVarDec',
				 'funcDec', 'funcBody', 'ifStatement', 'whileStatement', 'forStatement',
				 'callStatement',
				 'startStatement',
				 'spinStatement',
				 'stopSpinStatement',
				 'turnStatement',
				 'moveStatement',
				 'waitForTurnStatement',
				 'waitForMoveStatement',
				 'emitSfxStatement',
				 'sleepStatement',
				 'hideStatement',
				 'showStatement',
				 'explodeStatement',
				 'signalStatement',
				 'setSignalMaskStatement',
				 'setStatement',
				 'getStatement',
				 'attachUnitStatement',
				 'dropUnitStatement',
				 'returnStatement',
				 'expression', 'term',
				 'expressionList'}

def escape(s):
	return s.replace('&','&amp;').replace('>','&gt;').replace('<','&lt;').replace('\"','&quot;')

class Node(object):
	def __init__(self, node_type, text = None):
		self._type = node_type
		self._text = text
		self._children = []

	def add_child(self, child):
		self._children.append(child)

	def clear(self):
		self._children = []

	def print_node(self, indent = 0, out_file = sys.stdout):
		if self._type in PRINTED_NODES:
			indentation = '  ' * indent
			if self._text is not None:
				out_file.write("%s<%s> %s </%s>\n" %(indentation, self._type, escape(self._text), self._type))
			else:
				out_file.write("%s<%s>\n" % (indentation, self._type))
				for child in self._children:
					child.print_node(indent + 1, out_file=out_file)
				out_file.write("%s</%s>\n" % (indentation, self._type))
		else:
			for child in self._children:
				child.print_node(indent, out_file=out_file)

	def __getitem__(self, i):
		return self._children[i]

	def __len__(self):
		return len(self._children)

	def get_children(self):
		return self._children

	def get_type(self):
		return self._type

	def get_text(self):
		if self._text is None:
			return "".join(c.get_text() for c in self._children)
		return self._text

def parse_string(pump, node):
	token = pump.next()
	if len(token) == 0:
		return False
	if token.startswith("\""):
		node.add_child(Node('stringConstant', token.strip('\"')))
		return True
	return False

def parse_int(pump, node):
	token = pump.next()
	if len(token) == 0:
		return False
	if token.startswith("0x"):
		try:
			token = str(int(token, 16))
			node.add_child(Node('integerConstant', token))
			return True
		except:
			return False

	if token.isdigit():
		node.add_child(Node('integerConstant', token))
		return True
	return False

def parse_identifier(pump, node):
	token = pump.next()
	if len(token) == 0:
		return False
	if token[0].isalpha() or token[0] == '_':
		node.add_child(Node('identifier', token))
		return True
	return False

def parse_float(pump, node):
	token = pump.next()
	if len(token) == 0:
		return False
	if token.count(".") > 1:
		return False
	if token.replace(".","").isdigit():
		node.add_child(Node('floatConstant', token))
		return True
	return False

ELEMENTS_DICT = {
	'keyword' : ('piece', 'static', 'var', 'while', 'for', 'if', 'else', 'return',
				'call', 'start', 'script', 'spin', 'stop', 'turn', 'move', 'wait',
				'from', 'to', 'along', 'around', 'x', 'y', 'z', 'axis', 'speed', 'now', 'accelerate', 'decelerate',
				'hide', 'show', 'set', 'get', 'explode', 'signal', 'mask', 'emit', 'sfx', 'type', 'sleep',
				'attach', 'drop', 'unit', 'rand', 'unknown_unit_value',
				'dont', 'cache', 'shade', 'shadow', 'play', 'sound'),
	'symbol' : ('{', '}', '(', ')', '[', ']', ',', ';', '+', '-', '*', '/', '&', '|',
				'<', '>', '=', '!', 'or', 'and', 'not'),
}

ATOMS_DICT = {
	'_integerConstant' : parse_int,
	'_floatConstant' : parse_float,
	'_stringConstant' : parse_string,
	'_identifier' : parse_identifier,
}

PARSER_DICT = {
	'_file' : (('_declaration%',),),
	'_declaration' : (('_pieceDec',), ('_staticVarDec',), ('_funcDec',),),
	'_pieceDec' : (('piece', '_pieceName', '_commaPiece%', ';',),),
	'_commaPiece' : ((',', '_pieceName',),),
	'_pieceName' : (('_identifier',),),
	'_staticVarDec' : (('static', '-', 'var', '_varName', '_commaVar%', ';',),),
	'_commaVar' : ((',', '_varName',),),
	'_varName' : (('_identifier',),),
	'_funcDec' : (('_funcName', '(', '_argumentList', ')', '_statementBlock',),),
	'_funcName' : (('_identifier',),),
	'_argumentList' : (('_arguments?',),),
	'_arguments' : (('_varName', '_commaVar%',),),

	'_statement' : (('_keywordStatement', ';',), ('_varStatement', ';',), ('_ifStatement',), ('_whileStatement',), ('_forStatement',), ('_assignStatement', ';',), (';',),),
	'_assignStatement' : (('_varName', '=', '_expression',), ('_incStatement',), ('_decStatement',),),
	'_incStatement' : (('+', '+', '_varName',),),
	'_decStatement' : (('-', '-', '_varName',),),
	'_ifStatement' : (('if', '(', '_expression', ')', '_statementBlock', '_elseBlock?',),),
	'_elseBlock' : (('else', '_statementBlock',),),
	'_whileStatement' : (('while', '(', '_expression', ')', '_statementBlock',),),
	'_forStatement' : (('for', '(', '_expression', ';', '_expression', ';', '_expression', ';?', ')', '_statementBlock',),),
	'_statementBlock' : (('{', '_statement%', '}',), ('_statement',),),

	'_keywordStatement' : 	(
								('_callStatement',),
								('_startStatement',),
								('_spinStatement',),
								('_stopSpinStatement',),
								('_turnStatement',),
								('_moveStatement',),
								('_waitForTurnStatement',),
								('_waitForMoveStatement',),
								('_emitSfxStatement',),
								('_sleepStatement',),
								('_hideStatement',),
								('_showStatement',),
								('_explodeStatement',),
								('_signalStatement',),
								('_setSignalMaskStatement',),
								('_setStatement',),
								('_getStatement',),
								('_attachUnitStatement',),
								('_dropUnitStatement',),
								('_returnStatement',),
								# ('_breakStatement',),
								# ('_continueStatement',),
								# ('_soundStatement',),
								('_playSoundStatement',),
								# ('_stopSoundStatement',),
								# ('_missionCommandStatement',),
								('_cacheStatement',),
								('_dontCacheStatement',),
								('_dontShadowStatement',),
								('_dontShadeStatement',),
							),

	'_varStatement' : (('var', '_arguments',),),
	'_callStatement' : (('call', '-', 'script', '_funcName', '(', '_expressionList', ')',),),
	'_startStatement' : (('start', '-', 'script', '_funcName', '(', '_expressionList', ')',),),
	'_spinStatement' : (('spin', '_pieceName', 'around', '_axis', 'speed', '_expression', '_optionalAcceleration'),),
	'_optionalAcceleration' : (('_acceleration?',),),
	'_acceleration' : (('accelerate', '_expression',),),
	'_stopSpinStatement' : (('stop', '-', 'spin', '_pieceName', 'around', '_axis', '_optionalDeceleration',),),
	'_optionalDeceleration' : (('_deceleration?',),),
	'_deceleration' : (('decelerate', '_expression',),),
	'_turnStatement' : (('turn', '_pieceName', 'to', '_axis', '_expression', '_speedNow',),),
	'_moveStatement' : (('move', '_pieceName', 'to', '_axis', '_expression', '_speedNow',),),
	'_speedNow' : (('now',), ('speed', '_expression',),),

	'_waitForTurnStatement' : (('wait', '-', 'for', '-', 'turn', '_pieceName', 'around', '_axis',),),
	'_waitForMoveStatement' : (('wait', '-', 'for', '-', 'move', '_pieceName', 'along', '_axis',),),

	'_emitSfxStatement' : (('emit', '-', 'sfx', '_expression', 'from', '_pieceName',),),
	'_sleepStatement' : (('sleep', '_expression',),),
	'_hideStatement' : (('hide', '_pieceName',),),
	'_showStatement' : (('show', '_pieceName',),),
	'_explodeStatement' : (('explode', '_pieceName', 'type', '_expression',),),
	'_signalStatement' : (('signal', '_expression',),),
	'_setSignalMaskStatement' : (('set', '-', 'signal','-','mask', '_expression',),),
	'_setStatement' : (('set', '_expression', 'to', '_expression',),),
	'_getStatement' : (('_get',),),
	'_attachUnitStatement' : (('attach', '-', 'unit', '_expression', 'to', '_expression',),),
	'_dropUnitStatement' : (('drop', '-', 'unit', '_expression',),),
	'_returnStatement' : (('return', '_optionalExpression',),),

	'_cacheStatement' : (('cache', '_pieceName',),),
	'_dontCacheStatement' : (('dont', '-', 'cache', '_pieceName',),),
	'_dontShadowStatement' : (('dont', '-', 'shadow', '_pieceName',),),
	'_dontShadeStatement' : (('dont', '-', 'shade', '_pieceName',),),

	'_playSoundStatement' : (('play', '-', 'sound', '(', '_stringConstant', '_commaExpression', ')'),),

	'_axis' : (('_axisLetter', '-', 'axis'),),
	'_axisLetter' : (('x',),('y',),('z',),),
	'_expressionList' : (('_expressions?',),),
	'_expressions' : (('_expression', '_commaExpression%'),),
	'_commaExpression' : ((',', '_expression'),),
	'_optionalCommaExpression' : (('_commaExpression?',),),
	'_expression' : (('_term', '_opterm%',),),
	'_optionalExpression' : (('_expression?',),),
	'_term' : (('_get',), ('_rand',), ('(', '_expression', ')',), ('_unaryOp', '_term',), ('_varName',),
			   ('_constant',),),
	'_get' : (('get', '_term', '(', '_expression', '_optionalCommaExpression', '_optionalCommaExpression', '_optionalCommaExpression', ')',), ('get', '_term',),),
	# '_unitValue' : (('_expression',),),
	'_rand' : (('rand', '(' , '_expression', ',', '_expression', ')',),),
	'_opterm' : (('_op', '_term',),),
	'_op' : (('=', '=',), ('<' , '=',), ('>', '=',), ('!', '=',), ('|', '|',), ('&', '&',), ('+',), ('-',), ('*',), ('/',), ('&',), ('|',), ('<',), ('>',), ('OR',), ('AND',),),
	'_unaryOp' : (('!',), ('NOT',),),
	'_constant' : (('<', '_signedFloatConstant', '>',), ('[', '_signedFloatConstant', ']',), ('_signedFloatConstant',), ('_signedIntegerConstant',), ),
	'_signedFloatConstant' : (('-', '_floatConstant',), ('_floatConstant',),),
	'_signedIntegerConstant' : (('-', '_integerConstant',), ('_integerConstant',),),
}

AXES = ('x', 'y', 'z')
IGNORED_SYMBOLS = (';','(',')', '{', '}', ',')
IGNORED_KEYWORDS = ('accelerate','decelerate')




class Compiler(object):
	def __init__(self, tree):
		self._static_vars = []
		self._local_vars = []
		self._pieces = []
		self._functions = []
		self._code = ""
		self._total_offset  = 0
		self._functions_code = {}
		self._compile_funcs = {
			# 'class' : self.parse_class,
			'file' : self.parse_file,
			'staticVarDec' : self.parse_staticVarDec,
			'pieceDec' : self.parse_pieceDec,
			'funcDec' : self.parse_funcDec,
			'arguments' : self.parse_arguments,
			'assignStatement' : self.parse_assignStatement,
			'incStatement' : self.parse_incStatement,
			'decStatement' : self.parse_decStatement,
			'keywordStatement' : self.parse_keywordStatement,
			'varStatement' : self.parse_varStatement,
			'rand' : self.parse_rand,
			'get' : self.parse_get,
			'ifStatement' : self.parse_ifStatement,
			'whileStatement' : self.parse_whileStatement,
			'term' : self.parse_term,
			'unaryOp' : self.parse_unaryOp,
			'constant' : self.parse_constant,
			'expression' : self.parse_expression,
			# 'stringConstant' : self.parse_stringConstant,
			'symbol' : self.parse_symbol,
			'keyword' : self.parse_keyword,
		}
		self._vars_to_push_opcodes = (
			(self._local_vars, OPCODES["PUSH_LOCAL_VAR"]),
			(self._static_vars, OPCODES["PUSH_STATIC"]),
			(self._pieces, OPCODES["PUSH_CONSTANT"]),
		)
		self._vars_to_pop_opcodes = (
			(self._local_vars, OPCODES["POP_LOCAL_VAR"]),
			(self._static_vars, OPCODES["POP_STATIC"]),
		)
		self.parse(tree)

	def current_offset(self):
		return self._total_offset + len(self._code) / 4

	def parse(self, node):
		node_type = node.get_type()
		if node_type in self._compile_funcs:
			self._compile_funcs[node_type](node)
		else:
			self.parse_children(node)

	def parse_children(self, node):
		if len(node.get_children()) == 0:
			raise Exception("node not handled %s: %s" % (node.get_type(),node.get_text()))
		for child in node.get_children():
			self.parse(child)

	def parse_file(self, node):
		for child_node in node.get_children():
			if child_node[0].get_type() == 'funcDec':
				self._functions.append(child_node[0][0].get_text())

		self.parse_children(node)

	def parse_staticVarDec(self, node):
		self._static_vars.append(node[3].get_text())

		for comma_var in node.get_children()[4:]:
			if comma_var.get_type() == 'commaVar':
				self._static_vars.append(comma_var[1].get_text())

	def parse_pieceDec(self, node):
		self._pieces.append(node[1].get_text())

		for comma_piece in node.get_children()[2:]:
			if comma_piece.get_type() == 'commaPiece':
				self._pieces.append(comma_piece[1].get_text())

	def parse_funcDec(self, node):
		del self._local_vars[0:]
		self._code = ""
		if len(node[2].get_children()) > 0:
			self.parse(node[2])

		code_len = len(self._code)
		self.parse(node[4])

		#clean code if empty
		if len(self._code) == code_len:
			self._code = ""

		#insert return if necessary
		if self._code[-4:] != OPCODES['RETURN']:
			self._code += OPCODES['PUSH_CONSTANT'] + get_num(0)
			self._code += OPCODES['RETURN']

		self._total_offset += len(self._code) / 4
		self._functions_code[node[0].get_text()] = self._code


	def parse_varStatement(self, node):
		self.parse(node[1])

	def parse_arguments(self, node):
		if len(node.get_children()) == 0:
			return

		self._local_vars.append(node[0].get_text())
		self._code += OPCODES['CREATE_LOCAL_VAR']

		for comma_var in node.get_children()[1:]:
			if comma_var.get_type() == 'commaVar':
				self._local_vars.append(comma_var[1].get_text())
				self._code += OPCODES['CREATE_LOCAL_VAR']


	def parse_assignStatement(self, node):
		if len(node.get_children()) < 3:
			self.parse_children(node)
			return

		self.parse(node[2])

		self._code += self.get_variable(node[0].get_text(), False)


	def parse_incStatement(self, node):
		self._code += "%s%s%s%s%s" % (self.get_variable(node[2].get_text(), True),
									OPCODES['PUSH_CONSTANT'],
									get_num(1),
									OPCODES['ADD'],
									self.get_variable(node[2].get_text(), False))

	def parse_decStatement(self, node):
		self._code += "%s%s%s%s%s" % (self.get_variable(node[2].get_text(), True),
									OPCODES['PUSH_CONSTANT'],
									get_num(1),
									OPCODES['SUB'],
									self.get_variable(node[2].get_text(), False))


	def parse_keywordStatement(self, node):
		node = node[0]

		#get result needs to be handled separately and removed from the stack
		if len(node[0].get_children()) > 0 and node[0][0].get_text() == 'get':
			self.parse(node)
			self._code += OPCODES['POP_STACK']
			return

		keyword = node[0].get_text()

		i = 0
		#fix split keywords
		while node[i + 1].get_text() == '-':
			keyword += '-%s' % (node[i + 2].get_text())
			i += 2

		if keyword == 'set' or keyword == 'attach-unit':
			children = node.get_children()
		else:
			children = node.get_children()[::-1]


		arguments = []
		for child_node in children:
			if child_node.get_type() == 'pieceName':
				piece_name = child_node.get_text()
				piece_index = index(self._pieces, piece_name)
				if piece_index < 0:
					raise Exception('Piece not found: %s' % (piece_name,))
				arguments.append(piece_index)
			elif child_node.get_type() == 'funcName':
				func_name = child_node.get_text()
				func_index = index(self._functions, func_name)
				if func_index < 0:
					raise Exception("Function not found: %s" % (func_name,))
				arguments.append(func_index)
			elif child_node.get_type() == 'axis':
				arguments.append(AXES.index(child_node[0].get_text()))
			elif child_node.get_type() == 'expression':
				self.parse(child_node)
			elif child_node.get_type() == 'expressionList':
				if len(child_node.get_children()) > 0:
					self.parse(child_node[0])
					arguments.append(len(child_node[0].get_children()))
				else:
					arguments.append(0)
			elif child_node.get_type() == 'speedNow':
				if child_node[0].get_text() == 'now':
					keyword += "-now"
				else:
					self.parse(child_node[1])
			elif child_node.get_type().startswith('optional'):
				if len(child_node.get_children()) == 0:
					self._code += OPCODES['PUSH_CONSTANT'] + get_num(0)
				else:
					self.parse_children(child_node)

		#has a dummy arg :(
		if keyword == 'attach-unit':
			self._code += OPCODES['PUSH_CONSTANT'] + get_num(0)

		opcode_name = keyword.upper().replace("-","_")

		if opcode_name in OPCODES:
			opcode = OPCODES[opcode_name]
		else:
			raise Exception('Unhandled keyword %s %s' % (keyword, opcode_name))

		self._code += opcode + struct.pack("<%dL" % len(arguments), *arguments[::-1])


	def parse_get(self, node):
		num_expressions = 0
		for child_node in node.get_children()[1:]:
			if child_node.get_type() == 'expression' or child_node.get_type() == 'term':
				self.parse(child_node)
				num_expressions += 1
			elif child_node.get_type().startswith('optional'):
				num_expressions += 1
				if len(child_node.get_children()) == 0:
					self._code += OPCODES['PUSH_CONSTANT'] + get_num(0)
				else:
					self.parse_children(child_node)

		if num_expressions == 1:
			self._code += OPCODES['GET_UNIT_VALUE']
			return

		self._code += OPCODES['GET']
		return

	def parse_rand(self, node):
		self.parse(node[2])
		self.parse(node[4])
		self._code += OPCODES['RAND']
		return


	def parse_ifStatement(self, node):
		has_else = len(node.get_children()) > 5
		self.parse(node[2])
		self._code += OPCODES['JUMP_NOT_EQUAL']
		condition_jump = len(self._code)
		self._code += get_num(0) #placeholder
		self.parse(node[4])
		if has_else:
			self._code += OPCODES['JUMP']
			else_jump = len(self._code)
			self._code += get_num(0) #placeholder

		self._code = "%s%s%s" % (self._code[:condition_jump], get_num(self.current_offset()), self._code[condition_jump + 4:])

		if has_else:
			self.parse(node[5][1])
			self._code = "%s%s%s" % (self._code[:else_jump], get_num(self.current_offset()), self._code[else_jump + 4:])


	def parse_expression(self, node):
		self.parse(node[0])

		if len(node.get_children()) == 1:
			return

		op_stack = []
		for op_term in node.get_children()[1:]:
			op = op_term[0].get_text()
			while len(op_stack) > 0 and OPS_PRECEDENCE[op_stack[-1]] <= OPS_PRECEDENCE[op]:
				self._code += OPS[op_stack.pop()]
			self.parse(op_term[1])
			op_stack.append(op)
		while len(op_stack) > 0:
			self._code += OPS[op_stack.pop()]


	def parse_whileStatement(self, node):
		start = self.current_offset()
		self.parse(node[2])
		self._code += OPCODES['JUMP_NOT_EQUAL']
		condition_jump = len(self._code)
		self._code += get_num(0) #placeholder
		self.parse(node[4])
		self._code += OPCODES['JUMP']
		self._code += get_num(start)
		self._code = "%s%s%s" % (self._code[:condition_jump], get_num(self.current_offset()), self._code[condition_jump + 4:])


	def parse_term(self, node):
		if node[0].get_type() == 'unaryOp':
			self.parse(node[1])
			self.parse(node[0])
		elif node[0].get_type() == 'varName':
			self._code += self.get_variable(node[0].get_text(), True)
		else:
			self.parse_children(node)

	def parse_constant(self, node):
		self._code += OPCODES['PUSH_CONSTANT']
		if len(node.get_children()) == 1: #normal number
			value = round(float(node.get_text()))
			if value < 0:
				self._code += get_signed_num(value)
			else:
				self._code += get_num(value)
		else:
			if node[0].get_text() == '[':
				value = int(LINEAR_SCALE * float(node[1].get_text()))
			elif node[0].get_text() == '<':
				value = int(ANGULAR_SCALE * float(node[1].get_text()))
			else:
				raise Exception("Unhandled fancy number: %s" % (node.get_text(),))
			if value < 0:
				self._code += get_signed_num(value)
			else:
				self._code += get_num(value)

	def parse_stringConstant(self, node):
		raise Exception("strings not yet implemented")

	def parse_op(self, node):
		self._code += OPS[node.get_text()]

	def parse_unaryOp(self, node):
		self._code += UNARY_OPS[node.get_text()]

	def parse_symbol(self, node):
		symbol = node.get_text()
		if symbol not in IGNORED_SYMBOLS:
			raise Exception("Unhandled symbol %s" % (symbol,))

	def parse_keyword(self, node):
		keyword = node.get_text()
		if keyword not in IGNORED_KEYWORDS:
			raise Exception("Unhandled keyword %s" % (keyword,))

	def get_variable(self, var_name, push):
		if push:
			opcodes = self._vars_to_push_opcodes
		else:
			opcodes = self._vars_to_pop_opcodes

		for vars, opcode in opcodes:
			i = index(vars, var_name)
			if i < 0:
				continue
			return opcode + get_num(i)
		raise Exception("Var not found: %s" % (var_name,))

	def get_cob(self):
		cob = cob_file.COB(self._functions, self._functions_code, self._pieces, self._static_vars, [])
		return cob.get_content()



class Pump(object):
	def __init__(self, generator):
		self._leftovers = [token for token in generator]
		self._index = 0
		self._max_index = 0

	def next(self):
		if self._index < len(self._leftovers):
			token = self._leftovers[self._index]
			self._index += 1
			self._max_index = max(self._max_index, self._index)
			return token
		else:
			return ""


	def update(self, result, index = 0):
		if not result:
			self._index = index

	def get_index(self):
		return self._index


def parse(pump, node, block_type):
	if block_type in ATOMS_DICT:
		return ATOMS_DICT[block_type](pump, node)
	for element_type in ELEMENTS_DICT:
		if block_type.lower() in ELEMENTS_DICT[element_type]:
			next = pump.next()
			if next.lower() == block_type.lower():
				node.add_child(Node(element_type, next))
				return True
			return False
	current_node = Node(block_type.strip('?%_'))
	for alternative in PARSER_DICT[block_type]:
		alternative_correct = True
		index = pump.get_index()
		for child_type in alternative:
			maybe = False
			multiple = False
			if child_type.endswith('%'):
				maybe = True
				multiple = True
			elif child_type.endswith('?'):
				maybe = True
			else:
				maybe = False

			first = True
			while first or multiple:
				first = False
				result = try_parse(pump, current_node, child_type.strip('?%'))
				if not result:
					break
			if not (result or maybe):
				alternative_correct = False
				break
		if alternative_correct:
			node.add_child(current_node)
			return True
		pump.update(False, index)
		current_node.clear()
	return False

def try_parse(pump, node, block_type):
	index = pump.get_index()
	result = parse(pump, node, block_type)
	pump.update(result, index)
	return result




def token_generator(code):
	symbol_delimiters = ['{', '}', '[', ']', '(', ')', ' ', '&', '|', '+', '-', '*', '/', ',', ';', '<', '>', '=', '!', '#', '\t', '\r', '\n', '\\']
	is_line_comment = False
	is_multi_line_comment = False
	is_in_quotation = False
	is_preprocessor = False
	skip = False

	idx = 0
	prev_idx = 0

	while (idx < len(code)):
		if not is_line_comment and not is_multi_line_comment and not is_in_quotation and code[idx] == '"':
			is_in_quotation = True
			prev_idx = idx
			idx+=1
			continue

		if not is_line_comment and not is_multi_line_comment and is_in_quotation and code[idx] == '"':
			is_in_quotation = False
			idx+=1
			yield code[prev_idx:idx]
			prev_idx = idx
			continue

		if not is_line_comment and not is_multi_line_comment and not is_in_quotation and code[idx:idx+2] == "//":
			is_line_comment = True
			s = code[prev_idx:idx].strip()
			if len(s) > 0:
				yield s
			if is_preprocessor:
				is_preprocessor = False
				yield '$'
			idx+=2
			prev_idx = idx
			continue

		if not is_line_comment and not is_multi_line_comment and not is_in_quotation and code[idx:idx+2] == "/*":
			is_multi_line_comment = True
			s = code[prev_idx:idx].strip()
			if len(s) > 0:
				yield s
			idx+=2
			prev_idx = idx
			continue

		if not is_line_comment and not is_multi_line_comment and not is_in_quotation and not is_preprocessor and code[idx] == "#":
			is_preprocessor = True
			s = code[prev_idx:idx].strip()
			if len(s) > 0:
				yield s
			yield '#'
			idx+=1
			prev_idx = idx
			continue

		if not is_line_comment and not is_multi_line_comment and not is_in_quotation and is_preprocessor and code[idx] == "\n" and code[idx-1:idx] != '\\' and code[idx-2:idx] != '\\\r':
			is_preprocessor = False
			s = code[prev_idx:idx].strip()
			if len(s) > 0:
				yield s
			yield '$' #mark end of preprocessor directive
			idx+=1
			prev_idx = idx
			continue

		if is_line_comment and code[idx:idx+1] == '\n':
			is_line_comment = False
			idx+=1
			prev_idx = idx
			continue

		if is_multi_line_comment and code[idx:idx+2] == "*/":
			is_multi_line_comment = False
			idx+=2
			prev_idx = idx
			continue

		skip = is_multi_line_comment or is_line_comment or is_in_quotation
		if not skip and (code[idx] in symbol_delimiters):
			token = code[prev_idx:idx].strip().strip('\\')
			if len(token) > 0:
				yield token

			symbol_token = code[idx:idx+1].strip().strip('\\')
			if len(symbol_token) > 0:
				yield symbol_token

			idx+=1
			prev_idx=idx
			continue

		idx+=1

	if not skip and idx == len(code):
		token = code[prev_idx:idx].strip()
		prev_idx = idx
		if len(token) > 0:
			yield token


def preprocess(code, include_path, defs = {"TRUE" : "1", "FALSE" : "0", "UNKNOWN_UNIT_VALUE" : ""}, recursion = 0):
	if recursion > 10:
		print "Error: recursion limit reached"
		exit(1)

	gen = token_generator(code)
	is_preprocessor_directive = False
	skip = 0
	ifs = 0
	while True:
		try:
			token = gen.next()
		except:
			if ifs > 0:
				print "Error: Missing #endif"
				exit(1)
			if is_preprocessor_directive:
				print "Preprocessor error"
				exit(1)
			break

		if token == '#':
			is_preprocessor_directive = True
			continue

		if token == '$':
			continue

		if not is_preprocessor_directive:
			if skip > 0:
				continue
			if token not in defs:
				yield token
				continue

			for prep_tokens in preprocess(defs[token], include_path, defs, recursion + 1):
				yield prep_tokens
			continue

		is_preprocessor_directive = False

		if token.lower() == 'include':
			if skip > 0:
				continue
			included = gen.next().strip('"')
			try:
				if not os.path.exists(included):
					alt_path = os.path.join(include_path, included)
					if not os.path.exists(alt_path):
						print 'Error: can\'t find %s' % included
						exit(1)
					included = alt_path

				content = open(included, 'rb').read()
				for prep_tokens in preprocess(content, include_path, defs, recursion + 1):
					yield prep_tokens
			except:
				print 'Error: Couldn\'t include %s' % (included,)
				exit(1)
			continue

		if token.lower() == 'define':
			if skip > 0:
				continue
			current_definition = gen.next()
			defs[current_definition] = ""
			while True:
				token = gen.next()
				if token == '$':
					break
				defs[current_definition] += " " + token
			continue

		if token.lower() == 'undef':
			if skip > 0:
				continue
			current_definition = gen.next()
			del defs[current_definition]
			continue

		if token.lower() == 'ifdef':
			ifs += 1
			if skip > 0:
				skip += 1
				continue
			current_definition = gen.next()
			if current_definition not in defs:
				skip += 1

			continue

		if token.lower() == 'ifndef':
			ifs += 1
			if skip > 0:
				skip += 1
				continue

			current_definition = gen.next()
			if current_definition in defs:
				skip += 1

			continue

		if token.lower() == 'if':
			ifs += 1
			if skip > 0:
				skip += 1
				continue
			query = ""
			while True:
				token = gen.next()
				if token == '$':
					break
				else:
					query += token

			query = "".join(preprocess(query, include_path, defs, recursion + 1))
			result = eval(query.strip())
			if not result or result == 0:
				skip += 1
			continue

		if token.lower() == 'else':
			if skip == 1:
				skip = 0
			elif skip == 0:
				skip = 1
			continue

		if token.lower() == 'endif':
			if ifs == 0:
				print "Error: extraneous #endif"
				exit(1)
			ifs -= 1
			if skip > 0:
				skip -= 1
			continue

		print "Error: unhandled token %s" % (token,)
		exit(1)





def main(path, output_path = None):
	if path[-1] == '/':
		input_path = path[:-1]
	else:
		input_path = path
	if not os.path.exists(input_path):
		print "File %s doesn't exist" % (input_path,)
		exit()
	if os.path.isdir(input_path):
		include_path = input_path
		sys.path.append(input_path)
		files = glob(os.path.join(input_path,"*.%s" % (BOS_EXT,)))
	else:
		files = [input_path]
		input_path = os.path.split(input_path)[0]
	for bos_file_path in files:
		print "processing %s" % (bos_file_path,)
		root = Node('root')
		content = open(bos_file_path, 'rb').read()
		pump = Pump(preprocess(content, input_path))
		result = try_parse(pump, root, '_file')
		if len(pump.next()) != 0:
			print "Syntax Error!"
			print pump._leftovers[pump._index - 1:pump._max_index], pump._index, pump._max_index
			exit(1)

		# root.print_node()
		# output_file = open(output_path, "wb")
		# sys.stdout = output_file
		comp = Compiler(root)

		#OUTPUT NEW COB

		data = comp.get_cob()
		print (len(data))
		if output_path == None:
			output_path = "%s.%s" % (os.path.splitext(bos_file_path)[0], COB_EXT)
		output_file = open(output_path, "wb")
		output_file.write(data)



		#DEBUG FUNCTIONS

		# for f in comp._functions:
		# 	func_path = "%s_%s.%s" % (os.path.splitext(bos_file_path)[0], f, COB_EXT)
		# 	open(func_path, "wb").write(comp._functions_code[f])



		# COMPARE TO COBS

		# original_path = "%s.%s" % (os.path.splitext(bos_file_path)[0], COB_EXT)
		# if os.path.exists(original_path):
			# original_data = open(original_path, "rb").read()
			# if original_data == data:
				# print "Binary same!"
			# else:
				# output_path = "%s.new.%s" % (os.path.splitext(bos_file_path)[0], COB_EXT)
				# output_file = open(output_path, "wb")
				# output_file.write(data)
				# output_file.close()
		# else:
			# print "Nothing to compare to!"






if __name__ == '__main__':
	main(sys.argv[1])