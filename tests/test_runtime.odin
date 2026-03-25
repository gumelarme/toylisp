package test

import "core:testing"
import "src:parser"
import "src:rt"


@(test)
test_number_builtin_function :: proc(t: ^testing.T) {
	tree, err := parser.parse("(+ 1 2 3)")
	defer parser.delete_ast(tree)

	vm := rt.new()
	defer rt.delete_runtime(&vm)
	evaluation_err := rt.eval(&vm, tree)
	result, has_value := rt.pop_stack(&vm.stack)

	testing.expect_value(t, evaluation_err, nil)
	testing.expect_value(t, has_value, true)
	testing.expect_value(t, result, rt.Primitives(6))
}

@(test)
test_number_builtin_function_nested :: proc(t: ^testing.T) {
	tree, err := parser.parse("(+ 1 (* 2 5 1) (- (/ 16 4) 2))")
	defer parser.delete_ast(tree)

	vm := rt.new()
	defer rt.delete_runtime(&vm)
	evaluation_err := rt.eval(&vm, tree)
	result, has_value := rt.pop_stack(&vm.stack)

	testing.expect_value(t, evaluation_err, nil)
	testing.expect_value(t, has_value, true)
	testing.expect_value(t, result, rt.Primitives(13))
}
