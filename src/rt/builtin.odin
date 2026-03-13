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
			arg_type := reflect.union_variant_typeid(arg)
			return nil, Type_Mismatch{W, arg_type}
		}
	}

	return args, nil
}

add_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
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

subtract_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
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

multiply_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
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

division_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
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

// -- Bool builtin functions

and_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Bool, bool) or_return
			defer delete(args)

			fn := proc(a, b: bool) -> bool {return a && b}
			result := reducer(bool, args, fn, true)
			return Primitives(parser.Bool(result)), nil
		},
	}
}

or_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
		args = {"values" = .VarArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			args := var_args_collector(scope, parser.Bool, bool) or_return
			defer delete(args)

			fn := proc(a, b: bool) -> bool {return a || b}
			result := reducer(bool, args, fn, true)
			return Primitives(parser.Bool(result)), nil
		},
	}
}

not_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
		args = {"pred" = .PosArg},
		body = proc(scope: Scope) -> (prim: Primitives, err: Error) {
			arg := scope.defs["pred"].(Primitives)

			result := !bool(arg.(parser.Bool))
			return Primitives(parser.Bool(result)), nil
		},
	}
}

equal_builtin :: proc() -> Builtin_Function {
	return Builtin_Function {
		args = {"a" = .PosArg, "b" = .PosArg},
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
