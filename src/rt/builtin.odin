#+feature dynamic-literals

package rt

import "core:reflect"
import "src:parser"

reducer :: proc($T: typeid, args: []T, fn: proc(a, b: T) -> T, init: T) -> T {
	if len(args) < 2 {
		return fn(T(init), args[0])
	}

	res := args[0]
	for arg in args[1:] {
		res = fn(res, arg)
	}
	return res
}

var_args_collector :: proc(
	scope: Scope,
	$W: typeid, // wrapper type
	$B: typeid, // base type
) -> (
	arr: []B,
	err: Error,
) {

	values, ok := scope.defs["values"].([]Primitives)
	if !ok {
		return nil, Incorrect_Arity{1, 0}
	}

	args := make([]B, len(values))
	defer if err != nil {
		delete(args)
	}

	for arg, i in values {
		#partial switch type_ in arg {
		case W:
			args[i] = B(arg.(W))
		case:
			arg_type := reflect.union_variant_typeid(arg)
			return nil, Type_Mismatch{W, arg_type}
		}
	}

	return args, nil
}

expect_expr_type :: proc(expr: parser.Expr, $T: typeid) -> (T, Error) {
	name_arg_type := reflect.union_variant_typeid(expr)
	if name_arg_type != T {
		return T{}, Type_Mismatch{T, name_arg_type}
	}

	return expr.(T), nil
}

def_builtin :: proc() -> Function {
	return Function {
		params = {"name" = .PosArg, "value" = .PosArg},
		body = proc(scope: ^Scope, raw_expr: []parser.Expr) -> (prim: Primitives, err: Error) {
			//find root scope
			root := scope
			for root.parent != nil {
				root = scope.parent
			}

			name := expect_expr_type(raw_expr[0], parser.Identifier) or_return
			value := eval_expr(root, raw_expr[1]) or_return

			err = define(root, string(name), value, shadow = false)
			if err != nil {
				return nil, err
			}
			return Primitives(parser.Bool(true)), nil
		},
	}
}

defn_builtin :: proc() -> Function {
	return Function {
		params = {"name" = .PosArg, "params" = .PosArg, "body" = .PosArg},
		body = proc(scope: ^Scope, raw_expr: []parser.Expr) -> (prim: Primitives, err: Error) {
			//find root scope
			root := scope
			for root.parent != nil {
				root = scope.parent
			}

			name := expect_expr_type(raw_expr[0], parser.Identifier) or_return

			// check all params are Identifier
			params_expr := expect_expr_type(raw_expr[1], []parser.Expr) or_return
			params := make(map[string]Arg)
			for p in params_expr {
				arg_name := expect_expr_type(p, parser.Identifier) or_return
				params[string(arg_name)] = .PosArg // TODO: Implement .VarArg
			}

			func := Function {
				params = params,
				body   = raw_expr[2],
			}

			err = define(root, string(name), func, shadow = false)
			return Primitives(parser.Bool(true)), nil
		},
	}
}

if_builtin :: proc() -> Function {
	return Function {
		params = {"pred" = .PosArg, "then" = .PosArg, "else" = .PosArg},
		body = proc(scope: ^Scope, raw_expr: []parser.Expr) -> (prim: Primitives, err: Error) {
			pred := eval_expr(scope, raw_expr[0]) or_return

			pred_type := reflect.union_variant_typeid(pred)
			if pred_type != parser.Bool {
				return nil, Type_Mismatch{parser.Bool, pred_type}
			}

			body := raw_expr[1] if bool(pred.(parser.Bool)) else raw_expr[2]
			return eval_expr(scope, body)
		},
	}
}

add_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a + b}
			result := reducer(int, args, fn, 0)
			return Primitives(parser.Int(result)), nil
		},
	}
}

subtract_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a - b}
			result := reducer(int, args, fn, 0)
			return Primitives(parser.Int(result)), nil
		},
	}
}

multiply_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a * b}
			result := reducer(int, args, fn, 1)
			return Primitives(parser.Int(result)), nil
		},
	}
}

division_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a / b}
			result := reducer(int, args, fn, 1)
			return Primitives(parser.Int(result)), nil
		},
	}
}

// -- Bool builtin functions

and_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Bool, bool) or_return
			defer delete(args)

			fn := proc(a, b: bool) -> bool {return a && b}
			result := reducer(bool, args, fn, true)
			return Primitives(parser.Bool(result)), nil
		},
	}
}

or_builtin :: proc() -> Function {
	return Function {
		params = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Bool, bool) or_return
			defer delete(args)

			fn := proc(a, b: bool) -> bool {return a || b}
			result := reducer(bool, args, fn, true)
			return Primitives(parser.Bool(result)), nil
		},
	}
}

not_builtin :: proc() -> Function {
	return Function {
		params = {"pred" = .PosArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			arg := scope.defs["pred"].(Primitives)

			result := !bool(arg.(parser.Bool))
			return Primitives(parser.Bool(result)), nil
		},
	}
}

equal_builtin :: proc() -> Function {
	return Function {
		params = {"a" = .PosArg, "b" = .PosArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			a := scope.defs["a"].(Primitives)
			b := scope.defs["b"].(Primitives)

			type_a := reflect.union_variant_typeid(a)
			type_b := reflect.union_variant_typeid(b)
			if type_a != type_b {
				return nil, Type_Mismatch{type_a, type_b}
			}

			result := a == b
			return Primitives(parser.Bool(result)), nil
		},
	}
}

inc_builtin :: proc() -> Function {
	fn := make([]parser.Expr, 3)
	fn[0] = parser.Identifier("+")
	fn[1] = parser.Identifier("value")
	fn[2] = parser.Int(1)

	return Function{params = {"value" = .PosArg}, body = parser.Expr(fn)}
}

dec_builtin :: proc() -> Function {
	fn := make([]parser.Expr, 3)
	fn[0] = parser.Identifier("-")
	fn[1] = parser.Identifier("value")
	fn[2] = parser.Int(1)

	return Function{params = {"value" = .PosArg}, body = parser.Expr(fn)}
}
