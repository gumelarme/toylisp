package parser

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

Syntax_Error :: struct {
	line: uint,
	col:  uint,
}

Missing_Paren :: distinct Syntax_Error

Error :: union {
	Syntax_Error,
	Missing_Paren,
}


TType :: enum {
	None,
	Left_Paren,
	Right_Paren,
	Identifier,
	Int,
	Bool,
	// we dont have macros here, so def & defn is a keyword
	Keyword,
}

Token :: struct {
	type:   TType,
	value:  string,
	line:   uint,
	column: uint,
}

delete_token :: proc(tok: Token) {
	delete(tok.value)
}

delete_tokens :: proc(tokens: []Token) {
	for tok in tokens {
		delete_token(tok)
	}
	delete(tokens)
}

token_to_string :: proc(tok: Token) -> string {
	if tok.type == .Int || tok.type == .Identifier {
		return fmt.tprintf("<%d:%d %v '%s'>", tok.line, tok.column, tok.type, tok.value)
	} else {
		return fmt.tprintf("<%d:%d %v>", tok.line, tok.column, tok.type)
	}
}


Lexer :: struct {
	source: string,
	buffer: [dynamic]rune,
	cursor: uint,
	// for error info
	line:   uint,
	column: uint,
}

skip :: proc(lex: ^Lexer) -> rune {
	advance(lex)
	return get_current_char(lex^)
}

next :: proc(lex: ^Lexer) -> rune {
	append(&lex.buffer, get_current_char(lex^))
	advance(lex)
	return get_current_char(lex^)
}

advance :: proc(lex: ^Lexer) {
	lex.cursor += 1
	lex.column += 1
}

get_current_char :: proc(lex: Lexer) -> rune {
	can_index := lex.cursor < len(lex.source)
	return rune(lex.source[lex.cursor]) if can_index else utf8.RUNE_EOF
}

consume :: proc(lex: ^Lexer, ttype: TType) -> Token {
	defer clear(&lex.buffer)

	col := lex.column - 1 // move back after advanced
	if length := len(lex.buffer); length > 1 {
		// point to the start of the id
		col -= uint(length - 1)
	}

	return Token{ttype, utf8.runes_to_string(lex.buffer[:]), lex.line, col}
}

lexer_from_file :: proc(filename: string) -> (lex: Lexer, err: os.Error) {
	data := os.read_entire_file_from_filename_or_err(filename) or_return
	return lexer_from_string(string(data)), nil
}

lexer_from_string :: proc(source_code: string) -> Lexer {
	return Lexer {
		source = strings.trim_space(source_code),
		buffer = make([dynamic]rune, 0),
		cursor = 0,
		line = 1,
		column = 1,
	}
}

expect_any :: proc(lex: ^Lexer, expected_chars: ..rune) -> bool {
	r := get_current_char(lex^)
	for char in expected_chars {
		if r == char {
			return true
		}
	}

	return false
}


tokenize :: proc(lex: ^Lexer) -> ([]Token, Error) {
	tokens := make([dynamic]Token)

	for get_current_char(lex^) != utf8.RUNE_EOF {
		skip_whitespace(lex)
		tok, err := next_token(lex)

		if err != nil {
			defer {
				for t in tokens {
					delete_token(t)
				}
				delete(tokens)
			}
			return nil, err
		}

		append(&tokens, tok)
	}

	// move back one char after EOF
	lex.column -= 1
	return tokens[:], nil
}

skip_whitespace :: proc(lex: ^Lexer) {
	char := get_current_char(lex^)
	for char != utf8.RUNE_EOF {
		if char == ' ' || char == '\t' {
			char = skip(lex)
			continue
		}

		if char == '\n' || char == '\r' {
			char = skip(lex)
			lex.line += 1
			lex.column = 1
			continue
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
		tok := lex_digit(lex)
		// EOF to propagate the handling of `missing paren` error to parser
		if !expect_any(lex, '\r', '\n', ' ', '\t', '(', ')', utf8.RUNE_EOF) {
			defer delete_token(tok)
			return Token{}, unexpected_token(tok)
		}
		return tok, nil
	}

	if is_alphabet(char) || is_valid_symbol(char) {
		return lex_identifier(lex), nil
	}

	return Token{}, nil
}

lex_digit :: proc(lex: ^Lexer) -> Token {
	char := next(lex)
	for char != utf8.RUNE_EOF {
		if is_digit(char) {
			char = next(lex)
			continue
		}
		break
	}

	return consume(lex, .Int)
}

lex_identifier :: proc(lex: ^Lexer) -> Token {
	char := next(lex)
	for char != utf8.RUNE_EOF {
		if is_alphabet(char) || is_valid_symbol(char) || is_digit(char) {
			char = next(lex)
			continue
		}

		break
	}

	tok := consume(lex, .Identifier)
	switch tok.value {
	case "true", "false":
		tok.type = .Bool
	case "def", "defn":
		tok.type = .Keyword
	}
	return tok
}

unexpected_token :: proc(tok: Token) -> Syntax_Error {
	return Syntax_Error{tok.line, tok.column}
}

// syntax_errorf :: proc(tok: Token, format: string, values: ..any) -> Syntax_Error {
// 	return Syntax_Error{reason = fmt.tprintf(format, values), line = tok.line, col = tok.column}
// }

// syntax_error :: proc(tok: Token, reason: string) -> Syntax_Error {
// 	return Syntax_Error{reason = strings.clone(reason), line = tok.line, col = tok.column}
// }
