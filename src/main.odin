package main

import "core:fmt"
import "src:text"

main :: proc() {
	code := text.string_lexer("(- 1000 (add-123 120 123))")
	tokens, err := text.tokenize(&code)
	if err != nil {
		panic(fmt.tprintf("Syntax error: %v", err))
	}

	fmt.printfln("The tokens are %v", tokens)
}
