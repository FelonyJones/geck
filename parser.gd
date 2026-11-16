# converted from godot/core/math/expression.cpp

# class_name CustomExpression
extends RefCounted

# ==============================================================================
# Tokens
# ==============================================================================

enum TokenType {
	CURLY_BRACKET_OPEN,
	CURLY_BRACKET_CLOSE,
	BRACKET_OPEN,
	BRACKET_CLOSE,
	PARENTHESIS_OPEN,
	PARENTHESIS_CLOSE,
	IDENTIFIER,
	BUILTIN_TYPE,
	SELF,
	CONSTANT,
	COLON,
	COMMA,
	PERIOD,
	OP_IN,
	OP_EQUAL,
	OP_NOT_EQUAL,
	OP_LESS,
	OP_LESS_EQUAL,
	OP_GREATER,
	OP_GREATER_EQUAL,
	OP_AND,
	OP_OR,
	OP_NOT,
	OP_ADD,
	OP_SUB,
	OP_MUL,
	OP_DIV,
	OP_MOD,
	OP_POWER,
	OP_SHIFT_LEFT,
	OP_SHIFT_RIGHT,
	OP_BIT_AND,
	OP_BIT_OR,
	OP_BIT_XOR,
	OP_BIT_INVERT,
	IF,
	ELSE,
	EOF,
	ERROR,
}

class Token:
	var type: TokenType = TokenType.EOF
	var value: Variant = null

	func _init(p_type: TokenType = TokenType.EOF, p_value: Variant = null) -> void:
		type = p_type
		value = p_value


# ==============================================================================
# AST Nodes (Equivalent to ENode hierarchy in expression.h)
# ==============================================================================

class ENode extends RefCounted:
	pass

class InputNode extends ENode:
	var index: int = 0
	func _init(p_index: int) -> void:
		index = p_index

class ConstantNode extends ENode:
	var value: Variant = null
	func _init(p_value: Variant) -> void:
		value = p_value

class OperatorNode extends ENode:
	var op: Variant.Operator
	var nodes: Array[ENode] = []
	func _init(p_op: Variant.Operator, p_nodes: Array[ENode]) -> void:
		op = p_op
		nodes = p_nodes

class SelfNode extends ENode:
	pass

class IndexNode extends ENode:
	var base: ENode
	var index: ENode
	func _init(p_base: ENode, p_index: ENode) -> void:
		base = p_base
		index = p_index

class NamedIndexNode extends ENode:
	var base: ENode
	var name: StringName
	func _init(p_base: ENode, p_name: StringName) -> void:
		base = p_base
		name = p_name

class CallNode extends ENode:
	var base: ENode
	var method: StringName
	var arguments: Array[ENode] = []
	func _init(p_base: ENode, p_method: StringName, p_args: Array[ENode] = []) -> void:
		base = p_base
		method = p_method
		arguments = p_args

class BuiltinFuncNode extends ENode:
	var func_name: StringName
	var arguments: Array[ENode] = []
	func _init(p_func_name: StringName, p_args: Array[ENode] = []) -> void:
		func_name = p_func_name
		arguments = p_args

class ConstructNode extends ENode:
	var data_type: Variant.Type
	var arguments: Array[ENode] = []
	func _init(p_type: Variant.Type, p_args: Array[ENode] = []) -> void:
		data_type = p_type
		arguments = p_args

class ArrayNode extends ENode:
	var array: Array[ENode] = []
	func _init(p_array: Array[ENode] = []) -> void:
		array = p_array

class DictionaryNode extends ENode:
	# Interleaved [key0, val0, key1, val1, ...]
	var dict: Array[ENode] = []
	func _init(p_dict: Array[ENode] = []) -> void:
		dict = p_dict

class TernaryNode extends ENode:
	var condition: ENode
	var true_expr: ENode
	var false_expr: ENode
	func _init(p_cond: ENode, p_true: ENode, p_false: ENode) -> void:
		condition = p_cond
		true_expr = p_true
		false_expr = p_false

class ExpressionEntry extends RefCounted:
	var node: ENode = null
	var op: Variant.Operator = Variant.Operator.OP_MAX
	var is_ternary: bool = false


# ==============================================================================
# Lookup Tables
# ==============================================================================

const BUILTIN_TYPES: Dictionary = {
	"bool": TYPE_BOOL,
	"int": TYPE_INT,
	"float": TYPE_FLOAT,
	"String": TYPE_STRING,
	"Vector2": TYPE_VECTOR2,
	"Vector2i": TYPE_VECTOR2I,
	"Rect2": TYPE_RECT2,
	"Rect2i": TYPE_RECT2I,
	"Vector3": TYPE_VECTOR3,
	"Vector3i": TYPE_VECTOR3I,
	"Transform2D": TYPE_TRANSFORM2D,
	"Vector4": TYPE_VECTOR4,
	"Vector4i": TYPE_VECTOR4I,
	"Plane": TYPE_PLANE,
	"Quaternion": TYPE_QUATERNION,
	"AABB": TYPE_AABB,
	"Basis": TYPE_BASIS,
	"Transform3D": TYPE_TRANSFORM3D,
	"Projection": TYPE_PROJECTION,
	"Color": TYPE_COLOR,
	"StringName": TYPE_STRING_NAME,
	"NodePath": TYPE_NODE_PATH,
	"RID": TYPE_RID,
	"Callable": TYPE_CALLABLE,
	"Signal": TYPE_SIGNAL,
	"Dictionary": TYPE_DICTIONARY,
	"Array": TYPE_ARRAY,
	"PackedByteArray": TYPE_PACKED_BYTE_ARRAY,
	"PackedInt32Array": TYPE_PACKED_INT32_ARRAY,
	"PackedInt64Array": TYPE_PACKED_INT64_ARRAY,
	"PackedFloat32Array": TYPE_PACKED_FLOAT32_ARRAY,
	"PackedFloat64Array": TYPE_PACKED_FLOAT64_ARRAY,
	"PackedStringArray": TYPE_PACKED_STRING_ARRAY,
	"PackedVector2Array": TYPE_PACKED_VECTOR2_ARRAY,
	"PackedVector3Array": TYPE_PACKED_VECTOR3_ARRAY,
	"PackedColorArray": TYPE_PACKED_COLOR_ARRAY,
	"PackedVector4Array": TYPE_PACKED_VECTOR4_ARRAY,
}

static var _builtin_funcs: Dictionary = {}


# ==============================================================================
# Instance State
# ==============================================================================

var _expression: String = ""
var _str_ofs: int = 0
var _input_names: PackedStringArray = PackedStringArray()
var _root: ENode = null

var _error_str: String = ""
var _error_set: bool = false
var _execution_error: bool = false


# ==============================================================================
# Public API
# ==============================================================================

func parse(p_expression: String, p_input_names: PackedStringArray = PackedStringArray()) -> Error:
	_ensure_builtin_funcs()
	_expression = p_expression
	_input_names = p_input_names
	_str_ofs = 0
	_error_str = ""
	_error_set = false
	_execution_error = false
	_root = null

	_root = _parse_expression()
	if _error_set:
		_root = null
		return ERR_INVALID_PARAMETER

	var end_tok := _get_token()
	if end_tok.type != TokenType.EOF:
		_set_error("Expected end of expression.")
		_root = null
		return ERR_INVALID_PARAMETER

	return OK


func execute(
	p_inputs: Array = [],
	p_base_instance: Object = null,
	p_show_error: bool = true,
	p_const_calls_only: bool = false
) -> Variant:
	_execution_error = false

	if _error_set:
		_execution_error = true
		if p_show_error:
			push_error("Expression has parse errors: " + _error_str)
		return null

	if _root == null:
		_execution_error = true
		return null

	var result: Variant = _execute(_root, p_inputs, p_base_instance, p_const_calls_only)
	if _execution_error:
		if p_show_error:
			push_error(_error_str)
		return null

	return result


func has_execute_failed() -> bool:
	return _execution_error


func get_error_text() -> String:
	return _error_str


# ==============================================================================
# Error Helpers
# ==============================================================================

func _set_error(p_err: String) -> void:
	if not _error_set:
		_error_str = p_err
		_error_set = true


func _set_exec_error(p_err: String) -> void:
	if not _execution_error:
		_error_str = p_err
		_execution_error = true


# ==============================================================================
# Lexer / Tokenizer
# ==============================================================================

func _is_digit(c: int) -> bool:
	return c >= 48 and c <= 57 # '0'..'9'


func _is_hex_digit(c: int) -> bool:
	return _is_digit(c) or (c >= 97 and c <= 102) or (c >= 65 and c <= 70)


func _is_binary_digit(c: int) -> bool:
	return c == 48 or c == 49 # '0' or '1'


func _is_ascii_ident_start(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 # A-Z, a-z, _


func _is_ascii_ident_continue(c: int) -> bool:
	return _is_ascii_ident_start(c) or _is_digit(c)


func _peek_char(offset: int = 0) -> int:
	var idx := _str_ofs + offset
	if idx < 0 or idx >= _expression.length():
		return 0
	return _expression.unicode_at(idx)


func _get_token() -> Token:
	while _str_ofs < _expression.length():
		var c := _peek_char()

		# Skip whitespace
		if c <= 32:
			_str_ofs += 1
			continue

		match c:
			123: # '{'
				_str_ofs += 1
				return Token.new(TokenType.CURLY_BRACKET_OPEN)
			125: # '}'
				_str_ofs += 1
				return Token.new(TokenType.CURLY_BRACKET_CLOSE)
			91: # '['
				_str_ofs += 1
				return Token.new(TokenType.BRACKET_OPEN)
			93: # ']'
				_str_ofs += 1
				return Token.new(TokenType.BRACKET_CLOSE)
			40: # '('
				_str_ofs += 1
				return Token.new(TokenType.PARENTHESIS_OPEN)
			41: # ')'
				_str_ofs += 1
				return Token.new(TokenType.PARENTHESIS_CLOSE)
			58: # ':'
				_str_ofs += 1
				return Token.new(TokenType.COLON)
			44: # ','
				_str_ofs += 1
				return Token.new(TokenType.COMMA)
			46: # '.'
				if _is_digit(_peek_char(1)):
					return _read_number()
				_str_ofs += 1
				return Token.new(TokenType.PERIOD)
			61: # '='
				_str_ofs += 1
				if _peek_char() == 61: # '=='
					_str_ofs += 1
					return Token.new(TokenType.OP_EQUAL)
				_set_error("Expected '=='")
				return Token.new(TokenType.ERROR)
			33: # '!'
				_str_ofs += 1
				if _peek_char() == 61: # '!='
					_str_ofs += 1
					return Token.new(TokenType.OP_NOT_EQUAL)
				return Token.new(TokenType.OP_NOT)
			60: # '<'
				_str_ofs += 1
				var nxt := _peek_char()
				if nxt == 61: # '<='
					_str_ofs += 1
					return Token.new(TokenType.OP_LESS_EQUAL)
				elif nxt == 60: # '<<'
					_str_ofs += 1
					return Token.new(TokenType.OP_SHIFT_LEFT)
				return Token.new(TokenType.OP_LESS)
			62: # '>'
				_str_ofs += 1
				var nxt := _peek_char()
				if nxt == 61: # '>='
					_str_ofs += 1
					return Token.new(TokenType.OP_GREATER_EQUAL)
				elif nxt == 62: # '>>'
					_str_ofs += 1
					return Token.new(TokenType.OP_SHIFT_RIGHT)
				return Token.new(TokenType.OP_GREATER)
			43: # '+'
				_str_ofs += 1
				return Token.new(TokenType.OP_ADD)
			45: # '-'
				_str_ofs += 1
				return Token.new(TokenType.OP_SUB)
			42: # '*'
				_str_ofs += 1
				if _peek_char() == 42: # '**'
					_str_ofs += 1
					return Token.new(TokenType.OP_POWER)
				return Token.new(TokenType.OP_MUL)
			47: # '/'
				_str_ofs += 1
				return Token.new(TokenType.OP_DIV)
			37: # '%'
				_str_ofs += 1
				return Token.new(TokenType.OP_MOD)
			38: # '&'
				_str_ofs += 1
				if _peek_char() == 38: # '&&'
					_str_ofs += 1
					return Token.new(TokenType.OP_AND)
				return Token.new(TokenType.OP_BIT_AND)
			124: # '|'
				_str_ofs += 1
				if _peek_char() == 124: # '||'
					_str_ofs += 1
					return Token.new(TokenType.OP_OR)
				return Token.new(TokenType.OP_BIT_OR)
			94: # '^'
				_str_ofs += 1
				return Token.new(TokenType.OP_BIT_XOR)
			126: # '~'
				_str_ofs += 1
				return Token.new(TokenType.OP_BIT_INVERT)
			34, 39: # '"' or '\''
				return _read_string(c)
			_:
				if _is_digit(c):
					return _read_number()
				elif _is_ascii_ident_start(c):
					return _read_identifier()
				else:
					_set_error("Unexpected character.")
					return Token.new(TokenType.ERROR)

	return Token.new(TokenType.EOF)


func _read_string(quote: int) -> Token:
	_str_ofs += 1 # skip opening quote
	var result := ""
	while _str_ofs < _expression.length():
		var c := _peek_char()
		_str_ofs += 1
		if c == quote:
			return Token.new(TokenType.CONSTANT, result)
		elif c == 92: # '\'
			if _str_ofs >= _expression.length():
				_set_error("Unterminated string.")
				return Token.new(TokenType.ERROR)
			var esc := _peek_char()
			_str_ofs += 1
			match esc:
				97: result += "\u0007" # \a
				98: result += "\b"
				102: result += "\f"
				110: result += "\n"
				114: result += "\r"
				116: result += "\t"
				118: result += "\u000b" # \v
				92: result += "\\"
				39: result += "'"
				34: result += "\""
				117, 85, 120: # \uXXXX, \UXXXXXX, \xXX
					var hex_len := 2 if esc == 120 else (4 if esc == 117 else 6)
					var hex_str := ""
					for i in hex_len:
						var hc := _peek_char()
						if not _is_hex_digit(hc):
							_set_error("Invalid unicode/hex escape in string.")
							return Token.new(TokenType.ERROR)
						hex_str += char(hc)
						_str_ofs += 1
					result += char(("0x" + hex_str).hex_to_int())
				_:
					result += char(esc)
		else:
			result += char(c)

	_set_error("Unterminated string.")
	return Token.new(TokenType.ERROR)


func _read_number() -> Token:
	var start := _str_ofs
	var is_float := false

	# Hexadecimal (0x...) or Binary (0b...)
	if _peek_char() == 48: # '0'
		var second := _peek_char(1)
		if second == 120 or second == 88: # 'x' or 'X'
			_str_ofs += 2
			var digits := ""
			while _str_ofs < _expression.length():
				var c := _peek_char()
				if _is_hex_digit(c):
					digits += char(c)
					_str_ofs += 1
				elif c == 95: # '_'
					_str_ofs += 1
				else:
					break
			if digits.is_empty():
				_set_error("Invalid hexadecimal constant.")
				return Token.new(TokenType.ERROR)
			return Token.new(TokenType.CONSTANT, ("0x" + digits).hex_to_int())

		elif second == 98 or second == 66: # 'b' or 'B'
			_str_ofs += 2
			var digits := ""
			while _str_ofs < _expression.length():
				var c := _peek_char()
				if _is_binary_digit(c):
					digits += char(c)
					_str_ofs += 1
				elif c == 95: # '_'
					_str_ofs += 1
				else:
					break
			if digits.is_empty():
				_set_error("Invalid binary constant.")
				return Token.new(TokenType.ERROR)
			return Token.new(TokenType.CONSTANT, ("0b" + digits).bin_to_int())

	# Decimal integer or float
	var num_str := ""
	while _str_ofs < _expression.length():
		var c := _peek_char()
		if _is_digit(c):
			num_str += char(c)
			_str_ofs += 1
		elif c == 95: # '_'
			_str_ofs += 1
		elif c == 46: # '.'
			if is_float or not _is_digit(_peek_char(1)) and _str_ofs == start:
				break
			# Ensure next char isn't another '.' or identifier (e.g. `1.to_float()` vs `1.5`)
			if _is_ascii_ident_start(_peek_char(1)):
				break
			is_float = true
			num_str += "."
			_str_ofs += 1
		elif c == 101 or c == 69: # 'e' or 'E'
			is_float = true
			num_str += "e"
			_str_ofs += 1
			var sign_c := _peek_char()
			if sign_c == 43 or sign_c == 45: # '+' or '-'
				num_str += char(sign_c)
				_str_ofs += 1
		else:
			break

	if is_float:
		return Token.new(TokenType.CONSTANT, num_str.to_float())
	return Token.new(TokenType.CONSTANT, num_str.to_int())


func _read_identifier() -> Token:
	var start := _str_ofs
	while _str_ofs < _expression.length() and _is_ascii_ident_continue(_peek_char()):
		_str_ofs += 1
	var id := _expression.substr(start, _str_ofs - start)

	match id:
		"true":  return Token.new(TokenType.CONSTANT, true)
		"false": return Token.new(TokenType.CONSTANT, false)
		"null":  return Token.new(TokenType.CONSTANT, null)
		"PI":    return Token.new(TokenType.CONSTANT, PI)
		"TAU":   return Token.new(TokenType.CONSTANT, TAU)
		"INF":   return Token.new(TokenType.CONSTANT, INF)
		"NAN":   return Token.new(TokenType.CONSTANT, NAN)
		"in":    return Token.new(TokenType.OP_IN)
		"not":   return Token.new(TokenType.OP_NOT)
		"and":   return Token.new(TokenType.OP_AND)
		"or":    return Token.new(TokenType.OP_OR)
		"self":  return Token.new(TokenType.SELF)
		"if":    return Token.new(TokenType.IF)
		"else":  return Token.new(TokenType.ELSE)

	if BUILTIN_TYPES.has(id):
		return Token.new(TokenType.BUILTIN_TYPE, BUILTIN_TYPES[id])

	return Token.new(TokenType.IDENTIFIER, id)


# ==============================================================================
# Recursive Descent + Precedence Parser
# ==============================================================================

func _parse_expression() -> ENode:
	var entries: Array[ExpressionEntry] = []

	while true:
		# 1. Parse unary prefix + primary atom
		var expr := _parse_unary_and_atom()
		if expr == null or _error_set:
			return null

		# 2. Parse postfix indexing / member access / method calls
		expr = _parse_postfix(expr)
		if expr == null or _error_set:
			return null

		var entry := ExpressionEntry.new()
		entry.node = expr

		# 3. Check for binary operator or ternary 'if'
		var saved_ofs := _str_ofs
		var tk := _get_token()
		if _error_set:
			return null

		var op := Variant.Operator.OP_MAX
		var is_ternary := false
		match tk.type:
			TokenType.OP_IN \
			or TokenType.OP_EQUAL \
			or TokenType.OP_NOT_EQUAL \
			or TokenType.OP_LESS \
			or TokenType.OP_LESS_EQUAL \
			or TokenType.OP_GREATER \
			or TokenType.OP_GREATER_EQUAL \
			or TokenType.OP_AND \
			or TokenType.OP_OR \
			or TokenType.OP_ADD \
			or TokenType.OP_SUB \
			or TokenType.OP_MUL \
			or TokenType.OP_DIV \
			or TokenType.OP_MOD \
			or TokenType.OP_POWER \
			or TokenType.OP_SHIFT_LEFT \
			or TokenType.OP_SHIFT_RIGHT \
			or TokenType.OP_BIT_AND \
			or TokenType.OP_BIT_OR \
			or TokenType.OP_BIT_XOR: op = _token_to_operator(tk)
			TokenType.OP_NOT:
				# Support `x not in y`
				var next_tk := _get_token()
				if next_tk.type == TokenType.OP_IN:
					op = Variant.Operator.OP_IN
					# Mark with unary negation wrapper after binary reduction
					entry.op = op
					entries.append(entry)
					# Parse RHS and wrap `in` inside `not`
					var rhs := _parse_expression_until_lower_than_in()
					if rhs == null or _error_set:
						return null
					var last = entries.pop_back()
					var in_node := OperatorNode.new(Variant.Operator.OP_IN, [last.node, rhs])
					var not_node := OperatorNode.new(Variant.Operator.OP_NOT, [in_node])
					# Continue loop with `not_node` as current LHS
					var cont_entry := ExpressionEntry.new()
					cont_entry.node = not_node
					saved_ofs = _str_ofs
					tk = _get_token()
					# Re-evaluate next token after `not in`
					_str_ofs = saved_ofs
					entries.append(cont_entry)
					# Re-enter loop cleanly by substituting atom
					return _continue_from_reduced(entries)
				else:
					_set_error("Expected 'in' after 'not' in binary operator position.")
					return null
			TokenType.IF:
				is_ternary = true
			_:
				# End of this expression level
				_str_ofs = saved_ofs
				entries.append(entry)
				break

		entry.op = op
		entry.is_ternary = is_ternary
		entries.append(entry)

		if is_ternary:
			# Reduce everything to the left of `if` first (lowest precedence)
			var true_branch := _reduce_entries(entries)
			var cond_expr := _parse_expression()
			if cond_expr == null or _error_set:
				return null
			var else_tk := _get_token()
			if else_tk.type != TokenType.ELSE:
				_set_error("Expected 'else' in ternary expression.")
				return null
			var false_expr := _parse_expression()
			if false_expr == null or _error_set:
				return null
			return TernaryNode.new(cond_expr, true_branch, false_expr)

	return _reduce_entries(entries)


func _continue_from_reduced(entries: Array[ExpressionEntry]) -> ENode:
	# Helper when `not in` consumed its RHS
	var lhs = entries.pop_back().node
	var saved_ofs := _str_ofs
	var tk := _get_token()
	_str_ofs = saved_ofs
	if tk.type in [
		TokenType.OP_IN, TokenType.OP_EQUAL, TokenType.OP_NOT_EQUAL,
		TokenType.OP_LESS, TokenType.OP_LESS_EQUAL, TokenType.OP_GREATER,
		TokenType.OP_GREATER_EQUAL, TokenType.OP_AND, TokenType.OP_OR,
		TokenType.OP_ADD, TokenType.OP_SUB, TokenType.OP_MUL, TokenType.OP_DIV,
		TokenType.OP_MOD, TokenType.OP_POWER, TokenType.OP_SHIFT_LEFT,
		TokenType.OP_SHIFT_RIGHT, TokenType.OP_BIT_AND, TokenType.OP_BIT_OR,
		TokenType.OP_BIT_XOR, TokenType.IF
	]:
		# Parse remaining chain and attach `lhs` at the front
		var rest := _parse_expression_with_initial(lhs)
		for e in entries:
			pass
		return rest
	entries.append(ExpressionEntry.new())
	entries[-1].node = lhs
	return _reduce_entries(entries)


func _token_to_operator(tk: Token):
	match tk.type:
		TokenType.OP_IN:            return Variant.Operator.OP_IN
		TokenType.OP_EQUAL:         return Variant.Operator.OP_EQUAL
		TokenType.OP_NOT_EQUAL:     return Variant.Operator.OP_NOT_EQUAL
		TokenType.OP_LESS:          return Variant.Operator.OP_LESS
		TokenType.OP_LESS_EQUAL:    return Variant.Operator.OP_LESS_EQUAL
		TokenType.OP_GREATER:       return Variant.Operator.OP_GREATER
		TokenType.OP_GREATER_EQUAL: return Variant.Operator.OP_GREATER_EQUAL
		TokenType.OP_AND:           return Variant.Operator.OP_AND
		TokenType.OP_OR:            return Variant.Operator.OP_OR
		TokenType.OP_ADD:           return Variant.Operator.OP_ADD
		TokenType.OP_SUB:           return Variant.Operator.OP_SUBTRACT
		TokenType.OP_MUL:           return Variant.Operator.OP_MULTIPLY
		TokenType.OP_DIV:           return Variant.Operator.OP_DIVIDE
		TokenType.OP_MOD:           return Variant.Operator.OP_MODULE
		TokenType.OP_POWER:         return Variant.Operator.OP_POWER
		TokenType.OP_SHIFT_LEFT:    return Variant.Operator.OP_SHIFT_LEFT
		TokenType.OP_SHIFT_RIGHT:   return Variant.Operator.OP_SHIFT_RIGHT
		TokenType.OP_BIT_AND:       return Variant.Operator.OP_BIT_AND
		TokenType.OP_BIT_OR:        return Variant.Operator.OP_BIT_OR
		TokenType.OP_BIT_XOR:       return Variant.Operator.OP_BIT_XOR
	return null;

func _parse_expression_with_initial(initial: ENode) -> ENode:
	# Re-injects an already parsed LHS atom into the binary operator loop
	var entries: Array[ExpressionEntry] = []
	var first := true
	while true:
		var expr: ENode
		if first:
			expr = initial
			first = false
		else:
			expr = _parse_unary_and_atom()
			if expr == null or _error_set:
				return null
			expr = _parse_postfix(expr)
			if expr == null or _error_set:
				return null

		var entry := ExpressionEntry.new()
		entry.node = expr

		var saved_ofs := _str_ofs
		var tk := _get_token()
		var op := Variant.Operator.OP_MAX
		var is_ternary := false

		match tk.type:
			TokenType.OP_IN\
			or TokenType.OP_EQUAL\
			or TokenType.OP_NOT_EQUAL\
			or TokenType.OP_LESS\
			or TokenType.OP_LESS_EQUAL\
			or TokenType.OP_GREATER\
			or TokenType.OP_GREATER_EQUAL\
			or TokenType.OP_AND\
			or TokenType.OP_OR\
			or TokenType.OP_ADD\
			or TokenType.OP_SUB\
			or TokenType.OP_MUL\
			or TokenType.OP_DIV\
			or TokenType.OP_MOD\
			or TokenType.OP_POWER\
			or TokenType.OP_SHIFT_LEFT\
			or TokenType.OP_SHIFT_RIGHT\
			or TokenType.OP_BIT_AND\
			or TokenType.OP_BIT_OR\
			or TokenType.OP_BIT_XOR:       op = _token_to_operator(tk)
			TokenType.IF: is_ternary = true
			_:
				_str_ofs = saved_ofs
				entries.append(entry)
				break

		entry.op = op
		entry.is_ternary = is_ternary
		entries.append(entry)

		if is_ternary:
			var true_branch := _reduce_entries(entries)
			var cond_expr := _parse_expression()
			if cond_expr == null or _error_set:
				return null
			if _get_token().type != TokenType.ELSE:
				_set_error("Expected 'else' in ternary expression.")
				return null
			var false_expr := _parse_expression()
			if false_expr == null or _error_set:
				return null
			return TernaryNode.new(cond_expr, true_branch, false_expr)

	return _reduce_entries(entries)


func _parse_expression_until_lower_than_in() -> ENode:
	var rhs := _parse_unary_and_atom()
	if rhs == null or _error_set:
		return null
	return _parse_postfix(rhs)


func _get_op_priority(op: Variant.Operator) -> int:
	match op:
		Variant.Operator.OP_POWER:
			return 10
		Variant.Operator.OP_MULTIPLY, Variant.Operator.OP_DIVIDE, Variant.Operator.OP_MODULE:
			return 9
		Variant.Operator.OP_ADD, Variant.Operator.OP_SUBTRACT:
			return 8
		Variant.Operator.OP_SHIFT_LEFT, Variant.Operator.OP_SHIFT_RIGHT:
			return 7
		Variant.Operator.OP_BIT_AND:
			return 6
		Variant.Operator.OP_BIT_XOR:
			return 5
		Variant.Operator.OP_BIT_OR:
			return 4
		Variant.Operator.OP_LESS, Variant.Operator.OP_LESS_EQUAL, Variant.Operator.OP_GREATER, Variant.Operator.OP_GREATER_EQUAL, \
		Variant.Operator.OP_EQUAL, Variant.Operator.OP_NOT_EQUAL, Variant.Operator.OP_IN:
			return 3
		Variant.Operator.OP_AND:
			return 2
		Variant.Operator.OP_OR:
			return 1
		_:
			return 0


func _reduce_entries(entries: Array[ExpressionEntry]) -> ENode:
	while entries.size() > 1:
		var best_idx := 0
		var best_prio := _get_op_priority(entries[0].op)

		for i in range(1, entries.size() - 1):
			var prio := _get_op_priority(entries[i].op)
			# Power (**) is right-associative; others are left-associative
			if prio > best_prio or (prio == best_prio and entries[i].op == Variant.Operator.OP_POWER):
				best_prio = prio
				best_idx = i

		var left := entries[best_idx]
		var right := entries[best_idx + 1]
		var combined := OperatorNode.new(left.op, [left.node, right.node])

		left.node = combined
		left.op = right.op
		entries.remove_at(best_idx + 1)

	return entries[0].node


func _parse_unary_and_atom() -> ENode:
	var tk := _get_token()
	if _error_set:
		return null

	match tk.type:
		TokenType.OP_ADD:
			var sub := _parse_unary_and_atom()
			return OperatorNode.new(Variant.Operator.OP_POSITIVE, [sub]) if sub else null
		TokenType.OP_SUB:
			var sub := _parse_unary_and_atom()
			return OperatorNode.new(Variant.Operator.OP_NEGATE, [sub]) if sub else null
		TokenType.OP_NOT:
			var sub := _parse_unary_and_atom()
			return OperatorNode.new(Variant.Operator.OP_NOT, [sub]) if sub else null
		TokenType.OP_BIT_INVERT:
			var sub := _parse_unary_and_atom()
			return OperatorNode.new(Variant.Operator.OP_BIT_NEGATE, [sub]) if sub else null

		TokenType.PARENTHESIS_OPEN:
			var inner := _parse_expression()
			if inner == null or _error_set:
				return null
			if _get_token().type != TokenType.PARENTHESIS_CLOSE:
				_set_error("Expected ')'")
				return null
			return inner

		TokenType.BRACKET_OPEN:
			var elements: Array[ENode] = []
			var saved := _str_ofs
			if _get_token().type != TokenType.BRACKET_CLOSE:
				_str_ofs = saved
				while true:
					var elem := _parse_expression()
					if elem == null or _error_set:
						return null
					elements.append(elem)
					var sep := _get_token()
					if sep.type == TokenType.BRACKET_CLOSE:
						break
					elif sep.type != TokenType.COMMA:
						_set_error("Expected ',' or ']'")
						return null
					# Allow trailing comma before ']'
					saved = _str_ofs
					if _get_token().type == TokenType.BRACKET_CLOSE:
						break
					_str_ofs = saved
			return ArrayNode.new(elements)

		TokenType.CURLY_BRACKET_OPEN:
			var pairs: Array[ENode] = []
			var saved := _str_ofs
			if _get_token().type != TokenType.CURLY_BRACKET_CLOSE:
				_str_ofs = saved
				while true:
					var key := _parse_expression()
					if key == null or _error_set:
						return null
					if _get_token().type != TokenType.COLON:
						_set_error("Expected ':' in dictionary")
						return null
					var val := _parse_expression()
					if val == null or _error_set:
						return null
					pairs.append(key)
					pairs.append(val)

					var sep := _get_token()
					if sep.type == TokenType.CURLY_BRACKET_CLOSE:
						break
					elif sep.type != TokenType.COMMA:
						_set_error("Expected ',' or '}'")
						return null
					saved = _str_ofs
					if _get_token().type == TokenType.CURLY_BRACKET_CLOSE:
						break
					_str_ofs = saved
			return DictionaryNode.new(pairs)

		TokenType.BUILTIN_TYPE:
			var vtype: Variant.Type = tk.value
			var saved := _str_ofs
			var next_tk := _get_token()
			if next_tk.type == TokenType.PARENTHESIS_OPEN:
				var args := _parse_argument_list()
				if _error_set:
					return null
				return ConstructNode.new(vtype, args)
			elif next_tk.type == TokenType.PERIOD:
				# Handle built-in type constants like Vector2.ZERO or Color.RED
				var id_tk := _get_token()
				if id_tk.type != TokenType.IDENTIFIER:
					_set_error("Expected identifier after '.'")
					return null
				var default_val: Variant = type_convert(null, vtype)
				return NamedIndexNode.new(ConstantNode.new(default_val), StringName(id_tk.value))
			else:
				_set_error("Expected '(' or '.' after built-in type.")
				return null

		TokenType.SELF:
			return SelfNode.new()

		TokenType.CONSTANT:
			return ConstantNode.new(tk.value)

		TokenType.IDENTIFIER:
			var ident: String = tk.value
			var saved := _str_ofs
			var next_tk := _get_token()
			if next_tk.type == TokenType.PARENTHESIS_OPEN:
				if _input_names.has(ident):
					_set_error("Cannot call input variable '%s'." % ident)
					return null
				var args := _parse_argument_list()
				if _error_set:
					return null
				if _builtin_funcs.has(ident):
					return BuiltinFuncNode.new(StringName(ident), args)
				return CallNode.new(SelfNode.new(), StringName(ident), args)
			else:
				_str_ofs = saved
				var input_idx := _input_names.find(ident)
				if input_idx != -1:
					return InputNode.new(input_idx)
				return NamedIndexNode.new(SelfNode.new(), StringName(ident))

		_:
			_set_error("Unexpected token in expression.")
			return null


func _parse_postfix(base: ENode) -> ENode:
	var current := base
	while true:
		var saved := _str_ofs
		var tk := _get_token()
		if _error_set:
			return null

		if tk.type == TokenType.BRACKET_OPEN:
			var index_expr := _parse_expression()
			if index_expr == null or _error_set:
				return null
			if _get_token().type != TokenType.BRACKET_CLOSE:
				_set_error("Expected ']'")
				return null
			current = IndexNode.new(current, index_expr)

		elif tk.type == TokenType.PERIOD:
			var id_tk := _get_token()
			if id_tk.type != TokenType.IDENTIFIER:
				_set_error("Expected identifier after '.'")
				return null
			var member_name := StringName(id_tk.value)
			var after_id := _str_ofs
			if _get_token().type == TokenType.PARENTHESIS_OPEN:
				var args := _parse_argument_list()
				if _error_set:
					return null
				current = CallNode.new(current, member_name, args)
			else:
				_str_ofs = after_id
				current = NamedIndexNode.new(current, member_name)
		else:
			_str_ofs = saved
			break

	return current


func _parse_argument_list() -> Array[ENode]:
	var args: Array[ENode] = []
	var saved := _str_ofs
	if _get_token().type == TokenType.PARENTHESIS_CLOSE:
		return args
	_str_ofs = saved

	while true:
		var arg := _parse_expression()
		if arg == null or _error_set:
			return []
		args.append(arg)
		var sep := _get_token()
		if sep.type == TokenType.PARENTHESIS_CLOSE:
			break
		elif sep.type != TokenType.COMMA:
			_set_error("Expected ',' or ')'")
			return []
	return args


# ==============================================================================
# AST Evaluator
# ==============================================================================

func _execute(
	node: ENode,
	inputs: Array,
	base_instance: Object,
	const_calls_only: bool
) -> Variant:
	if _execution_error:
		return null

	if node is InputNode:
		var idx: int = node.index
		if idx < 0 or idx >= inputs.size():
			_set_exec_error("Input index %d out of bounds." % idx)
			return null
		return inputs[idx]

	elif node is ConstantNode:
		return node.value

	elif node is SelfNode:
		if base_instance == null:
			_set_exec_error("self can't be used because instance is null (not passed)")
			return null
		return base_instance

	elif node is OperatorNode:
		var op: Variant.Operator = node.op
		if node.nodes.size() == 1:
			var a: Variant = _execute(node.nodes[0], inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			return _eval_unary(op, a)
		else:
			var a: Variant = _execute(node.nodes[0], inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			# Short-circuit boolean AND / OR
			if op == Variant.Operator.OP_AND and not bool(a):
				return false
			if op == Variant.Operator.OP_OR and bool(a):
				return true

			var b: Variant = _execute(node.nodes[1], inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			return _eval_binary(op, a, b)

	elif node is IndexNode:
		var base: Variant = _execute(node.base, inputs, base_instance, const_calls_only)
		if _execution_error:
			return null
		var idx: Variant = _execute(node.index, inputs, base_instance, const_calls_only)
		if _execution_error:
			return null
		if base == null:
			_set_exec_error("Cannot index null value.")
			return null
		return base[idx]

	elif node is NamedIndexNode:
		var base: Variant = _execute(node.base, inputs, base_instance, const_calls_only)
		if _execution_error:
			return null
		if base == null:
			_set_exec_error("Cannot access member '%s' on null." % node.name)
			return null
		if base is Object:
			if not (node.name in base):
				_set_exec_error("Invalid named index '%s' for base type Object" % node.name)
				return null
			return base.get(node.name)
		elif base is Dictionary:
			if not base.has(node.name) and not base.has(String(node.name)):
				_set_exec_error("Key '%s' not found in Dictionary." % node.name)
				return null
			return base[node.name] if base.has(node.name) else base[String(node.name)]
		else:
			return base[node.name]

	elif node is CallNode:
		var base: Variant = _execute(node.base, inputs, base_instance, const_calls_only)
		if _execution_error:
			return null
		if base == null:
			_set_exec_error("Cannot call method '%s' on null." % node.method)
			return null

		var args: Array = []
		for arg_node in node.arguments:
			var val: Variant = _execute(arg_node, inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			args.append(val)

		if base is Object:
			if not base.has_method(node.method):
				_set_exec_error("Method '%s' not found on object." % node.method)
				return null
			if const_calls_only:
				_set_exec_error("Object method calls are disabled when const_calls_only is true.")
				return null
			return base.callv(node.method, args)
		else:
			var c := Callable(base, node.method)
			if not c.is_valid():
				_set_exec_error("Invalid method '%s' on Variant." % node.method)
				return null
			return c.callv(args)

	elif node is BuiltinFuncNode:
		var args: Array = []
		for arg_node in node.arguments:
			var val: Variant = _execute(arg_node, inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			args.append(val)

		var fn: Callable = _builtin_funcs.get(String(node.func_name), Callable())
		if not fn.is_valid():
			_set_exec_error("Unknown built-in function '%s'." % node.func_name)
			return null
		return fn.callv(args)

	elif node is ConstructNode:
		var args: Array = []
		for arg_node in node.arguments:
			var val: Variant = _execute(arg_node, inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			args.append(val)
		return _construct_variant(node.data_type, args)

	elif node is ArrayNode:
		var arr: Array = []
		for item_node in node.array:
			var val: Variant = _execute(item_node, inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			arr.append(val)
		return arr

	elif node is DictionaryNode:
		var dict: Dictionary = {}
		for i in range(0, node.dict.size(), 2):
			var k: Variant = _execute(node.dict[i], inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			var v: Variant = _execute(node.dict[i + 1], inputs, base_instance, const_calls_only)
			if _execution_error:
				return null
			dict[k] = v
		return dict

	elif node is TernaryNode:
		var cond: Variant = _execute(node.condition, inputs, base_instance, const_calls_only)
		if _execution_error:
			return null
		if bool(cond):
			return _execute(node.true_expr, inputs, base_instance, const_calls_only)
		else:
			return _execute(node.false_expr, inputs, base_instance, const_calls_only)

	return null


# ==============================================================================
# Operator & Constructor Helpers
# ==============================================================================

func _eval_unary(op: Variant.Operator, a: Variant) -> Variant:
	match op:
		Variant.Operator.OP_POSITIVE: return +a
		Variant.Operator.OP_NEGATE: return -a
		Variant.Operator.OP_NOT: return not bool(a)
		Variant.Operator.OP_BIT_NEGATE: return ~int(a)
	_set_exec_error("Unsupported unary operator.")
	return null


func _eval_binary(op: Variant.Operator, a: Variant, b: Variant) -> Variant:
	match op:
		Variant.Operator.OP_EQUAL: return a == b
		Variant.Operator.OP_NOT_EQUAL: return a != b
		Variant.Operator.OP_LESS: return a < b
		Variant.Operator.OP_LESS_EQUAL: return a <= b
		Variant.Operator.OP_GREATER: return a > b
		Variant.Operator.OP_GREATER_EQUAL: return a >= b
		Variant.Operator.OP_ADD: return a + b
		Variant.Operator.OP_SUBTRACT: return a - b
		Variant.Operator.OP_MULTIPLY: return a * b
		Variant.Operator.OP_DIVIDE:
			if (b is int or b is float) and b == 0:
				_set_exec_error("Division by zero.")
				return null
			return a / b
		Variant.Operator.OP_MODULE:
			if (b is int or b is float) and b == 0:
				_set_exec_error("Modulo by zero.")
				return null
			return a % b
		Variant.Operator.OP_POWER: return a ** b
		Variant.Operator.OP_SHIFT_LEFT: return int(a) << int(b)
		Variant.Operator.OP_SHIFT_RIGHT: return int(a) >> int(b)
		Variant.Operator.OP_BIT_AND: return int(a) & int(b)
		Variant.Operator.OP_BIT_OR: return int(a) | int(b)
		Variant.Operator.OP_BIT_XOR: return int(a) ^ int(b)
		Variant.Operator.OP_AND: return bool(a) and bool(b)
		Variant.Operator.OP_OR: return bool(a) or bool(b)
		Variant.Operator.OP_IN: return a in b
	_set_exec_error("Unsupported binary operator.")
	return null


func _construct_variant(vtype: Variant.Type, args: Array) -> Variant:
	if args.is_empty():
		return type_convert(null, vtype)
	if args.size() == 1:
		return type_convert(args[0], vtype)

	match vtype:
		TYPE_VECTOR2:
			return Vector2(args[0], args[1])
		TYPE_VECTOR2I:
			return Vector2i(args[0], args[1])
		TYPE_VECTOR3:
			return Vector3(args[0], args[1], args[2])
		TYPE_VECTOR3I:
			return Vector3i(args[0], args[1], args[2])
		TYPE_VECTOR4:
			return Vector4(args[0], args[1], args[2], args[3])
		TYPE_VECTOR4I:
			return Vector4i(args[0], args[1], args[2], args[3])
		TYPE_RECT2:
			if args.size() == 2:
				return Rect2(args[0], args[1])
			return Rect2(args[0], args[1], args[2], args[3])
		TYPE_RECT2I:
			if args.size() == 2:
				return Rect2i(args[0], args[1])
			return Rect2i(args[0], args[1], args[2], args[3])
		TYPE_COLOR:
			if args.size() == 2:
				return Color(args[0], args[1])
			elif args.size() == 3:
				return Color(args[0], args[1], args[2])
			return Color(args[0], args[1], args[2], args[3])
		TYPE_QUATERNION:
			if args.size() == 2:
				return Quaternion(args[0], args[1])
			return Quaternion(args[0], args[1], args[2], args[3])
		TYPE_PLANE:
			if args.size() == 2:
				return Plane(args[0], args[1])
			elif args.size() == 3:
				return Plane(args[0], args[1], args[2])
			return Plane(args[0], args[1], args[2], args[3])
		TYPE_AABB:
			return AABB(args[0], args[1])
		TYPE_BASIS:
			if args.size() == 2:
				return Basis(args[0], args[1])
			return Basis(args[0], args[1], args[2])
		TYPE_TRANSFORM2D:
			if args.size() == 2:
				return Transform2D(args[0], args[1])
			return Transform2D(args[0], args[1], args[2])
		TYPE_TRANSFORM3D:
			if args.size() == 2:
				return Transform3D(args[0], args[1])
			return Transform3D(args[0], args[1], args[2], args[3])

	_set_exec_error("Unsupported constructor signature for type %s." % type_string(vtype))
	return null


# ==============================================================================
# Built-in Utility Functions Registry
# ==============================================================================

static func _ensure_builtin_funcs() -> void:
	if not _builtin_funcs.is_empty():
		return
	_builtin_funcs = {
		"sin": func(x): return sin(x),
		"cos": func(x): return cos(x),
		"tan": func(x): return tan(x),
		"sinh": func(x): return sinh(x),
		"cosh": func(x): return cosh(x),
		"tanh": func(x): return tanh(x),
		"asin": func(x): return asin(x),
		"acos": func(x): return acos(x),
		"atan": func(x): return atan(x),
		"atan2": func(y, x): return atan2(y, x),
		"asinh": func(x): return asinh(x),
		"acosh": func(x): return acosh(x),
		"atanh": func(x): return atanh(x),
		"sqrt": func(x): return sqrt(x),
		"fmod": func(x, y): return fmod(x, y),
		"fposmod": func(x, y): return fposmod(x, y),
		"posmod": func(x, y): return posmod(x, y),
		"floor": func(x): return floor(x),
		"ceil": func(x): return ceil(x),
		"round": func(x): return round(x),
		"abs": func(x): return abs(x),
		"sign": func(x): return sign(x),
		"pow": func(b, e): return pow(b, e),
		"log": func(x): return log(x),
		"exp": func(x): return exp(x),
		"is_nan": func(x): return is_nan(x),
		"is_inf": func(x): return is_inf(x),
		"is_equal_approx": func(a, b): return is_equal_approx(a, b),
		"is_zero_approx": func(x): return is_zero_approx(x),
		"ease": func(x, c): return ease(x, c),
		"step_decimals": func(x): return step_decimals(x),
		"snapped": func(x, s): return snapped(x, s),
		"lerp": func(a, b, t): return lerp(a, b, t),
		"cubic_interpolate": func(a, b, pre, post, t): return cubic_interpolate(a, b, pre, post, t),
		"lerp_angle": func(a, b, t): return lerp_angle(a, b, t),
		"inverse_lerp": func(a, b, v): return inverse_lerp(a, b, v),
		"remap": func(v, istart, istop, ostart, ostop): return remap(v, istart, istop, ostart, ostop),
		"smoothstep": func(a, b, x): return smoothstep(a, b, x),
		"move_toward": func(a, b, d): return move_toward(a, b, d),
		"deg_to_rad": func(d): return deg_to_rad(d),
		"rad_to_deg": func(r): return rad_to_deg(r),
		"linear_to_db": func(v): return linear_to_db(v),
		"db_to_linear": func(db): return db_to_linear(db),
		"wrap": func(v, mn, mx): return wrap(v, mn, mx),
		"wrapf": func(v, mn, mx): return wrapf(v, mn, mx),
		"wrapi": func(v, mn, mx): return wrapi(v, mn, mx),
		"max": func(a, b): return max(a, b),
		"min": func(a, b): return min(a, b),
		"clamp": func(v, mn, mx): return clamp(v, mn, mx),
		"nearest_po2": func(v): return nearest_po2(v),
		"pingpong": func(v, l): return pingpong(v, l),
		"randi": func(): return randi(),
		"randf": func(): return randf(),
		"randi_range": func(a, b): return randi_range(a, b),
		"randf_range": func(a, b): return randf_range(a, b),
		"seed": func(s): seed(s),
		"str": func(v): return str(v),
		"printgd": func(v): print(v),
		"typeof": func(v): return typeof(v),
		"type_string": func(t): return type_string(t),
		"str_to_var": func(s): return str_to_var(s),
		"var_to_str": func(v): return var_to_str(v),
		"hash": func(v): return hash(v),
		"len": func(v): return len(v),
	}
