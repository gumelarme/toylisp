package main

import "core:fmt"
import "src:parser"

main :: proc() {
	code := parser.lexer_from_string("(- 1000 (add-123 120 123))")
	tokens, err := parser.tokenize(&code)
	if err != nil {
		panic(fmt.tprintf("Syntax error: %v", err))
	}

	fmt.printfln("The tokens are %v", tokens)
}
