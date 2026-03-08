COLL_FLAGS=-collection:src=src

run:
	odin run src $(COLL_FLAGS) -out:build/main

check:
	odin check src $(COLL_FLAGS)

test:
	odin test tests $(COLL_FLAGS)
