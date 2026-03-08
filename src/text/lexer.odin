package text

import "core:unicode/utf8"

TType :: enum {
	Left_Paren,
	Right_Paren,
	Identifier,
	Number,
}

TType_String :: #sparse[TType]string {
	.Left_Paren  = "Left_Paren",
	.Right_Paren = "Right_Paren",
	.Identifier  = "Identifier",
	.Number      = "Number",
}

Token :: struct {
	type:  TType,
	value: string,
}


Lexer :: struct {
	source: string,
	buffer: [dynamic]rune,
	cursor: uint,
}

skip :: proc(lex: ^Lexer) -> rune {
	lex.cursor += 1
	return get_current_char(lex^)
}

next :: proc(lex: ^Lexer) -> rune {
	append(&lex.buffer, get_current_char(lex^))
	lex.cursor += 1
	return get_current_char(lex^)
}

get_current_char :: proc(lex: Lexer) -> rune {
	can_index := lex.cursor < len(lex.source)
	return rune(lex.source[lex.cursor]) if can_index else utf8.RUNE_EOF
}

consume :: proc(lex: ^Lexer, ttype: TType) -> Token {
	defer clear(&lex.buffer)
	return Token{ttype, utf8.runes_to_string(lex.buffer[:])}
}

string_lexer :: proc(source_code: string) -> Lexer {
	return Lexer{source = source_code, buffer = make([dynamic]rune, 0), cursor = 0}
}

expect :: proc(lex: ^Lexer, expected_chars: ..rune) -> bool {
	r := get_current_char(lex^)
	for char in expected_chars {
		if r == char {
			return true
		}
	}

	return false
}

Syntax_Error :: struct {
	reason:   string,
	// TODO: make this into (col, row) when file lexer is implemented
	position: uint,
}

Error :: union {
	Syntax_Error,
}


tokenize :: proc(lex: ^Lexer) -> ([]Token, Error) {
	tokens: [dynamic]Token

	for get_current_char(lex^) != utf8.RUNE_EOF {
		skip_whitespace(lex)
		tok, err := next_token(lex)

		if err != nil {
			return nil, err
		}

		append(&tokens, tok)
	}

	return tokens[:], nil
}

skip_whitespace :: proc(lex: ^Lexer) {
	char := get_current_char(lex^)
	for char != utf8.RUNE_EOF {
		if char == ' ' || char == '\n' || char == '\r' {
			char = skip(lex)
		}
		return
	}
}

next_token :: proc(lex: ^Lexer) -> (Token, Error) {
	char := get_current_char(lex^)

	if char == '(' || char == ')' {
		ttype: TType = .Left_Paren if char == '(' else .Right_Paren
		next(lex)
		return consume(lex, ttype), nil
	}

	if is_digit(char) {
		tok := parse_digit(lex)
		if !expect(lex, ' ', '(', ')') {
			return Token{}, Syntax_Error{"unexpected char", lex.cursor}
		}
		return tok, nil
	}

	if is_alphabet(char) || is_valid_symbol(char) {
		return parse_identifier(lex), nil
	}

	return Token{}, nil
}

parse_digit :: proc(lex: ^Lexer) -> Token {
	char := next(lex)
	for char != utf8.RUNE_EOF {
		if is_digit(char) {
			char = next(lex)
			continue
		}
		break
	}

	return consume(lex, .Number)
}

parse_identifier :: proc(lex: ^Lexer) -> Token {
	char := next(lex)
	for char != utf8.RUNE_EOF {
		if is_alphabet(char) || is_valid_symbol(char) || is_digit(char) {
			char = next(lex)
			continue
		}

		break
	}

	return consume(lex, .Identifier)
}
