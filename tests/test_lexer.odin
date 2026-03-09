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
	source := text.string_lexer("123a")
	tokens, err := text.tokenize(&source)

	// TODO: show what error it actually got,
	// type_info_of(typeid_of(type_of(X))) doesnt work
	_, ok := err.(text.Syntax_Error)
	testing.expect(t, ok, "Expected syntax error")
}

@(test)
test_lexer_simple :: proc(t: ^testing.T) {
	source := text.string_lexer("(+ 1 2)")
	tokens, err := text.tokenize(&source)

	testing.expect(t, err == nil, "should not return error")

	expected := []text.Token {
		{.Left_Paren, "("},
		{.Identifier, "+"},
		{.Number, "1"},
		{.Number, "2"},
		{.Right_Paren, ")"},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))
}

@(test)
test_multiline_string :: proc(t: ^testing.T) {
	source_code := strings.join({"(+ 888", "(* 12 3))"}, "\n")
	source := text.string_lexer(source_code)

	tokens, err := text.tokenize(&source)

	testing.expect_value(t, err, nil)
	testing.expect_value(t, source.line, 2)
	testing.expect_value(t, source.column, 9)

	expected := []text.Token {
		{.Left_Paren, "("},
		{.Identifier, "+"},
		{.Number, "888"},
		{.Left_Paren, "("},
		{.Identifier, "*"},
		{.Number, "12"},
		{.Number, "3"},
		{.Right_Paren, ")"},
		{.Right_Paren, ")"},
	}

	is_ok, reasons := compare_tokens(expected, tokens)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))

}
