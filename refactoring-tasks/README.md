# Refactoring Tasks

This directory contains detailed task prompts for refactoring this dotfiles codebase. Each task is designed to be tackled independently on its own branch.

## Task Overview

| # | Task | Branch | Priority | Dependencies |
|---|------|--------|----------|--------------|
| 01 | [Extract Validation Helpers](./01-extract-validation-helpers.md) | `refactor/extract-validation-helpers` | High | None |
| 02 | [Split conflicts.sh Module](./02-split-conflicts-module.md) | `refactor/split-conflicts-module` | High | None |
| 03 | [Refactor deps.sh for DI](./03-refactor-deps-module.md) | `refactor/deps-module-di` | High | Task 06 (mocks) helpful |
| 04 | [Standardize Test Framework](./04-standardize-test-framework.md) | `refactor/standardize-tests` | Medium | None |
| 05 | [GitHub Download Helper](./05-github-download-helper.md) | `refactor/github-download-helper` | Medium | None |
| 06 | [Build Mock Infrastructure](./06-build-mock-infrastructure.md) | `refactor/test-mock-infrastructure` | High | None |
| 07 | [Injectable Paths](./07-hardcoded-paths-injection.md) | `refactor/injectable-paths` | Medium | None |
| 08 | [Separate install.sh Concerns](./08-install-sh-separation.md) | `refactor/install-separation` | Medium | None |
| 09 | [Module Initialization System](./09-module-initialization.md) | `refactor/module-initialization` | Medium | None |
| 10 | [Error Handling Conventions](./10-error-handling-conventions.md) | `refactor/error-handling` | Low | Task 01 helpful |

## Recommended Order

### Phase 1: Foundation (Can be done in parallel)
- **Task 01**: Extract Validation Helpers - removes duplication, creates shared module
- **Task 06**: Build Mock Infrastructure - enables better testing for other tasks
- **Task 04**: Standardize Test Framework - ensures consistent test patterns

### Phase 2: Core Refactoring (After Phase 1)
- **Task 02**: Split conflicts.sh - major module restructuring
- **Task 03**: Refactor deps.sh - requires mock infrastructure from Task 06

### Phase 3: Enhancements (Can be done in parallel)
- **Task 05**: GitHub Download Helper - standalone improvement
- **Task 07**: Injectable Paths - improves testability
- **Task 08**: Separate install.sh Concerns - cleanup

### Phase 4: Polish
- **Task 09**: Module Initialization System - requires other modules stable
- **Task 10**: Error Handling Conventions - final cleanup pass

## How to Use These Tasks

### For a single agent:
```bash
# Create branch
git checkout -b refactor/extract-validation-helpers

# Read the task
cat refactoring-tasks/01-extract-validation-helpers.md

# Implement the changes
# ... work ...

# Test
./tests/run_tests.sh
./validate.sh

# Commit
git add -A
git commit -m "Refactor: Extract validation helpers to shared module"
```

### For parallel agents:
Each agent can work on independent tasks simultaneously:
- Agent 1: Task 01 (validation helpers)
- Agent 2: Task 04 (test framework)
- Agent 3: Task 06 (mock infrastructure)

## Task Prompt Format

Each task file contains:

1. **Branch Name**: Git branch to use
2. **Problem Statement**: What's wrong and where
3. **Desired Outcome**: What should change
4. **Implementation Steps**: Detailed instructions
5. **Files to Modify**: List of files to create/change
6. **Testing**: How to verify the changes work
7. **Success Criteria**: Checklist for completion

## Notes

- All tasks maintain backward compatibility
- Run `./tests/run_tests.sh` after each change
- Run `./validate.sh` to verify the installation still works
- Each task is self-contained with all necessary context
