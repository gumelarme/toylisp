package test

import "core:testing"
import "src:parser"

// TODO: test for every possible error to check for leak

@(test)
test_parser_function_call_simple :: proc(t: ^testing.T) {
	ast, err := parser.parse("(+ 1 2 3)")
	defer parser.delete_ast(ast)

	// fn := ast.exprs[0].(parser.Function_Call)
	// eq := parser.is_function_call_equal(
	// 	fn,
	// 	parser.Function_Call{name = "+", args = {parser.Int(1), parser.Int(2), parser.Int(3)}},
	// )

	eq := parser.is_expression_equal(
		ast.exprs[0],
		[]parser.Expr{parser.Identifier("+"), parser.Int(1), parser.Int(2), parser.Int(3)},
	)

	testing.expect_value(t, err, nil)
	testing.expect_value(t, eq, true)
}

@(test)
test_parser_function_call_nested :: proc(t: ^testing.T) {
	ast, err := parser.parse("(+ 1 2 (* 3 4))")
	defer parser.delete_ast(ast)

	// fn := ast.exprs[0].(parser.Function_Call)
	// mul := parser.Function_Call {
	// 	name = "*",
	// 	args = ,
	// }

	mul := []parser.Expr{parser.Identifier("*"), parser.Int(3), parser.Int(4)}
	eq := parser.is_expression_equal(
		ast.exprs[0],
		[]parser.Expr{parser.Identifier("+"), parser.Int(1), parser.Int(2), mul},
	)


	// eq := parser.is_function_call_equal(
	// 	fn,
	// 	parser.Function_Call{name = "+", args = {parser.Int(1), parser.Int(2), mul}},
	// )

	testing.expect_value(t, err, nil)
	testing.expect_value(t, eq, true)
}
