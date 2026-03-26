package parser

import "core:strconv"
import "core:strings"

Int :: distinct int
Bool :: distinct bool
Identifier :: distinct string

Expr :: union {
	Int,
	Bool,
	Identifier,
	[]Expr,
}

AST :: struct {
	exprs: []Expr,
}

delete_ast :: proc(ast: AST) {
	for expr in ast.exprs {
		delete_expression(expr)
	}

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
	p := Parser{tokens, 0}
	exprs := make([dynamic]Expr)

	defer if err != nil {
		delete_tokens(tokens)
		delete(exprs)
	}

	for p.cursor < len(p.tokens) {
		expr := parse_expression(&p) or_return
		append(&exprs, expr)
	}

	return AST{exprs = exprs[:]}, nil
}

parse_expression :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	tok := p.tokens[p.cursor]
	#partial switch tok.type {
	case .Bool, .Int:
		return parse_literal(p)
	case .Identifier:
		return parse_identifier(p)
	case .Left_Paren:
		return parse_list(p)
	}

	return Expr{}, unexpected_token(tok)
}

parse_list :: proc(p: ^Parser) -> (expr: Expr, err: Error) {
	p.cursor += 1 // Left_Paren

	items := make([dynamic]Expr)
	tok := p.tokens[p.cursor]
	for p.cursor < len(p.tokens) {
		tok = p.tokens[p.cursor]
		if tok.type == .Right_Paren {
			break
		}

		expr = parse_expression(p) or_return
		append(&items, expr)
	}

	if tok.type != .Right_Paren {
		return Expr{}, Missing_Paren{tok.line, tok.column}
	}

	p.cursor += 1 // Right_Paren
	return items[:], nil
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

	return Identifier(strings.clone(tok.value)), nil
}


//-- Tree node equality check function

is_expression_equal :: proc(a, b: Expr) -> bool {
	if typeid_of(type_of(a)) != typeid_of(type_of(b)) {
		return false
	}

	// TODO: compare []Expr
	switch _ in a {
	case Identifier:
		return a.(Identifier) == b.(Identifier)
	case Int:
		return a.(Int) == b.(Int)
	case Bool:
		return a.(Bool) == b.(Bool)
	case []Expr:
		list_a := a.([]Expr)
		list_b := b.([]Expr)

		if len(list_a) != len(list_b) {
			return false
		}

		accumulator := true
		for e, i in list_a {
			accumulator &= is_expression_equal(e, list_b[i])
		}

		return accumulator
	}

	return true
}

// destructors
delete_expression :: proc(expr: Expr) {
	#partial switch _ in expr {
	case Identifier:
		delete(string(expr.(Identifier)))
	case []Expr:
		list := expr.([]Expr)
		for e in list {
			delete_expression(e)
		}
		delete(list)
	}
}
