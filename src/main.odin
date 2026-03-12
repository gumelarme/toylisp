package main

import "core:fmt"
import "src:parser"
import "src:rt"

main :: proc() {
	_ = rt.Runtime{}

	code := parser.lexer_from_string("(- 1000 (add-123 120 123))")
	tokens, err := parser.tokenize(&code)
	if err != nil {
		panic(fmt.tprintf("Syntax error: %v", err))
	}

	fmt.printfln("The tokens are %v", tokens)
}
