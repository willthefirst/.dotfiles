# Task: Split conflicts.sh Into Focused Modules

## Branch Name
`refactor/split-conflicts-module`

## Problem Statement
`lib/conflicts.sh` is 391 lines - the largest library file (3x typical module size). It violates single responsibility by handling data structures, parsing, detection, reporting, AND resolution all in one file.

### Current Structure in `lib/conflicts.sh`

| Lines | Responsibility | Functions |
|-------|---------------|-----------|
| 13-26 | Constants & Format | `CONFLICT_TYPE_FILE`, `CONFLICT_TYPE_SYMLINK`, `PARENT_STATUS_*` |
| 31-44 | Constructors | `make_file_conflict()`, `make_symlink_conflict()` |
| 47-101 | Parsers | `parse_conflict_type()`, `parse_conflict_path()`, `parse_conflict_target()` |
| 104-178 | Detection Helpers | `report_symlink_mismatch()`, `is_already_checked()`, `check_directory_conflict()`, `check_parent_symlink()`, `check_file_conflict()` |
| 195-248 | Main Detection | `get_package_conflicts()` |
| 250-321 | Reporting | `check_all_conflicts()` |
| 323-391 | Resolution | `remove_conflict()`, `is_under_removed_path()`, `handle_conflicts()` |

### Issues
1. Too many reasons to change this file
2. Hard to test individual components in isolation
3. Difficult to understand the full scope
4. Tight coupling between detection, reporting, and resolution

## Desired Outcome
Split into three focused modules:
- `lib/conflict-data.sh` - data structures, constants, constructors, parsers
- `lib/conflict-detect.sh` - detection logic
- `lib/conflict-resolve.sh` - resolution and user-facing reporting

## Implementation Steps

### 1. Create `lib/conflict-data.sh`
Move from `lib/conflicts.sh`:
- Lines 13-26: Constants (`CONFLICT_TYPE_*`, `PARENT_STATUS_*`)
- Lines 31-44: Constructors (`make_file_conflict()`, `make_symlink_conflict()`)
- Lines 47-101: Parsers (`parse_conflict_type()`, `parse_conflict_path()`, `parse_conflict_target()`)

This module should have NO dependencies on other conflict modules.

### 2. Create `lib/conflict-detect.sh`
Move from `lib/conflicts.sh`:
- Lines 104-178: Detection helpers
- Lines 195-248: `get_package_conflicts()`

This module should:
- Source `lib/conflict-data.sh`
- Source `lib/log.sh` (for logging)

### 3. Create `lib/conflict-resolve.sh`
Move from `lib/conflicts.sh`:
- Lines 250-321: `check_all_conflicts()` (reporting)
- Lines 323-391: `remove_conflict()`, `is_under_removed_path()`, `handle_conflicts()`

This module should:
- Source `lib/conflict-data.sh`
- Source `lib/conflict-detect.sh`
- Source `lib/log.sh`

### 4. Update `lib/conflicts.sh` to be a facade
Convert the original file to simply source all three modules:
```bash
#!/usr/bin/env bash
# Facade for backward compatibility - sources all conflict modules
source "${BASH_SOURCE%/*}/conflict-data.sh"
source "${BASH_SOURCE%/*}/conflict-detect.sh"
source "${BASH_SOURCE%/*}/conflict-resolve.sh"
```

This maintains backward compatibility with existing code that sources `lib/conflicts.sh`.

### 5. Update callers
Check these files for direct usage:
- `lib/deploy.sh:119-127` calls `check_all_conflicts()` and `handle_conflicts()`
- Any test files in `tests/`

### 6. Update tests
- `tests/test_conflicts.sh` should continue to work
- Consider adding focused tests for each new module

## Files to Create/Modify
- `lib/conflict-data.sh` (CREATE)
- `lib/conflict-detect.sh` (CREATE)
- `lib/conflict-resolve.sh` (CREATE)
- `lib/conflicts.sh` (MODIFY - convert to facade)
- `tests/test_conflicts.sh` (VERIFY - ensure tests pass)

## Dependency Graph
```
conflict-data.sh (no conflict dependencies)
       ↑
conflict-detect.sh (depends on data)
       ↑
conflict-resolve.sh (depends on data + detect)
       ↑
conflicts.sh (facade - sources all three)
```

## Testing
```bash
# Run conflict-specific tests
./tests/run_tests.sh test_conflicts.sh

# Run all tests to check for regressions
./tests/run_tests.sh

# Verify the install workflow still works
./install.sh --dry-run base
```

## Success Criteria
- [ ] Three new focused modules created
- [ ] `lib/conflicts.sh` is now a simple facade (~5-10 lines)
- [ ] Each new module is under 150 lines
- [ ] All existing tests pass
- [ ] `install.sh` and `validate.sh` work correctly
- [ ] No circular dependencies between modules
