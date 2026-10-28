# Retail first-play readiness

The user has only Retail installed and wants to test on Windows tomorrow. Preserve the separate Forever project, but prioritize a usable Retail path: login, normal account and character creation, visible hostile creatures, killing, loot, XP and persistence. These are acceptance criteria, not already observed outcomes.

Continue the native Windows architecture and fixed Retail core/client pins. The existing Mac preparation is not a Windows build. Obtain actual source and TDB, inspect their content, add a manually dispatched Windows build/test/package workflow, and simplify Windows setup, launcher preparation, account creation and diagnostics. Do not claim client gameplay without the matching real client. The launcher requires the user to accept its license and provide it; do not bypass that flow. Keep personal config and passwords out of packages and CI artifacts.

The first starter check is a normal human warrior in the traditional human area. Do not silently replace all race/class start choices. Detect missing world spawns, templates, loot and character-start data with database checks. Check client build before expensive work. A different retail build must be reported rather than relabeled.

Windows CI can build and import a disposable DB without a client, but cannot prove gameplay. A remote repository/Actions run is a separate execution choice because private Windows Actions may consume paid minutes. Prepare a concrete workflow before asking. No paid compute or public publication without explicit approval.
