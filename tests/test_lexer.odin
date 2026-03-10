package test

import "core:fmt"
import "core:log"
import "core:strings"
import "core:testing"
import "src:text"


compare_tokens :: proc(a, b: []text.Token) -> (bool, []string) {
	reasons: [dynamic]string

	if len(a) != len(b) {
		append(&reasons, fmt.tprintf("unequal length, expected %d got %d", len(a), len(b)))
		return false, reasons[:]
	}

	for tok, i in a {
		if tok != b[i] {
			append(
				&reasons,
				fmt.tprintf("different item at [%d] expected %v got %v", i, tok, b[i]),
			)
		}
	}

	return len(reasons) == 0, reasons[:]
}

@(test)
test_lexer_number :: proc(t: ^testing.T) {
	source := text.from_string("123a")
	defer delete(source.buffer)

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)

	// TODO: show what error it actually got,
	// type_info_of(typeid_of(type_of(X))) doesnt work
	_, ok := err.(text.Syntax_Error)
	testing.expect(t, ok, "Expected syntax error")
}

@(test)
test_lexer_simple :: proc(t: ^testing.T) {
	source := text.from_string("(+ 1 2)")
	defer delete(source.buffer)

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)

	testing.expect(t, err == nil, "should not return error")

	expected := []text.Token {
		{.Left_Paren, "(", 1, 1},
		{.Identifier, "+", 1, 2},
		{.Number, "1", 1, 4},
		{.Number, "2", 1, 6},
		{.Right_Paren, ")", 1, 7},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))
}

@(test)
test_multiline_string :: proc(t: ^testing.T) {
	source_code := strings.join({"(+ 888", "(* 12 3))"}, "\n")
	defer delete(source_code)

	source := text.from_string(source_code)
	defer delete(source.buffer)

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)

	testing.expect_value(t, err, nil)
	testing.expect_value(t, source.line, 2)
	testing.expect_value(t, source.column, 9)

	expected := []text.Token {
		{.Left_Paren, "(", 1, 1},
		{.Identifier, "+", 1, 2},
		{.Number, "888", 1, 4},
		{.Left_Paren, "(", 2, 1},
		{.Identifier, "*", 2, 2},
		{.Number, "12", 2, 4},
		{.Number, "3", 2, 7},
		{.Right_Paren, ")", 2, 8},
		{.Right_Paren, ")", 2, 9},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))
}

@(test)
test_lexer_from_file :: proc(t: ^testing.T) {
	source, _ := text.from_file("./resources/fib.cl")
	defer {
		delete(source.source)
		delete(source.buffer)
	}

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, source.line, 6)
	testing.expect_value(t, source.column, 7)
}

@(test)
test_parse_bool :: proc(t: ^testing.T) {
	source := text.from_string("(= true false)")
	defer delete(source.buffer)

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)

	expected := []text.Token {
		{.Left_Paren, "(", 1, 1},
		{.Identifier, "=", 1, 2},
		{.Bool, "true", 1, 4},
		{.Bool, "false", 1, 9},
		{.Right_Paren, ")", 1, 14},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))

}

@(test)
test_parse_keyword :: proc(t: ^testing.T) {

	source_code := strings.join({"(def x 1)", "(defn a ())"}, "\n")
	source := text.from_string(source_code)
	defer delete(source.buffer)

	tokens, err := text.tokenize(&source)
	defer text.delete_tokens(tokens)

	expected := []text.Token {
		// First line
		{.Left_Paren, "(", 1, 1},
		{.Keyword, "def", 1, 2},
		{.Identifier, "x", 1, 6},
		{.Number, "1", 1, 8},
		{.Right_Paren, ")", 1, 9},

		// Second line
		{.Left_Paren, "(", 2, 1},
		{.Keyword, "defn", 2, 2},
		{.Identifier, "a", 2, 7},
		{.Left_Paren, "(", 2, 9},
		{.Right_Paren, ")", 2, 10},
		{.Right_Paren, ")", 2, 11},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))
}
