#+feature dynamic-literals

package rt

import "src:parser"

reducer :: proc($T: typeid, args: []T, fn: proc(a, b: T) -> T, init: T) -> T {
	res := T(init) if len(args) < 2 else args[0]
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

	values := scope.defs["values"].([]Primitives)
	args := make([]B, len(values))
	defer if err != nil {
		delete(args)
	}

	for arg, i in values {
		#partial switch type_ in arg {
		case W:
			args[i] = B(arg.(W))
		case:
			return nil, TypeMismatch{W, type_of(type_)}
		}
	}

	return args, nil
}

add_builtin :: proc() -> BuiltinFunction {
	return BuiltinFunction {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a + b}
			result := reducer(int, args, fn, 0)
			return Primitives(parser.Int(result)), nil
		},
	}
}

subtract_builtin :: proc() -> BuiltinFunction {
	return BuiltinFunction {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a - b}
			result := reducer(int, args, fn, 0)
			return Primitives(parser.Int(result)), nil
		},
	}
}

multiply_builtin :: proc() -> BuiltinFunction {
	return BuiltinFunction {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a * b}
			result := reducer(int, args, fn, 1)
			return Primitives(parser.Int(result)), nil
		},
	}
}

division_builtin :: proc() -> BuiltinFunction {
	return BuiltinFunction {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Int, int) or_return
			defer delete(args)

			fn := proc(a, b: int) -> int {return a / b}
			result := reducer(int, args, fn, 1)
			return Primitives(parser.Int(result)), nil
		},
	}
}
