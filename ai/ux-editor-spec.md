# SuperCollider iOS — Editor & File UX Spec

> Status: PROPOSAL — for review before implementation
> Inspired by: Apple Pages (iOS + iPadOS)
> Date: 2026-03-16

---

## Core Insight: Use Apple's Document Browser Pattern

Pages uses `UIDocumentBrowserViewController` which provides the **same UX on both iOS and iPadOS**:
- Half-sheet file browser on launch (draggable up/down)
- Recents / Shared / Browse tabs
- "Choose a Template" and "Start Writing" CTAs above the file list
- Grid or list view with thumbnails, search, sort
- Tap a file → opens full-screen editor
- Back button returns to browser

**We should use SwiftUI's `DocumentGroup` or wrap `UIDocumentBrowserViewController` to get this behavior for free.** No need to build a custom file browser — Apple's component handles iCloud, Recents, Browse, import, and the half-sheet presentation natively.

---

## 1. App Launch: Native Document Browser

### What the User Sees (identical on iPhone and iPad)

**Top Card (above the file sheet):**
```
    SuperCollider
  [Choose a Template]    ← orange/accent button
  [Start Coding]         ← secondary button (blank .scd)
```

**Bottom Sheet (native file browser, draggable):**
- Recents | Browse tabs (system-provided)
- Shows .scd and .sc files
- Grid view with code preview thumbnails
- Search, sort by name/date/size
- "+" button to create new
- Long-press for rename/duplicate/delete/share

### Implementation
- Use `DocumentGroup` in SwiftUI with a custom `UTType` for `.scd` files
- OR wrap `UIDocumentBrowserViewController` for more control
- Register `.scd` as a document type the app owns
- Templates presented as a sheet from "Choose a Template"

### Key Benefit
No custom file browser to maintain. Apple handles iCloud Drive, Recents, file import, AirDrop, share sheet — all for free.

---

## 2. Templates

### Presented From "Choose a Template" Button

Template picker appears as a sheet (like Pages). Categories:

| Category | Templates |
|----------|-----------|
| **Getting Started** | Tutorial, First Synth |
| **Synthesis** | SynthDef, FM, Granular, Subtractive, Additive |
| **Patterns** | Pbind, Pdef, Live Coding (Ndef) |
| **Effects** | Reverb Chain, Delay/Loop, Compressor |
| **MIDI/OSC** | MIDI Controller, OSC Receiver |
| **Blank** | Empty .scd |

Each template: card with title + 2-line description + code preview thumbnail.

Tap → creates new .scd file from template → opens in editor.

---

## 3. Editor: Read Mode vs Edit Mode

### Why This Matters on Touch Devices
On a phone, scrolling through code constantly triggers accidental edits. Pages solves this with a read-first approach where you must explicitly tap "Edit" to modify text.

For SC, Read mode is even more useful because you primarily **read and evaluate** code — not edit it. Most SC workflows are: open file → select block → evaluate → listen.

### Read Mode (Default When Opening a File)

```
┌──────────────────────────────────┐
│ [< Back]  filename.scd  [Edit ✏️]│
│ [▶ Play] [■ Stop]       0% 2s   │
├──────────────────────────────────┤
│                                  │
│  // SC code displayed here       │
│  // Syntax highlighted           │
│  // NOT editable                 │
│  // Scrolls smoothly             │
│                                  │
│  Long-press → select block       │
│  2-finger tap → evaluate         │
│  3-finger tap → stop all         │
│                                  │
└──────────────────────────────────┘
```

- Code displayed with syntax highlighting
- **Not editable** — no keyboard, no cursor, no accidental changes
- Smooth scrolling (no text selection interference with scroll)
- Long-press → select code block (bracket-matched)
- Two-finger tap → evaluate selection
- Three-finger tap → stop all
- Play/Stop buttons in toolbar work as now
- Evaluate from context menu works as now

### Edit Mode (Tap "Edit" or Pencil Icon)

```
┌──────────────────────────────────┐
│ [Done ✓] filename.scd [↩ Undo]  │
│ [▶ Play] [■ Stop]       0% 2s   │
├──────────────────────────────────┤
│                                  │
│  // SC code — EDITABLE           │
│  // Keyboard available           │
│  // Full text editing            │
│  // All gestures still work      │
│                                  │
└──────────────────────────────────┘
```

- Full text editing, keyboard visible
- Undo/Redo buttons in toolbar
- "Done" returns to Read mode
- Auto-saves on mode switch
- All evaluate/stop gestures still work

### Mode Switching
- **Read → Edit**: Tap "Edit ✏️" button, or double-tap code
- **Edit → Read**: Tap "Done ✓", or swipe down to dismiss keyboard + auto-switch
- **Setting**: "Always open in Edit mode" for power users

### Visual Difference
- Read mode: no cursor visible, slightly different toolbar tint
- Edit mode: cursor blinking, keyboard present, undo/redo visible

---

## 4. Toolbar Design

### Read Mode Toolbar
```
[< Back]           filename.scd           [Edit ✏️]
[▶ Play] [■ Stop]                         [● 0% 2s]
```

### Edit Mode Toolbar
```
[Done ✓]           filename.scd     [↩ Undo] [↪ Redo]
[▶ Play] [■ Stop]                         [● 0% 2s]
```

### Key Points
- Back button returns to document browser (same as Pages "< Documents")
- Filename tappable to rename (popover)
- Server status always visible (green dot + CPU + synth count)
- Play/Stop always accessible in both modes
- Edit mode adds Undo/Redo, replaces Edit button with Done

---

## 5. Evaluate Feedback

When code is evaluated:
1. Selected block gets a brief **green flash** (0.3s highlight)
2. Small **toast overlay** appears at bottom showing result or "Synth created"
3. Toast auto-dismisses after 2 seconds
4. If error: toast shows in red with error message

This gives immediate visual feedback that something happened.

---

## 6. Post Window

### Current: Separate Tab
Post is a separate tab on iPhone. You switch away from the editor to see it.

### Proposed: Toggle-able Bottom Panel
- Post appears as a **bottom panel** that can be pulled up from the bottom edge
- Drag handle at top of panel
- Collapsed: shows last line of output as a single-line bar
- Half-height: shows scrollable output
- Full-height: full post window
- Available in both Read and Edit modes
- Same on iPhone and iPad

### Alternative: Keep as Tab but Show Toasts
If the panel approach is too complex, keep Post as a tab but show evaluate results as toast overlays on the editor. User only switches to Post for full history.

---

## 7. iPad Considerations

### Same Document Browser
iPad uses the exact same `UIDocumentBrowserViewController` as iPhone — Apple scales it automatically. The file list fills more space but the interaction is identical.

### Editor
- Same Read/Edit mode toggle
- Same toolbar layout (more space for icons)
- Keyboard shortcuts work with external keyboard (⌘+Return, ⌘+., ⌘+K)
- Post window: could be a right-side panel instead of bottom panel

### No Sidebar
In the Pages model there is no persistent sidebar — the document browser IS the navigation root, and the editor is pushed on top of it. This is simpler and more consistent across devices.

If users want to switch files quickly, they tap "< Back" to return to the browser.

---

## 8. File Management

### In Document Browser (System-Provided)
- Swipe to delete
- Long-press for: Rename, Duplicate, Move, Share, Delete, Tags
- Drag and drop between folders
- iCloud Drive integration automatic
- AirDrop import/export automatic
- Search across all files

### In Editor (Custom)
- Tap filename in toolbar → rename popover
- "..." menu: Share, Duplicate, Move
- Auto-save every 5 seconds in Edit mode
- Unsaved changes indicator

---

## 9. Navigation Flow

```
App Launch
  → Document Browser (native, half-sheet on both platforms)
    → Tap "Choose a Template" → Template picker sheet
      → Tap template → New file created → Editor (Edit mode)
    → Tap "Start Coding" → New blank .scd → Editor (Edit mode)
    → Tap existing file → Editor (Read mode)
      → Long-press + 2-finger tap → Evaluate
      → Tap Edit → Edit mode → type code → Done → Read mode
      → Tap < Back → Document Browser
```

---

## 10. Open Questions

1. Should Post be a bottom panel or keep it as a tab?
2. Should evaluating in Read mode show a brief toast, or always require switching to Post?
3. Should we support "auto-evaluate SynthDefs on file open" so patterns work immediately?
4. Should the document browser show a "▶ Playing" badge on files with active synths?
5. Is `DocumentGroup` sufficient or do we need `UIDocumentBrowserViewController` for the half-sheet?

---

## 11. Priority Order

1. **Document browser** (native UIDocumentBrowserViewController) — replaces custom file tab
2. **Read/Edit mode toggle** — biggest UX improvement for phone
3. **Templates** — productivity boost
4. **Evaluate feedback** (green flash + toast) — satisfying interaction
5. **Post as bottom panel** — keeps context while evaluating
6. **Undo/Redo in toolbar** — essential for Edit mode
