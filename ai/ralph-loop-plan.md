# Ralph Loop Plan — SuperCollider iOS Port

## How to Launch

Run this from `/Users/danielraffel/Code/supercollider`:

```bash
/ralph-loop:ralph-loop "You are porting SuperCollider's scsynth audio engine to iOS.

GOVERNING RULES:
- The file ai/CLAUDE.md defines mandatory coding standards, architecture rules, and conventions.
- You MUST read ai/CLAUDE.md at the start of EVERY iteration.
- All code, tests, documentation, and commits MUST comply with ai/CLAUDE.md.
- Any violation of ai/CLAUDE.md is a bug and must be fixed.

SOURCE OF TRUTH:
- The file ai/work-items.md defines required features and phases.
- The file ai/IOS_PORT_PLAN.md contains the comprehensive architecture plan.
- The file ai/CODEX_REVIEW.md contains critical corrections validated against the real codebase.
- The file ai/CODEX_REVIEW_ACTIONS.md contains required fixes from the review.

TASK:
- Read ai/work-items.md at the start of EVERY iteration.
- Identify all work items that are:
  - NOT implemented, or
  - Partially implemented / incomplete.
- Implement ALL missing or incomplete items in the current codebase.
- Update work item status as you go ([ ] → [~] → [x])

TOOLS:
- Use RepoPrompt (window 3 = supercollider workspace) at EVERY step to validate changes against the real codebase before committing. Use context_builder for analysis, file_search for finding code, and apply_edits for changes.
- Use /xcodebuildmcp-cli for building and testing iOS targets.
- Use /codex for parallel work (tests, code review, independent components).
- Use Sosumi for iOS simulator testing when available.

RULES:
- Do NOT stop after implementing a subset.
- Do NOT assume a feature is complete without verifying the code builds and tests pass.
- If a feature requires tests, documentation, or build verification, it is NOT complete until those exist.
- Modify, refactor, or rewrite existing code if necessary.
- NEVER break the desktop macOS build. Test regression after every iOS change.
- NEVER use deprecated APIs in new code (AudioSession*, AUGraph, UIAccelerometer).
- NEVER use dlopen/dlsym in iOS code paths.
- Treat old SC_IPHONE code as REFERENCE ONLY — do not reuse as implementation base.

PRIORITIZATION & PHASE GATING RULE:
Within each iteration, the agent MUST:
1. Identify all incomplete items in the current phase.
2. Prioritize completing those items before starting any work in a later phase.
3. Fully implement, test, and verify each item before marking it complete.
4. Advance to the next phase when all current-phase items are marked [x] or will be addressed by a blocker.

Exception:
- If an item is blocked by a dependency that exists only in a later phase:
  - Explicitly document the dependency.
  - Mark the item as [~] or [!] with rationale.
  - Continue completing all other items in the current phase.

Phase advancement is allowed ONLY when:
- No unblocked items remain in the current phase.
- All required tests pass.
- Desktop macOS regression build passes.
- The phase has been explicitly verified as complete.

VALIDATION AT EVERY STEP:
Before marking ANY work item complete:
1. Use RepoPrompt context_builder to verify the change is correct in context
2. Build for iOS: cmake -B build-ios -DSC_IOS=ON && cmake --build build-ios --target libscsynth
3. Build for desktop: cmake -B build-desktop && cmake --build build-desktop --target libscsynth
4. Run any applicable tests
5. Check for memory leaks or thread issues if relevant

GIT DISCIPLINE:
- Commit at the end of EVERY iteration where changes were made.
- Commits must be small, focused, and aligned to features in ai/work-items.md.
- Commit messages must be imperative and follow ai/CLAUDE.md conventions.
- Do NOT commit if no meaningful progress was made.
- Stage specific files only — never git add -A or git add .

EACH ITERATION MUST:
1. Re-read ai/CLAUDE.md
2. Re-read ai/work-items.md
3. List remaining incomplete or missing items in current phase
4. Implement as many as possible
5. Verify against ai/CLAUDE.md
6. Build iOS target (if code changed)
7. Build desktop target (regression check)
8. Run tests (if applicable)
9. Commit changes (if any)
10. Update ai/work-items.md status
11. Re-check which items remain

COMPLETION CONDITION:
- ai/work-items.md contains ZERO unimplemented or incomplete items through Phase 5
- All features through Phase 5 are fully implemented and verified
- Tests pass on iOS simulator and desktop
- Code and commit history comply with ai/CLAUDE.md
- Desktop SuperCollider scripts can run their SynthDefs on iOS scsynth

ONLY WHEN ALL CONDITIONS ARE MET:
Output exactly: <promise>DONE</promise>

IF STUCK:
- After 20 iterations, document:
  - What is blocked
  - Why
  - What was attempted
  - What assumption may be wrong
- Write findings to ai/stuck-report.md
- Consider if the approach needs fundamental rethinking

CODEX DELEGATION (OPTIONAL):
- Use /codex <task> or codex exec --full-auto <task> for parallel work.
- Good candidates for Codex delegation:
  - Writing tests for code you just wrote
  - Implementing a component while you work on another
  - Code review of completed work items
  - Verifying desktop regression after iOS changes
- Do NOT delegate to Codex when:
  - The task depends on something you are currently building
  - Multiple agents would edit the same file
  - The task requires your current conversation context
- When delegating, run Codex in background and continue your work.
- Check Codex output before marking work item complete.

" --completion-promise "DONE" --max-iterations 70
```

## Files This Loop Reads and Modifies

### Reads Every Iteration
- `ai/CLAUDE.md` — coding standards and rules
- `ai/work-items.md` — task list and status
- `ai/IOS_PORT_PLAN.md` — architecture reference
- `ai/CODEX_REVIEW.md` — codebase validation findings
- `ai/CODEX_REVIEW_ACTIONS.md` — required corrections

### Modifies
- `ai/work-items.md` — updates status as items are completed
- `CMakeLists.txt` — adds SC_IOS option
- `server/scsynth/CMakeLists.txt` — iOS build config
- `server/plugins/CMakeLists.txt` — static plugin build
- `external_libraries/CMakeLists.txt` — dependency config
- `server/scsynth/SC_CoreAudio.h/cpp` — audio driver rewrite
- `server/scsynth/SC_Lib_Cintf.cpp` — static plugin loading
- `common/SC_VFP11.h` — arm64 guards
- Various new files (see CLAUDE.md new files list)

### Creates
- `server/scsynth/SC_iOSAudioSession.h/mm`
- `server/scsynth/SC_iOSLibSynth.h/cpp`
- `server/scsynth/SC_StaticPluginRegistry.cpp.in`
- `platform/iOS/build_xcframework.sh`
- `platform/iOS/TestApp/` (entire test app)
- `.github/workflows/build_ios.yml`
- `ai/phase0-findings.md` (Phase 0 output)

## Expected Duration

- **Phase 0**: ~2-3 iterations (investigation, no code changes)
- **Phase 1**: ~8-12 iterations (CMake changes, build fixes)
- **Phase 2**: ~6-10 iterations (plugin system rewrite)
- **Phase 3**: ~10-15 iterations (audio backend, most complex)
- **Phase 4**: ~5-8 iterations (API, packaging)
- **Phase 5**: ~10-15 iterations (test app, device validation)
- **Total**: ~41-63 iterations (within 70 max)

## Success Criteria

The loop is complete when:
1. `libscsynth.a` builds as a static library for iOS arm64
2. All core UGens are statically linked
3. Audio renders correctly via modern RemoteIO + AVAudioSession
4. Public C API allows creating/controlling the server
5. XCFramework packages device + simulator builds
6. Test app runs on iOS simulator with sine wave, polyphonic keyboard, sample playback, and mic input
7. Desktop macOS build has zero regressions
8. Pre-compiled SynthDefs from desktop SC play correctly on iOS
9. All tests pass
