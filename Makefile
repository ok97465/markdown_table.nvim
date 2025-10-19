.PHONY: test

test:
	nvim --headless -u tests/minimal_init.lua -c "lua require('tests.runner').main()" -c "qa"

