.PHONY: build
build:
	mkdir -p lib
	node_modules/.bin/lsc -o lib src
.PHONY: test
test: build
	npm test
clean:
	rm -rf lib
