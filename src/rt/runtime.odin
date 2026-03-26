#+feature dynamic-literals

package rt

import "src:parser"

Error :: union {
	Insufficient_Stack,
	Type_Mismatch,
	Incorrect_Arity,
	Undefined_Name,
	Already_Defined,
	Is_Non_Callable,
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
}

Is_Non_Callable :: struct {
	name: string,
}

Primitives :: union {
	parser.Int,
	parser.Bool,
}

Value :: union {
	Function,
	Primitives,
	[]Primitives,
}

Native_Func_Body :: proc(scope: Scope) -> (Primitives, Error)

Function :: struct {
	params: map[string]parser.Arg,
	body:   union {
		parser.Expr,
		Native_Func_Body,
	},
}

Stack :: [dynamic]Primitives

Scope :: struct {
	parent: ^Scope,
	defs:   map[string]Value,
}


delete_scope :: proc(scope: ^Scope) {
	for _, def in scope.defs {
		#partial switch _ in def {
		case []Primitives:
			delete(def.([]Primitives))
		case Function:
			fn := def.(Function)
			delete(fn.params)

			#partial switch _ in fn.body {
			case parser.Expr:
				// FIXME: could not use delete_expression
				// because its also delete func.name,
				// while hardcoded user function names are automatically cleared
				// and parsed user function need to be clearead manually
				delete(fn.body.(parser.Expr).(parser.Function_Call).args)
			}
		}
	}

	delete_map(scope.defs)
}

find_id :: proc(scope: Scope, name: string) -> (val: Value, err: Error) {
	value, found := scope.defs[name]
	if found {
		return value, nil
	}

	if scope.parent != nil {
		return find_id(scope.parent^, name)
	}

	return nil, Undefined_Name{name}
}


Runtime :: struct {
	scope: Scope,
	stack: Stack,
}

delete_runtime :: proc(rt: ^Runtime) {
	delete_scope(&rt.scope)
	delete_dynamic_array(rt.stack)
}

new :: proc() -> Runtime {
	stack := make([dynamic]Primitives, 0)
	scope := Scope {
		parent = nil,
		defs = {
			"__version__" = 1,
			"+" = add_builtin(),
			"-" = subtract_builtin(),
			"*" = multiply_builtin(),
			"/" = division_builtin(),
			"=" = equal_builtin(),
			"and" = and_builtin(),
			"or" = or_builtin(),
			"not" = not_builtin(),
			"inc" = inc(),
			"dec" = dec(),
		},
	}

	return Runtime{stack = stack, scope = scope}
}


pop_stack :: proc(stack: ^Stack) -> (Primitives, bool) {
	if expect_stack_size(stack^, 1) != nil {
		return nil, false
	}

	result := pop(stack)
	return result, true
}

eval :: proc(rt: ^Runtime, ast: parser.AST) -> Error {
	// NOTE: currently this define everything inorder
	// Ideally create graph of dependencies before defining
	for _, def in ast.defs {
		define(rt, def)
	}

	for expr in ast.exprs {
		val, err := eval_expr(&rt.scope, expr)
		append(&rt.stack, val)
		return err
	}
	return nil
}


eval_expr :: proc(scope: ^Scope, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	switch _ in expr {
	case parser.Int:
		return Primitives(expr.(parser.Int)), nil
	case parser.Bool:
		return Primitives(expr.(parser.Bool)), nil
	case parser.Identifier:
		return eval_variable(scope, expr)
	case parser.Function_Call:
		return invoke(scope, expr)
	case:
		panic("Somethings wrong")
	}

	panic("Expr is nil")
}

eval_variable :: proc(scope: ^Scope, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	id := expr.(parser.Identifier)
	value := find_id(scope^, id.name) or_return

	switch _ in value {
	case Primitives:
		return value.(Primitives), nil
	case Function, []Primitives:
		return nil, Type_Mismatch{expected = typeid_of(type_of(value)), got = typeid_of(Function)}
	}

	panic("What should i do??")
}

define :: proc(rt: ^Runtime, definition: parser.Definition) -> (prim: Primitives, err: Error) {
	_, is_var_defined := rt.scope.defs[definition.name]
	_, is_func_defined := rt.scope.defs[definition.name]

	if is_var_defined || is_func_defined {
		return nil, Already_Defined{definition.name}
	}

	switch _ in definition.value {
	case parser.Expr:
		expr := definition.value.(parser.Expr)
		rt.scope.defs[definition.name] = eval_expr(&rt.scope, expr) or_return
		return
	case parser.Function:
		panic("Unreachable")
	}
	panic("Unreachable")
}

invoke :: proc(scope: ^Scope, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	fn_call := expr.(parser.Function_Call)
	fn_def := find_id(scope^, fn_call.name) or_return

	fn: Function
	#partial switch _ in fn_def {
	case Function:
		fn = fn_def.(Function)
	case:
		return nil, Is_Non_Callable{fn_call.name}
	}

	new_scope := Scope {
		parent = scope,
	}

	defer delete_scope(&new_scope)
	check_arity(fn.params, fn_call.args) or_return

	// Put the argument into the scope
	arg_pos := 0
	for name, kind in fn.params {
		if kind == .PosArg {
			val := eval_expr(scope, fn_call.args[arg_pos]) or_return
			new_scope.defs[name] = val
			arg_pos += 1
			continue
		}

		var_arg_count := len(fn_call.args) - len(fn.params) + 1
		var_args := make([]Primitives, var_arg_count)

		for offset in 0 ..< var_arg_count {
			arg := fn_call.args[arg_pos + offset]
			val, _err := eval_expr(scope, arg)
			if _err != nil {
				return nil, err
			}
			var_args[offset] = val
		}

		new_scope.defs[name] = var_args
	}

	// Invoke the function!
	switch _ in fn.body {
	case parser.Expr:
		body := fn.body.(parser.Expr)
		return eval_expr(&new_scope, body)

	case Native_Func_Body:
		body := fn.body.(Native_Func_Body)
		result := body(new_scope) or_return
		return result, nil
	}

	// FIXME: Panic?
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
