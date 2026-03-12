package parser

import "core:strconv"
import "core:strings"

Int :: distinct int
Bool :: distinct bool

Function_Call :: struct {
	name: string,
	args: []Expr,
}


Expr :: union {
	Int,
	Bool,
	Function_Call,
}

Arg :: enum {
	PosArg,
	VarArg,
}

Function :: struct {
	args: map[string]Arg,
	body: Expr,
}


Definition :: struct {
	name:  string,
	value: union {
		Int,
		Bool,
		Function,
	},
}


AST :: struct {
	defs:  map[string]Definition,
	exprs: []Expr,
}

delete_ast :: proc(ast: AST) {
	for expr in ast.exprs {
		delete_expression(expr)
	}

	delete(ast.defs)
	delete(ast.exprs)
}

Parser :: struct {
	tokens: []Token,
	cursor: int,
}

parse :: proc {
	parse_string,
	parse_tokens,
}

parse_string :: proc(code: string) -> (ast: AST, err: Error) {
	lexer := lexer_from_string(code)
	defer delete(lexer.buffer)

	tokens := tokenize(&lexer) or_return
	return parse_tokens(tokens)
}

parse_tokens :: proc(tokens: []Token) -> (ast: AST, err: Error) {
	defer delete_tokens(tokens)
	p := Parser {
		tokens = tokens,
		cursor = 0,
	}

	exprs := make([dynamic]Expr)
	defer if err != nil {
		delete_tokens(tokens)
		for expr in exprs {
			delete_expression(expr)
		}
		delete(exprs)
	}

	for p.cursor < len(p.tokens) {
		tok := p.tokens[p.cursor]

		#partial switch tok.type {
		case .Bool, .Int:
			lit := parse_literal(&p) or_return
			append(&exprs, lit)
		case .Left_Paren:
			// TODO: do variable, function definition
			expr := parse_expression(&p) or_return
			append(&exprs, expr)
		}
	}

	return AST{exprs = exprs[:]}, nil
}

parse_expression :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	tok := p.tokens[p.cursor]
	#partial switch tok.type {
	case .Bool, .Int:
		return parse_literal(p)
	case .Left_Paren:
		func := parse_function_call(p) or_return

		tok = p.tokens[p.cursor]
		if tok.type != .Right_Paren {
			return Expr{}, syntax_errorf(tok, "missing closing paren")
		}

		p.cursor += 1
		return func, nil
	}

	return Expr{}, unexpected_token(tok)
}


parse_literal :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	tok := p.tokens[p.cursor]
	p.cursor += 1

	if tok.type == .Bool {
		res, _ := strconv.parse_bool(tok.value)
		return Bool(res), nil
	}

	if tok.type == .Int {
		res, _ := strconv.parse_int(tok.value)
		return Int(res), nil
	}

	return Expr{}, unexpected_token(tok)
}


parse_function_call :: proc(p: ^Parser) -> (fn: Function_Call, err: Error) {
	p.cursor += 1 // Left_Paren
	id := p.tokens[p.cursor].value

	p.cursor += 1 // Identifier
	args := make([dynamic]Expr)

	for p.cursor < len(p.tokens) {
		tok := p.tokens[p.cursor]
		if tok.type == .Right_Paren {
			break
		}

		expr := parse_expression(p) or_return
		append(&args, expr)
	}

	return Function_Call{strings.clone(id), args[:]}, nil
}

//-- Tree node equality check function

is_expression_equal :: proc(a, b: Expr) -> bool {
	if typeid_of(type_of(a)) != typeid_of(type_of(b)) {
		return false
	}

	switch _ in a {
	case Function_Call:
		return is_function_call_equal(a.(Function_Call), b.(Function_Call))
	case Int:
		return a.(Int) == b.(Int)
	case Bool:
		return a.(Bool) == b.(Bool)
	}

	return true
}

is_function_call_equal :: proc(a, b: Function_Call) -> bool {
	if a.name != b.name {
		return false
	}

	if len(a.args) != len(b.args) {
		return false
	}

	for _, i in a.args {
		if !is_expression_equal(a.args[i], b.args[i]) {
			return false
		}
	}

	return true
}

// destructors
delete_expression :: proc(expr: Expr) {
	#partial switch _ in expr {
	case Function_Call:
		func := expr.(Function_Call)
		for arg in func.args {
			delete_expression(arg)
		}
		delete(func.name)
		delete(func.args)
	}
}
