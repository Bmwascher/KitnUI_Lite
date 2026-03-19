# Changelog

## v2.2.0
- UUF: Added Healer Colored and Healer Dark profiles
- UUF: Choosing Colored or Dark now installs both DPS and Healer profiles in one click
- UUF: Install and load activate the correct profile based on current spec
- Grid2/UUF: Fixed load path not activating DPS profile for non-healer classes/specs
- Updated Blizzard Edit Mode and Ayije CDM Healer profile strings
- Moved installer textures to Media/Textures folder

## v2.1.0
- Grid2: Added Healer Colored and Healer Dark profiles
- Grid2: Choosing Colored or Dark now installs both DPS and Healer profiles in one click
- Grid2: Automatic per-spec profile switching (DPS specs use DPS profile, healer specs use healer profile)
- Grid2: Switching styles (Colored <-> Dark) properly clears the old style
- Fixed installer button layout issues when navigating between pages (ResetContent now resets all button positions and sizes)

## v2.0.1
- Updated README

## v2.0.0
- Ayije CDM: 1-click import of all profiles (base, CastEmphasized, Healer, Healer DualResource)
- Ayije CDM: Automatic per-spec profile switching via AceDB specProfiles
- Ayije CDM: No longer requires manual variant selection in the installer
- Added `/kitn cdm` slash command to open the installer directly to the Blizzard CDM page
- Added first-time install welcome popup prompting new users to open the installer
- Blizzard CDM reminder after `/kitn load` now points to `/kitn cdm`
- Updated profile data for Ayije CDM and Blizzard CDM

## v1.0.6
- Fixed `/kitn load` overwriting UUF personal customizations (now activates existing profile instead of re-importing)

## v1.0.5
- Fixed Plater profile import causing oversized nameplates (bypassed ImportAndSwitchProfile with direct SavedVariables write)

## v1.0.4
- Fixed Plater requiring two installs for correct sizing

## v1.0.3
- Fixed profile update detection (checksum-based change tracking)
- Fixed UUF profile resetting on load
- Updated profile data

## v1.0.2
- Added KitnEssentials addon support
- Updated profile data for multiple addons
- Media path updates

## v1.0.1
- Updated profiles for UUF, Ayije CDM, and BigWigs

## v1.0.0
- Initial release
- Step-by-step profile installer with sidebar navigation
- Supported addons: Blizzard Edit Mode, Unhalted Unit Frames, Grid2, Details, Plater, BigWigs, WarpDeplete, Ayije CDM, Chattynator, MRT, BasicMinimap, Minimap Stats, Blizzard CDM
- Colored/Dark variants for Unit Frames and Grid2
- Square/Circle variants for BasicMinimap and Minimap Stats
- Per-spec layouts for Blizzard CDM
- One-click profile loading for alt characters (/kitn load)
- Auto-detection of new characters with load prompt
- Version update detection with installer prompt
