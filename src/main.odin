package main

import "core:bufio"
import "core:fmt"
import "core:log"
import "core:os"

import "src:parser"
import "src:rt"

Error :: union {
	parser.Error,
	rt.Error,
}


main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger

	vm := rt.new()
	defer rt.delete_runtime(&vm)

	scanner: bufio.Scanner
	stdin := os.stream_from_handle(os.stdin)
	bufio.scanner_init(&scanner, stdin, context.temp_allocator)

	fmt.println("Hello!")
	for {
		fmt.printf(">>> ")
		if !bufio.scanner_scan(&scanner) {
			break
		}

		line := bufio.scanner_text(&scanner)
		if line == "quit" {break}

		result, err := eval(&vm, line)

		if err != nil {
			fmt.eprintfln("Error: %v", err)
			continue
		}

		fmt.printfln("%v", result)
	}

	if err := bufio.scanner_error(&scanner); err != nil {
		fmt.eprintln("error scanning input: %v", err)
	}

	free_all(context.temp_allocator)
}

eval :: proc(vm: ^rt.Runtime, code: string) -> (result: rt.Primitives, err: Error) {
	ast := parser.parse(code) or_return
	rt.eval(vm, ast) or_return
	val, has_value := rt.peek_stack(vm.stack)

	if !has_value {
		return nil, rt.Error(rt.Insufficient_Stack{1, 0})
	}
	return val, nil
}
