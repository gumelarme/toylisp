#+feature dynamic-literals

package rt

import "src:parser"

Error :: union {
	InsufficientStack,
	TypeMismatch,
}

InsufficientStack :: struct {
	expected: int,
	got:      int,
}

TypeMismatch :: struct {
	expected: typeid,
	got:      typeid,
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

UserFunction :: parser.Function
BuiltinFunction :: struct {
	args: map[string]parser.Arg,
	body: proc(scope: Scope) -> (Primitives, Error),
}

Function :: union {
	UserFunction,
	BuiltinFunction,
}

Runtime :: struct {
	defs:  map[string]Function,
	scope: Scope,
	stack: Stack,
}

delete_runtime :: proc(rt: ^Runtime) {
	for _, fn in rt.defs {
		switch _ in fn {
		case UserFunction:
			delete(fn.(UserFunction).args)
		case BuiltinFunction:
			delete(fn.(BuiltinFunction).args)
		}
	}

	delete_map(rt.defs)
	delete_dynamic_array(rt.stack)
}

new :: proc() -> Runtime {
	stack := make([dynamic]Primitives, 0)
	return Runtime {
		stack = stack,
		defs = {
			"+" = add_builtin(),
			"-" = subtract_builtin(),
			"*" = multiply_builtin(),
			"/" = division_builtin(),
		},
	}
}

peek_stack :: proc(stack: Stack) -> (Primitives, bool) {
	if expect_stack_size(stack, 1) != nil {
		return nil, false
	}

	return stack[len(stack) - 1], true
}

eval :: proc(rt: ^Runtime, ast: parser.AST) -> Error {
	for expr in ast.exprs {
		val, err := eval_expr(rt, expr)
		append(&rt.stack, val)
		return err
	}
	return nil
}


eval_expr :: proc(rt: ^Runtime, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	#partial switch _ in expr {
	case parser.Int:
		return Primitives(expr.(parser.Int)), nil
	case parser.Bool:
		return Primitives(expr.(parser.Bool)), nil
	// i_load(&rt.stack, expr) or_return
	case parser.Function_Call:
		return invoke(rt, expr)
	}
	return nil, nil
}

invoke :: proc(rt: ^Runtime, expr: parser.Expr) -> (prim: Primitives, err: Error) {
	fn_call := expr.(parser.Function_Call)
	fn_def := rt.defs[fn_call.name]

	new_scope := Scope {
		parent = &rt.scope,
	}

	defer if err != nil {
		delete_scope(&new_scope)
	}

	params: map[string]parser.Arg
	switch _ in fn_def {
	case UserFunction:
		params = fn_def.(parser.Function).args
	case BuiltinFunction:
		params = fn_def.(BuiltinFunction).args
	}


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
		rt.scope = new_scope

	}

	// Invoke the function!
	#partial switch _ in fn_def {
	case BuiltinFunction:
		defer delete_scope(&rt.scope) // cleanup args

		fn := fn_def.(BuiltinFunction)
		result := fn.body(rt.scope) or_return
		rt.scope = rt.scope.parent^
		return result, nil
	}

	return nil, nil
}

expect_stack_size :: proc(stack: Stack, count: int) -> Error {
	stack_len := len(stack)
	if stack_len >= count {
		return nil
	}

	return InsufficientStack{expected = count, got = stack_len}
}
