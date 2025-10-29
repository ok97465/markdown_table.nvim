.PHONY: test

NVIM ?= nvim
TEST_CMD = $(NVIM) --headless -u tests/minimal_init.lua -c "lua require('tests.runner').main()" -c "qa"

# OS별 분기 (GNU Make에서 Windows면 OS=Windows_NT)
ifeq ($(OS),Windows_NT)
  # cmd.exe를 쉘로 사용
  SHELL := cmd.exe
  .SHELLFLAGS := /V:ON /C

  # nvim 존재 확인 (cmd 구문)
  CHECK_NVIM = where $(NVIM) >nul 2>nul || ( echo Error: $(NVIM) not found in PATH & exit /b 1 )
else
  # POSIX sh 사용
  SHELL := /bin/sh

  # nvim 존재 확인 (POSIX 구문)
  CHECK_NVIM = if ! command -v $(NVIM) >/dev/null 2>&1; then echo "Error: $(NVIM) not found in PATH"; exit 1; fi
endif

test:
	@$(CHECK_NVIM)
	@$(TEST_CMD)
