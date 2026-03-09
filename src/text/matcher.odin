package text

is_digit :: proc(r: rune) -> bool {
	return r >= '0' && r <= '9'
}

is_alphabet :: proc(r: rune) -> bool {
	return (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z')
}

is_valid_symbol :: proc(r: rune) -> bool {
	for sym in "_-+*/=><?!" {
		if sym == r {return true}
	}
	return false
}
