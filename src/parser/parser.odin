package parser

import "core:strconv"
import "core:strings"

Int :: distinct int
Bool :: distinct bool

Identifier :: struct {
	name: string,
}

Function_Call :: struct {
	name: string,
	args: []Expr,
}


Expr :: union #no_nil {
	Int,
	Bool,
	Identifier,
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
		Expr,
		Function,
	},
}

delete_definition :: proc(def: Definition) {
	delete(def.name)
	#partial switch _ in def.value {
	case Function:
		fn := def.value.(Function)
		delete(fn.args)
		delete_expression(fn.body)
	}
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
	defer if err == nil {
		// FIXME: handle on error cleanup
		// if error happens keep tokens for error reporting
		// but the user needed to release the tokens somehow
		delete_tokens(tokens)
	}
	return parse_tokens(tokens)
}

parse_tokens :: proc(tokens: []Token) -> (ast: AST, err: Error) {
	p := Parser {
		tokens = tokens,
		cursor = 0,
	}

	defs := make(map[string]Definition)
	exprs := make([dynamic]Expr)
	defer if err != nil {
		delete_tokens(tokens)
		for expr in exprs {
			delete_expression(expr)
		}
		delete(exprs)

		for _, definition in defs {
			delete_definition(definition)
		}
		delete(defs)
	}


	for p.cursor < len(p.tokens) {
		tok := p.tokens[p.cursor]

		#partial switch tok.type {
		case .Bool, .Int:
			lit := parse_literal(&p) or_return
			append(&exprs, lit)
		case .Left_Paren:
			peek := p.tokens[p.cursor + 1]
			if peek.type == .Keyword {
				def := parse_definition(&p) or_return
				defs[def.name] = def
			} else {
				expr := parse_expression(&p) or_return
				append(&exprs, expr)
			}
		}
	}

	return AST{exprs = exprs[:], defs = defs}, nil
}

parse_definition :: proc(p: ^Parser) -> (def: Definition, err: Error) {
	p.cursor += 1 // consume left paren
	keyword := p.tokens[p.cursor]

	p.cursor += 1 // consume keyword
	identifier := p.tokens[p.cursor]

	if identifier.type != .Identifier {
		// FIXME: Could return better error
		err = unexpected_token(identifier)
		return
	}

	p.cursor += 1 // consume identifier
	if keyword.value == "defn" {
		// TODO: parse function
		// definition := Definition{ identifier, nil}, nil
	}

	if keyword.value == "def" {
		def.name = strings.clone(identifier.value)
		def.value = parse_expression(p) or_return

		end_tok := p.tokens[p.cursor]
		if end_tok.type != .Right_Paren {
			err = Missing_Paren{end_tok.line, end_tok.column}
			return
		}

		p.cursor += 1 // consume paren
		return def, nil
	}

	err = unexpected_token(p.tokens[p.cursor])
	return
}

parse_expression :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	tok := p.tokens[p.cursor]
	#partial switch tok.type {
	case .Bool, .Int:
		return parse_literal(p)
	case .Identifier:
		return parse_identifier(p)
	case .Left_Paren:
		func := parse_function_call(p) or_return
		has_token := len(p.tokens) > p.cursor

		last_token := p.tokens[len(p.tokens) - 1]
		missing_paren := Missing_Paren{last_token.line, last_token.column}
		if !has_token {
			return Expr{}, missing_paren
		}

		tok = p.tokens[p.cursor]
		if tok.type != .Right_Paren {
			return Expr{}, missing_paren
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

	tok.value = "BAR"
	return Expr{}, unexpected_token(tok)
}

parse_identifier :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	tok := p.tokens[p.cursor]
	p.cursor += 1

	return Identifier{strings.clone(tok.value)}, nil
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
	case Identifier:
		return a.(Identifier).name == b.(Identifier).name
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
