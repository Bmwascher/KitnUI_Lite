# Test Coverage Analysis — KitnUI_Lite

## Current State

**Test coverage: 0%.** There are no test files, no test framework, and no test
configuration. All 4 Lua source files (~4,072 lines) are completely untested.

## Recommended Test Framework

[**Busted**](https://olivinelabs.com/busted/) — the standard Lua testing
framework. Since the code depends heavily on the WoW API (not available outside
the game client), a **mock layer** for WoW globals (`CreateFrame`, `C_AddOns`,
`UnitName`, `GetRealmName`, `LibStub`, etc.) is required.

---

## High-Priority Areas

### 1. `DataChecksum()` — Setup.lua:35-48
Pure logic function that computes a simple checksum for profile change detection.
No WoW API dependencies — the easiest first test target.

**Tests needed:**
- Returns `0` for `nil` data
- Returns string length for string data
- Returns sum of string-value lengths for table data
- Returns `0` for non-string/non-table data types

### 2. `HasData()` — Setup.lua:65-71
Validates whether profile data exists and is non-empty.

**Tests needed:**
- Returns `false` for `nil`
- Returns `false` for empty or whitespace-only strings
- Returns `false` for empty tables
- Returns `true` for non-empty strings and tables

### 3. `IsProfileUpdated()` — Setup.lua:74-83
Determines if a profile's data has changed since last install. Drives the
"red updated items" sidebar indicator — a bug here means users miss updates
or see false positives.

**Tests needed:**
- Returns `false` when `db` or `db.profiles` is nil
- Returns `false` when addon key isn't in profiles
- Returns `true` for legacy `true` entries (migration path)
- Returns `false` for table entries (per-spec data like BlizzardCDM)
- Returns `true` when checksum differs from stored value
- Returns `false` when checksum matches

### 4. `GetUpdatedProfiles()` — Setup.lua:86-95
Collects all addon keys whose data has changed since last install.

**Tests needed:**
- Returns empty table when no profiles exist
- Returns only keys where `IsProfileUpdated` returns true
- Excludes non-updated profiles

### 5. Variant mapping & resolution — Setup.lua:19-31 + Core.lua:57-83
The variant system (e.g. `Grid2_Colored` → `Grid2`) is used throughout
`LoadProfiles()` and `CompleteSetup()`. Incorrect mappings cause profiles
to silently not load.

**Tests needed:**
- Every variant key maps to the correct base addon
- `LoadProfiles()` skips base keys when a variant is present
- `LoadProfiles()` skips `manualSelectAddons` and adds them to `skipped`
- `LoadProfiles()` calls `SetupAddon` for always-available addons

### 6. `SetupAddon()` dispatcher — Setup.lua:9-16
Routes addon keys to handler functions. Missing/mismatched keys fail silently.

**Tests needed:**
- Calls the correct handler for each registered addon key
- Prints a warning for unregistered keys
- Passes `import` flag and varargs through correctly

### 7. `CompleteSetup()` — Setup.lua:50-63
Updates saved variables after a successful install. Bugs here corrupt state.

**Tests needed:**
- Stores checksum in `db.profiles[addonKey]`
- Also stores base addon key when a variant is used
- Sets `db.version` and `db.installedVersion`
- Initializes and sets `perChar[charKey].loaded = true`

### 8. Slash command dispatch — Core.lua:153-172
Normalizes input and routes to `KitnCommands`.

**Tests needed:**
- Empty input shows help text
- Known commands dispatch correctly
- Unknown commands print error message
- Input is lowercased and trimmed

### 9. Version parsing — Core.lua:5-13
Strips packager tokens and leading `v` prefix. Affects update detection.

**Tests needed:**
- Strips leading "v" from version strings
- Falls back to `X-Manual-Version` when version contains `@`
- Falls back to `"dev"` when both unavailable

---

## Medium-Priority Areas

| Area | Location | Reason |
|------|----------|--------|
| `GetCharKey()` | Core.lua:35-37 | Used for all per-character tracking |
| `IsAddOnEnabled()` | Core.lua:40-43 | Guards every profile load |
| `GetImportStatus()` | Installer.lua:47-53 | UI status display |
| `GetCDMSpecStatus()` | Installer.lua:56-65 | Per-spec data availability |
| `ResetContent()` | Installer.lua:400-416 | Clean state between pages |
| Individual setup handlers | Setup.lua:101-656 | Each addon's import/load paths |

---

## Suggested Test Structure

```
tests/
  mocks/
    wow_api.lua          -- Mock WoW API globals
    addon_apis.lua       -- Mock third-party addon APIs
  test_data_checksum.lua
  test_has_data.lua
  test_profile_updates.lua
  test_variant_mapping.lua
  test_setup_dispatcher.lua
  test_complete_setup.lua
  test_slash_commands.lua
  test_version_parsing.lua
  test_load_profiles.lua
```

## Key Takeaway

**Start with `DataChecksum`, `HasData`, `IsProfileUpdated`, and
`GetUpdatedProfiles`.** These are pure logic functions that:
- Drive profile update detection (the most subtle failure mode)
- Require no WoW API mocking
- Are where bugs would be hardest to notice (silent data issues)

After those, test the variant resolution and `LoadProfiles` flow to cover
the most complex branching logic in the codebase.
