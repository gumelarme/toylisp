COLL_FLAGS=-collection:src=src

run:
	odin run src $(COLL_FLAGS) -out:build/main 

debug:
	mkdir -p build/debug/ \
	&& odin build src $(COLL_FLAGS) -debug -out:build/debug/main \
	&& lldb --file build/debug/main

check:
	odin check src $(COLL_FLAGS) -vet

test:
	odin test tests $(COLL_FLAGS)
