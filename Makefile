.PHONY: test

NVIM ?= nvim
TEST_CMD = $(NVIM) --headless -u tests/minimal_init.lua \
	-c "lua require('tests.runner').main()" -c "qa"

test:
	@if ! command -v $(NVIM) >/dev/null 2>&1; then \
		echo "Error: $(NVIM) not found in PATH"; \
		exit 1; \
	fi
	@$(TEST_CMD)
