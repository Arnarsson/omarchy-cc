.PHONY: test test-route test-exec test-preprocess test-integration test-all

test:
	@bats tests/

test-preprocess:
	@bats tests/preprocess.bats

test-route:
	@bats tests/route.bats

test-exec:
	@bats tests/exec.bats

test-integration:
	@bash bin/omarchy-cc-test

test-all: test test-integration
