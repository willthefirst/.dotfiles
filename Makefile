# Tool versions - CI reads these to stay in sync with local
SHELLCHECK_VERSION := 0.11.0

.PHONY: setup configure configure-force configure-adopt install test lint lint-conventions check-shellcheck-version validate clean uninstall help

# Default packages (all available)
PACKAGES ?= nvim git zsh ssh ghostty

help:
	@echo "Dotfiles Management"
	@echo "==================="
	@echo "  make setup            - Full setup (install programs + configure)"
	@echo "  make install          - Install programs/packages"
	@echo "  make configure        - Configure dotfiles (symlinks only)"
	@echo "  make configure-force  - Configure, removing conflicts"
	@echo "  make configure-adopt  - Configure, adopting existing files"
	@echo "  make test             - Run test suite"
	@echo "  make lint             - Run ShellCheck + conventions"
	@echo "  make lint-conventions - Check coding conventions only"
	@echo "  make validate         - Validate configs"
	@echo "  make clean            - Remove backups older than 7 days"
	@echo "  make uninstall        - Remove all symlinks"
	@echo ""
	@echo "Options:"
	@echo "  PACKAGES=\"nvim git\"   - Specify packages (for install, setup, uninstall)"

setup:
	./install.sh --with-deps $(PACKAGES)

install:
	./install.sh --deps-only $(PACKAGES)

configure:
	./install.sh

configure-force:
	./install.sh --force

configure-adopt:
	./install.sh --adopt

test:
	./tests/test_runner.sh

SHELL_FILES := install.sh lib/*.sh tests/*.sh validate.sh scripts/*.sh */install.sh
LOG := ./scripts/log.sh

check-shellcheck-version:
	@shellcheck --version | grep -q 'version: $(SHELLCHECK_VERSION)' \
		|| { $(LOG) error "Expected shellcheck $(SHELLCHECK_VERSION), run: brew upgrade shellcheck"; exit 1; }

lint: check-shellcheck-version lint-conventions
	shellcheck $(SHELL_FILES)
	@for f in $(SHELL_FILES); do bash -n "$$f" || exit 1; done
	@$(LOG) ok "All files pass ShellCheck and syntax check"

lint-conventions:
	@./scripts/lint-conventions.sh

validate:
	./validate.sh

clean:
	@$(LOG) step "Removing backups older than 7 days..."
	@. ./lib/config.sh && find ~ -maxdepth 1 -name "$${BACKUP_PREFIX}*" -mtime +$${BACKUP_RETENTION_DAYS} -exec rm -rf {} \;
	@$(LOG) ok "Cleanup complete"

uninstall:
	@cd $(HOME)/.dotfiles && stow -D -t ~ $(PACKAGES) 2>&1 | grep -v "BUG in find_stowed_path" || true
	@$(LOG) ok "Symlinks removed"
