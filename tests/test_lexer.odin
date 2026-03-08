package test

import "core:fmt"
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

test_lexer_number :: proc(t: ^testing.T) {
	source := text.string_lexer("123a")
	tokens, err := text.tokenize(&source)

	testing.expect(t, type_of(err) == text.Syntax_Error, "Expected syntax error")
}

@(test)
test_lexer_simple :: proc(t: ^testing.T) {
	source := text.string_lexer("(+ 1 2)")
	tokens, err := text.tokenize(&source)

	testing.expect(t, err == nil, "Should not return error")

	expected := []text.Token {
		{.Left_Paren, "("},
		{.Identifier, "+"},
		{.Number, "1"},
		{.Number, "2"},
		{.Right_Paren, ")"},
	}

	is_ok, reasons := compare_tokens(tokens, expected)
	testing.expect(t, is_ok, strings.join(reasons, "\n"))
}
