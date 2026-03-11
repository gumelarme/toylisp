package test

// import "core:fmt"
// import "core:strings"
import "core:testing"
import "src:text"

@(test)
test_parser_function_call_simple :: proc(t: ^testing.T) {
	ast, err := text.parse("(+ 1 2 3)")
	defer text.delete_ast(ast)

	fn := ast.exprs[0].(text.Function_Call)
	eq := text.is_function_call_equal(
		fn,
		text.Function_Call{name = "+", args = {text.Number(1), text.Number(2), text.Number(3)}},
	)

	testing.expect_value(t, err, nil)
	testing.expect_value(t, eq, true)
}

@(test)
test_parser_function_call_nested :: proc(t: ^testing.T) {
	ast, err := text.parse("(+ 1 2 (* 3 4))")
	defer text.delete_ast(ast)

	fn := ast.exprs[0].(text.Function_Call)
	mul := text.Function_Call {
		name = "*",
		args = {text.Number(3), text.Number(4)},
	}
	eq := text.is_function_call_equal(
		fn,
		text.Function_Call{name = "+", args = {text.Number(1), text.Number(2), mul}},
	)

	testing.expect_value(t, err, nil)
	testing.expect_value(t, eq, true)
}
