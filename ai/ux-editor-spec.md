# SuperCollider iOS — UX Spec v2

> Status: PROPOSAL — for review before implementation
> Inspired by: Apple Pages (iOS + iPadOS)
> Date: 2026-03-16
> Mockups: See Pencil Desktop canvas (14 screens)

---

## Architecture Overview

The app has three layers:

1. **Document Browser** — home screen, Pages-style with hero card + slide-up file sheet
2. **Editor** — pushed on top, Read Mode (default) or Edit Mode
3. **Global Overlays** — Post Window, Settings, Recording Playback (accessible from anywhere)

No tab bar in the editor. The document browser IS the navigation root.

---

## 1. Document Browser (App Launch)

### Layout (Mockups: Screens 1, 10)

**Background**: Dark gradient (deep purple → navy → dark blue)

**Hero Card** (floating, rounded corners, frosted glass):
- App title "SuperCollider" (large, bold)
- Subtitle "Audio synthesis on iOS"
- **[Choose a Template]** — orange accent button, full width
- **[Start Coding]** — secondary outlined button, full width

**File Sheet** (slides up from bottom, draggable):
- Drag handle at top
- Top-right icons: Settings (gear), New (+), More (...), Search (magnifying glass)
- File grid with code preview thumbnails (syntax-highlighted first ~8 lines)
- Each card shows: filename, date, file size
- Long-press for: Rename, Duplicate, Move, Share, Delete

**Bottom Tab Bar** (inside the sheet):
- **Scripts** — .scd file grid with code previews
- **Recordings** — list of audio recordings with waveform icons
- **Browse** — file system browser (folders, iCloud)

### Implementation Options
- Custom SwiftUI implementation matching Pages pattern
- OR wrap `UIDocumentBrowserViewController` for native behavior
- Register `.scd` as a document type the app owns

---

## 2. Templates (Mockup: Screen 5)

### Presented as Sheet from "Choose a Template"

Cancel button top-left, scrollable categorized grid:

| Category | Templates |
|----------|-----------|
| **Getting Started** | Tutorial, First Synth |
| **Synthesis** | SynthDef, FM Synth, Granular, Subtractive |
| **Patterns & Sequencing** | Pbind, Live Coding (Ndef) |
| **Effects** | Reverb Chain, Delay/Loop |
| **Blank** | Empty .scd |

Each template card:
- Colored icon (category-specific)
- Title (bold)
- 1-2 line description
- Tap → creates new .scd from template → opens in Editor (Edit mode)

---

## 3. Editor: Read Mode (Mockups: Screens 2, 8, 11)

### Default when opening a file

**Nav Bar**:
```
[< Documents]     filename.scd     [Edit pencil-icon]
```

**Transport Toolbar**:
```
[Play] [Stop] [Record] [Post-icon]     [green-dot] 3% 2s
```

- Play = green circle (idle) or orange (playing)
- Stop = red circle
- Record = gray circle with red dot
- Post = terminal icon, opens Post Window overlay
- Right side: server status (green dot, CPU%, synth count)

**Code Area**:
- Syntax-highlighted, **not editable**
- Smooth scrolling (no accidental edits)
- No cursor, no keyboard

### Gestures (Read Mode)
| Gesture | Action |
|---------|--------|
| Long-press | Select enclosing code block (bracket-matched) |
| 2-finger tap | Evaluate selected block |
| 3-finger tap | Stop all sound (CmdPeriod) |
| Hold + drag on number | Value Scrub (see Section 6) |

### Evaluate Feedback
1. Selected block gets brief **blue highlight** (0.3s)
2. **Toast bar** at bottom: green for success ("Synth created — Simple drone"), red for errors
3. Toast auto-dismisses after 2 seconds

### Gesture Hints Bar (bottom of screen, dismissible)
```
Long-press        2-finger tap       3-finger tap
Select block      Evaluate           Stop all
```

---

## 4. Editor: Edit Mode (Mockup: Screen 3)

### Activated by tapping "Edit" pill button

**Nav Bar**:
```
[Done]     filename.scd     [Undo] [Redo]
```

- "Done" = blue pill button, returns to Read mode
- Undo/Redo = arrow icons (blue when available, dimmed when not)

**Transport Toolbar**: Same as Read mode (Play/Stop/Record/Post always available)

**Code Area**:
- Full text editing, keyboard visible
- Blinking cursor
- All gestures still work (evaluate, stop, block selection)
- Auto-saves on mode switch (Edit → Read)

### Mode Switching
- **Read → Edit**: Tap "Edit" pill, or double-tap code
- **Edit → Read**: Tap "Done", or swipe down to dismiss keyboard
- **Setting**: "Always open in Edit mode" toggle in Settings

### Visual Difference
- Read: no cursor, Edit pill visible, toolbar normal
- Edit: cursor blinking, Done button (blue), undo/redo visible, keyboard up

---

## 5. Post Window (Mockups: Screens 4, 8, 11, 12)

### What It Is
SuperCollider's **Post window** — the canonical SC term. Shows sclang output: boot messages, compilation results, evaluated code output, synth creation confirmations, errors, recording status. Session-scoped, not document-scoped.

### Access
- **Terminal icon** in the transport toolbar (next to Play/Stop/Record)
- Available from any editor screen, regardless of which document is open
- Opens as a **full-screen overlay** (Sheet presentation)

### Post Window Overlay (Screen 12)
```
Post Window              Copy  Clear  [X]
─────────────────────────────────────────
=== SuperCollider for iOS ===
Booting audio engine...
Audio engine running
compiling class library...
    Found 719 primitives.
    compiled 334 files in 0.23 seconds
compile done
Server connected
*** Welcome to SuperCollider 3.15.0-dev ***
Ready! Select code and tap Evaluate.

> { var sig = Mix([ SinOsc.ar(110,...
-> Synth('temp__0' : 1001)

Recording...
path: Documents/Recordings/06-Ambient_260316_154840.wav
Recording saved
stopped
```

### Color Coding
- Green: success messages (boot, compile, connected, ready, saved)
- Orange: evaluated code (prefixed with >)
- White/gray: sclang output, results
- Red: errors, recording status
- Dim gray: verbose output (primitives, method count)

### Actions
- **Copy**: copies entire post content to clipboard
- **Clear**: clears post history
- **X**: dismisses overlay, returns to editor

### Collapsed Post Bar (Alternative — Screen 8)
A single-line bar at the bottom of the editor showing the last post output line. Swipe up to expand to full Post Window. This provides quick feedback without leaving the editor.

```
[terminal-icon] Ready! Select code and tap Evaluate.  [chevron-up]
```

---

## 6. Value Scrub (Mockup: Screen 6)

### Concept
In Read Mode, hold-and-drag on numeric values to adjust them without switching to Edit Mode. This is a performance-oriented feature for live tweaking.

### Interaction Flow

1. **Tap-and-hold** a number in the code (e.g., `440`, `0.15`)
2. Number highlights with orange accent background + up/down arrow indicator
3. Toolbar shows orange "Scrubbing" badge
4. **Drag up/down** to change value:
   - **1-finger drag** = fine adjustment (+/- 1 for integers, +/- 0.01 for floats)
   - **2-finger drag** = coarse adjustment (+/- 10 or +/- 0.1)
5. **Floating popup** appears near the value showing:
   - Current value (large, orange)
   - Original value ("was 110")
   - Range slider (min/max for the value type)
   - Speed hint ("1-finger: fine" / "2-finger: coarse")
6. **On release**: value stays changed in code, synth keeps playing with old value
7. **Action bar** appears at bottom:
   - **[Apply & Re-evaluate]** — orange button, re-evaluates the enclosing block with new value
   - **[Revert]** — outlined button, restores original value

### Value Type Detection
| Pattern | Type | Fine Step | Coarse Step | Range |
|---------|------|-----------|-------------|-------|
| Integer (e.g., `440`) | Frequency | +/- 1 Hz | +/- 10 Hz | 20–20000 |
| Float 0-1 (e.g., `0.15`) | Amplitude/Mix | +/- 0.01 | +/- 0.1 | 0.0–1.0 |
| Float > 1 (e.g., `2.5`) | Time/Ratio | +/- 0.1 | +/- 1.0 | 0.0–30.0 |

### Settings
- "Value Scrub in Read mode" toggle (default ON)

---

## 7. Recordings (Mockups: Screens 0, 10, 13)

### Recording Flow
1. Tap Record button in transport toolbar
2. Record button pulses red, toolbar shows "REC" indicator
3. Audio output is captured to WAV file
4. Tap Record again (or Stop) to end recording
5. File saved to `Documents/Recordings/`

### File Naming Convention
```
{PatchName}_{YYMMDD}_{HHMMSS}.wav
```
Examples:
- `06-Ambient_260316_154840.wav` (recorded from 06-Ambient.scd)
- `scratch_260316_161639.wav` (recorded from scratch.scd)
- `Untitled_260316_170000.wav` (no file open)

The patch name comes from `AppState.currentFile`. This creates clear correlation between recordings and their source patches.

### Recordings Tab (Document Browser — Screen 10)
Recordings are a separate content type from .scd scripts. They appear in their own tab in the document browser:

**Scripts** | **Recordings** | Browse

Each recording row shows:
- Waveform icon (red)
- Filename (with patch name prefix)
- Metadata: file size, duration, date/time
- Share button (right side)
- Swipe actions: Share, Delete

### Recording Playback (Screen 13)
Tapping a recording opens a playback sheet:

**Header**:
- Recording name (bold)
- Metadata: size, format (WAV 48kHz), date
- "From: 06-Ambient.scd" link (tappable — opens the source .scd file)

**Waveform Visualizer**:
- Orange bars for played portion, gray for remaining
- White playhead line
- Time labels: elapsed / remaining

**Controls**:
- Skip back / Play-Pause / Skip forward
- Large orange play/pause button (centered)

**Action Bar**:
- Share (AirDrop, Messages, etc.)
- Open In (other audio apps)
- Delete

### Storage
- Recordings save to `Documents/Recordings/` (separate from `Documents/Scripts/`)
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` enabled so recordings appear in Files app under "On My iPhone > SCiOSTest"
- NOT mixed with .scd files in the Scripts tab

---

## 8. Settings (Mockup: Screen 7)

### Access
Gear icon in the document browser header (top-left of file sheet).
Presented as a modal sheet over the document browser.

### Sections

**SERVER**
| Setting | Value |
|---------|-------|
| Sample Rate | 48000 Hz (read-only) |
| Block Size | 64 (read-only) |
| Output Channels | 2 (read-only) |

**EDITOR**
| Setting | Default | Description |
|---------|---------|-------------|
| Always open in Edit mode | OFF | Skip Read mode, go straight to editing |
| Value Scrub in Read mode | ON | Enable hold-drag number editing |
| Auto-load SynthDefs | ON | Evaluate SynthDef blocks when opening files |
| Font Size | 14pt | Code editor font size |

**GESTURES** (reference, not editable)
| Gesture | Action |
|---------|--------|
| Long-press | Select block |
| 2-finger tap | Evaluate |
| 3-finger tap | Stop all |
| Hold + drag on number | Value scrub |

**ACTIONS**
- Recompile Class Library (blue)
- Clear Post Window (blue)
- Stop All Sound (red/destructive)

---

## 9. Navigation Flow

```
App Launch
  → Document Browser (hero card + file sheet)
    │
    ├─ [Choose a Template] → Template Picker (sheet)
    │   └─ Tap template → New .scd created → Editor (Edit mode)
    │
    ├─ [Start Coding] → New blank .scd → Editor (Edit mode)
    │
    ├─ Scripts tab → Tap .scd file → Editor (Read mode)
    │   ├─ Long-press → select block → 2-finger tap → evaluate
    │   ├─ Hold number → value scrub → Apply & Re-evaluate
    │   ├─ Tap Edit → Edit mode → type code → Done → Read mode
    │   ├─ Tap Post icon → Post Window (overlay)
    │   ├─ Tap Record → recording → Tap Record → stop
    │   └─ Tap < Documents → Document Browser
    │
    ├─ Recordings tab → list of .wav files
    │   └─ Tap recording → Playback sheet (waveform + controls)
    │       ├─ Play/Pause/Seek
    │       ├─ Share / Open In / Delete
    │       └─ "From: patch.scd" → opens source file
    │
    ├─ Settings (gear icon) → Settings sheet
    │
    └─ Search (magnifying glass) → search .scd files by name
```

---

## 10. iPad Considerations

### Same Document Browser
iPad uses the exact same layout as iPhone — Apple's document browser pattern scales automatically. The file sheet fills more space but the interaction is identical.

### Editor
- Same Read/Edit mode toggle
- Same toolbar layout (more room for icons)
- Keyboard shortcuts with external keyboard:
  - `Cmd+Return` — evaluate selection
  - `Cmd+.` — stop all
  - `Cmd+E` — toggle Edit mode
  - `Cmd+K` — clear post
- Post Window: could be a side panel on iPad instead of full overlay

### No Sidebar
The Pages model has no persistent sidebar. The document browser IS the navigation root. Tap "< Documents" to go back. This is simpler and more consistent across devices.

---

## 11. Resolved Design Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Post: tab or panel? | Terminal icon → full overlay | Post is session-scoped, not document-scoped. Overlay keeps it accessible from any editor screen without tabs. |
| Recordings: mixed or separate? | Separate tab in document browser | Different content type (audio output vs source code). Own tab, own folder. |
| Recording names? | `{PatchName}_{timestamp}.wav` | Creates correlation between recordings and source patches. |
| Recording playback? | In-app waveform player | Quick audition without leaving app. Share/Open In for full editing. |
| Server tab? | Eliminated | Status in toolbar, settings in Settings sheet, actions in Settings. |
| Where does Settings live? | Gear icon in document browser | Accessible from home screen, not buried in tabs. |
| Value Scrub: Read or Edit mode? | Read mode | Performance-oriented: tweak values without keyboard. |

---

## 12. Implementation Priority

### Phase 1: Core Navigation
1. Document browser (hero card + file sheet + Scripts/Recordings/Browse tabs)
2. Read/Edit mode toggle
3. Transport toolbar with Post icon
4. Post Window as overlay

### Phase 2: Polish
5. Templates (template picker sheet)
6. Evaluate feedback (block highlight + toast)
7. Recording naming (`PatchName_timestamp.wav`)
8. Recording playback (waveform player sheet)

### Phase 3: Advanced
9. Value Scrub gesture
10. Settings sheet (replacing Server tab)
11. iPad layout refinements
12. iCloud Drive support

---

## 13. Mockup Index

| Screen | Name | Key Features |
|--------|------|-------------|
| 0 | Files Tab (current app) | Recordings section with share/delete |
| 1 | Document Browser v1 | Pages-style hero + file grid (dark, 2-column) |
| 2 | Editor — Read Mode | Back button, Edit pill, transport, syntax code, block selection, toast, gesture hints |
| 3 | Editor — Edit Mode | Done button, undo/redo, cursor, keyboard |
| 4 | Read Mode + Post Panel | Pull-up panel over dimmed code |
| 5 | Template Picker | Categorized grid with colored icons |
| 6 | Value Scrub | Orange number highlight, floating popup, Apply/Revert bar |
| 7 | Settings Sheet | Server, Editor, Gestures, Actions sections |
| 8 | Editor + Post Bar | Collapsed single-line post bar at bottom |
| 10 | Document Browser v2 | Recordings tab selected, settings icon, 3-tab nav |
| 11 | Editor + Post Icon | Terminal icon in transport toolbar |
| 12 | Post Window (overlay) | Full-screen post with color-coded output |
| 13 | Recording Playback | Waveform visualizer, play/pause, share/delete |
