#+feature dynamic-literals

package rt

import "core:fmt"
import "src:parser"

Error :: union {
	Insufficient_Stack,
	Type_Mismatch,
	Incorrect_Arity,
	Undefined_Name,
	Already_Defined,
}

Insufficient_Stack :: struct {
	expected: int,
	got:      int,
}

Type_Mismatch :: struct {
	expected: typeid,
	got:      typeid,
}

Incorrect_Arity :: struct {
	expected: int,
	got:      int,
}

Undefined_Name :: struct {
	name: string,
}

Already_Defined :: struct {
	name: string,
	// location: u8
}

Primitives :: union {
	parser.Int,
	parser.Bool,
}

Value :: union {
	Primitives,
	[]Primitives,
}

Stack :: [dynamic]Primitives

// Ideally Scope.defs can also contain function
// so Runtime.defs can be of type scope, but that is too complicated for now
Scope :: struct {
	parent: ^Scope,
	defs:   map[string]Value,
}


delete_scope :: proc(scope: ^Scope) {
	for _, v in scope.defs {
		#partial switch _ in v {
		case []Primitives:
			delete_slice(v.([]Primitives))
		}
	}

	delete_map(scope.defs)
}

find_id :: proc(scope: Scope, name: string) -> (prim: Primitives, err: Error) {
	value, found := scope.defs[name]
	if found {
		return value.(Primitives), nil
	}

	if scope.parent != nil {
		return find_id(scope.parent^, name)
	}

	return nil, Undefined_Name{name}
}

User_Function :: parser.Function
Builtin_Function :: struct {
	args: map[string]parser.Arg,
	body: proc(scope: Scope) -> (Primitives, Error),
}

Function :: union {
	User_Function,
	Builtin_Function,
}

Runtime :: struct {
	defs:  map[string]Function,
	scope: Scope,
	stack: Stack,
}

delete_runtime :: proc(rt: ^Runtime) {
	for _, fn in rt.defs {
		switch _ in fn {
		case User_Function:
			delete(fn.(User_Function).args)
		case Builtin_Function:
			delete(fn.(Builtin_Function).args)
		}
	}

	delete_map(rt.defs)
	delete_scope(&rt.scope)
	delete_dynamic_array(rt.stack)
}

new :: proc() -> Runtime {
	stack := make([dynamic]Primitives, 0)
	scope := Scope {
		parent = nil,
		defs = {"__version__" = 1},
	}

	return Runtime {
		stack = stack,
		defs = {
			"+" = add_builtin(),
			"-" = subtract_builtin(),
			"*" = multiply_builtin(),
			"/" = division_builtin(),
			"=" = equal_builtin(),
			"and" = and_builtin(),
			"or" = or_builtin(),
			"not" = not_builtin(),
		},
		scope = scope,
	}
}

peek_stack :: proc(stack: Stack) -> (Primitives, bool) {
	if expect_stack_size(stack, 1) != nil {
		return nil, false
	}
	return stack[len(stack) - 1], true
}

eval :: proc(rt: ^Runtime, ast: parser.AST) -> Error {
	// NOTE: currently this define everything inorder
	// Ideally create graph of dependencies before defining
	for _, def in ast.defs {
		define(rt, def)
	}

	for expr in ast.exprs {
		val, err := eval_expr(rt, expr)
		append(&rt.stack, val)
		return err
	}
	return nil
}


eval_expr :: proc(rt: ^Runtime, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	switch _ in expr {
	case parser.Int:
		return Primitives(expr.(parser.Int)), nil
	case parser.Bool:
		return Primitives(expr.(parser.Bool)), nil
	case parser.Identifier:
		id := expr.(parser.Identifier)
		return find_id(rt.scope, id.name)
	case parser.Function_Call:
		return invoke(rt, expr)
	}
	return nil, nil
}

define :: proc(rt: ^Runtime, definition: parser.Definition) -> (prim: Primitives, err: Error) {
	_, is_var_defined := rt.scope.defs[definition.name]
	_, is_func_defined := rt.defs[definition.name]

	if is_var_defined || is_func_defined {
		return nil, Already_Defined{definition.name}
	}

	switch _ in definition.value {
	case parser.Expr:
		expr := definition.value.(parser.Expr)
		rt.scope.defs[definition.name] = eval_expr(rt, expr) or_return
		return
	case parser.Function:
		panic("Unreachable")
	}
	panic("Unreachable")
}

invoke :: proc(rt: ^Runtime, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	fn_call := expr.(parser.Function_Call)
	fn_def, ok := rt.defs[fn_call.name]

	if !ok {
		return nil, Undefined_Name{fn_call.name}
	}

	new_scope := Scope {
		parent = &rt.scope,
	}

	defer delete_scope(&new_scope)

	params: map[string]parser.Arg
	switch _ in fn_def {
	case User_Function:
		params = fn_def.(parser.Function).args
	case Builtin_Function:
		params = fn_def.(Builtin_Function).args
	}

	check_arity(params, fn_call.args) or_return

	// Put argument into the scope
	arg_pos := 0
	for name, kind in params {
		if kind == .PosArg {
			val := eval_expr(rt, fn_call.args[arg_pos]) or_return
			new_scope.defs[name] = val
			arg_pos += 1
			continue
		}

		//VarArgs
		var_arg_count := len(fn_call.args) - len(params) + 1
		var_args := make([]Primitives, var_arg_count)

		for offset in 0 ..< var_arg_count {
			val := eval_expr(rt, fn_call.args[arg_pos + offset]) or_return
			var_args[offset] = val
		}

		new_scope.defs[name] = var_args
	}

	// Invoke the function!
	#partial switch _ in fn_def {
	case Builtin_Function:
		fn := fn_def.(Builtin_Function)
		result := fn.body(new_scope) or_return
		return result, nil
	}

	return nil, nil
}

check_arity :: proc(params: map[string]parser.Arg, args: []parser.Expr) -> Error {
	param_count, args_count := len(params), len(args)
	pos_param_count, var_param_count := 0, 0

	for _, p in params {
		switch p {
		case .PosArg:
			pos_param_count += 1
		case .VarArg:
			var_param_count += 1
		}
	}

	error := Incorrect_Arity{param_count, args_count}
	if var_param_count == 0 {
		if param_count == args_count {
			return nil
		}

		return error
	}

	left_over := args_count - pos_param_count
	if left_over > 0 {
		return nil
	}
	return error
}

expect_stack_size :: proc(stack: Stack, count: int) -> Error {
	stack_len := len(stack)
	if stack_len >= count {
		return nil
	}

	return Insufficient_Stack{expected = count, got = stack_len}
}
