.PHONY: install install-force install-adopt test lint validate clean uninstall help

help:
	@echo "Dotfiles Management"
	@echo "==================="
	@echo "  make install       - Install dotfiles"
	@echo "  make install-force - Install dotfiles, removing conflicts"
	@echo "  make install-adopt - Install dotfiles, adopting existing files"
	@echo "  make test          - Run test suite"
	@echo "  make lint          - Run ShellCheck"
	@echo "  make validate      - Validate configs"
	@echo "  make clean         - Remove backups older than 7 days"
	@echo "  make uninstall     - Remove all symlinks"

install:
	./install.sh

install-force:
	./install.sh --force

install-adopt:
	./install.sh --adopt

test:
	./tests/test_runner.sh

lint:
	shellcheck install.sh lib/*.sh tests/*.sh validate.sh
	@echo "All files pass ShellCheck"

validate:
	./validate.sh

clean:
	@echo "Removing backups older than 7 days..."
	find ~ -maxdepth 1 -name ".dotfiles-backup-*" -mtime +7 -exec rm -rf {} \;

uninstall:
	cd $(HOME)/.dotfiles && stow -D -t ~ zsh git nvim ssh ghostty
	@echo "Symlinks removed"
