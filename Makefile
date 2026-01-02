# Tool versions - CI reads these to stay in sync with local
SHELLCHECK_VERSION := 0.11.0

.PHONY: install install-force install-adopt install-all deps test lint check-shellcheck-version validate clean uninstall help

# Default packages (all available)
PACKAGES ?= nvim git zsh ssh ghostty

help:
	@echo "Dotfiles Management"
	@echo "==================="
	@echo "  make install        - Install dotfiles (symlinks only)"
	@echo "  make install-force  - Install dotfiles, removing conflicts"
	@echo "  make install-adopt  - Install dotfiles, adopting existing files"
	@echo "  make deps           - Install dependencies for all packages"
	@echo "  make install-all    - Full setup (deps + stow)"
	@echo "  make test           - Run test suite"
	@echo "  make lint           - Run ShellCheck"
	@echo "  make validate       - Validate configs"
	@echo "  make clean          - Remove backups older than 7 days"
	@echo "  make uninstall      - Remove all symlinks"
	@echo ""
	@echo "Options:"
	@echo "  PACKAGES=\"nvim git\" - Specify packages (for deps, install-all)"

install:
	./install.sh

install-force:
	./install.sh --force

install-adopt:
	./install.sh --adopt

deps:
	./install.sh --deps-only $(PACKAGES)

install-all:
	./install.sh --with-deps $(PACKAGES)

test:
	./tests/test_runner.sh

SHELL_FILES := install.sh lib/*.sh tests/*.sh validate.sh */install.sh

check-shellcheck-version:
	@shellcheck --version | grep -q 'version: $(SHELLCHECK_VERSION)' \
		|| { echo "Error: expected shellcheck $(SHELLCHECK_VERSION), run: brew upgrade shellcheck"; exit 1; }

lint: check-shellcheck-version
	shellcheck $(SHELL_FILES)
	@for f in $(SHELL_FILES); do bash -n "$$f" || exit 1; done
	@echo "All files pass ShellCheck and syntax check"

validate:
	./validate.sh

clean:
	@echo "Removing backups older than 7 days..."
	find ~ -maxdepth 1 -name ".dotfiles-backup-*" -mtime +7 -exec rm -rf {} \;

uninstall:
	cd $(HOME)/.dotfiles && stow -D -t ~ zsh git nvim ssh ghostty 2>&1 | grep -v "BUG in find_stowed_path" || true
	@echo "Symlinks removed"
