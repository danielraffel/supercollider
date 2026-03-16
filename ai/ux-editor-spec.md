# SuperCollider iOS — Editor & File UX Spec

> Status: PROPOSAL — for review before implementation
> Inspired by: Apple Pages, Xcode, SC IDE
> Date: 2026-03-16

---

## 1. App Launch: Document Browser (replacing current tab-based Files)

### Current Problem
Files are in a separate tab. Opening a file loads it into the editor on another tab. Feels disconnected — you browse in one place and work in another.

### Proposed: Pages-Style Document Browser
The app launches into a **document browser** (like Pages) showing:

**Top Section: Quick Actions**
- "New Script" (blank .scd)
- "Choose Template" → template picker (see §2)
- Last opened file (one-tap to resume)

**Bottom Section: File Grid/List**
- All .scd files in Documents/Scripts/
- Bundled examples in a separate section
- Grid view with code preview thumbnails (first few lines)
- Sort: recent, name, date
- Search bar
- Import button (Files app document picker)

**Tapping a file → opens it in the editor** (full screen, no tab switching)

**Back navigation**: Swipe back or tap "< Scripts" to return to browser

### Implementation
- Use SwiftUI `DocumentGroup` or custom `NavigationStack` with file list as root
- Remove the "Files" tab from iPhone tab bar
- iPad: sidebar shows file list, detail shows editor (current approach but refined)

---

## 2. Templates

### Template Categories
- **Blank**: Empty .scd file
- **Getting Started**: Tutorial with commented examples
- **SynthDef**: Template with SynthDef skeleton + .add
- **Pattern**: Pbind template with common parameters
- **Live Coding**: Ndef/ProxySpace template
- **FM Synthesis**: Multi-operator FM template
- **Granular**: GrainBuf template with parameters
- **Effects Chain**: Bus routing with reverb/delay/compression
- **MIDI Controller**: MIDIdef template for note/CC handling
- **OSC Receiver**: OSCdef template for receiving messages

### Template UX
- Grid of cards with title + brief description
- Tap → creates new file from template, opens in editor
- Templates stored as .scd files in app bundle

---

## 3. Read Mode vs Edit Mode

### Rationale
On a phone, accidental edits are common when scrolling code. A read-only mode lets you browse and evaluate code without risk of changing it.

### Two Modes

**Read Mode (default when opening a file)**
- Code is displayed with syntax highlighting
- Text is NOT editable (no keyboard, no cursor)
- Scrolling is smooth (no text selection interference)
- **Long-press** → select code block (same as now)
- **Two-finger tap** → evaluate selection
- **Three-finger tap** → stop all
- **Play button** → evaluate selection or all
- **Stop button** → stop all
- Toolbar shows: ▶ Stop | "Edit" button | file name

**Edit Mode (tap "Edit" button or pencil icon)**
- Full text editing enabled
- Keyboard available
- Undo/redo buttons in toolbar (like Pages)
- All gestures still work
- "Done" button to return to Read mode
- Auto-save on mode switch

### Mode Toggle
- Toolbar button: 📖 Read ↔ ✏️ Edit
- Setting: "Always open in Edit mode" (for power users)
- Double-tap anywhere in Read mode → switch to Edit at that position

### Visual Difference
- Read mode: slightly different background tint or top bar color
- Edit mode: standard dark background, cursor visible

---

## 4. Editor Toolbar (refined)

### Read Mode Toolbar
```
[< Back]  [file name]  [Edit ✏️]
[▶ Play] [■ Stop]     [0% 2s]
```

### Edit Mode Toolbar
```
[Done ✓]  [file name]  [Undo ↩] [Redo ↪]
[▶ Play] [■ Stop]     [0% 2s]
```

### Evaluate Feedback
When code is evaluated:
- Brief green flash on the selected block
- Post window auto-shows briefly as an overlay (toast-style) with the result
- Then fades back to editor

---

## 5. File Management

### In Document Browser
- Swipe to delete
- Long-press for context menu: Rename, Duplicate, Share, Delete
- Drag to reorder (optional)
- Pull-to-refresh

### In Editor
- Title bar shows file name (tappable to rename)
- "..." menu: Rename, Duplicate, Share, Move to folder
- Auto-save every 5 seconds while editing
- Unsaved indicator (dot on file name)

---

## 6. iPad Considerations

### Sidebar + Editor Layout
- Sidebar shows file list (always visible in landscape)
- Tapping a file opens in the main editor pane
- No need for separate document browser — sidebar IS the browser
- Read/Edit mode toggle in editor toolbar
- Post window: toggle-able bottom panel or right panel

### Multi-Window
- Each window can have a different file open
- Drag a file from sidebar to create new window (Stage Manager)

---

## 7. Navigation Flow

### iPhone
```
App Launch
  → Document Browser (file grid + templates)
    → Tap file → Editor (Read mode)
      → Tap Edit → Editor (Edit mode)
      → Tap ▶ → Evaluate (works in both modes)
      → Swipe back → Document Browser
    → Tap Template → New file → Editor (Edit mode)
    → Tab: Post | Server (still in tab bar, but Files tab replaced by being the root)
```

### iPad
```
App Launch
  → Sidebar (file list) + Editor (last file or welcome)
    → Tap file in sidebar → loads in editor
    → Read/Edit toggle in editor
    → Post: toggle-able panel
    → Server: in sidebar
```

---

## 8. Open Questions

1. Should "Post" be a persistent bottom bar/overlay rather than a separate tab?
   - Pros: Always visible, like a terminal
   - Cons: Takes screen space on iPhone

2. Should evaluating auto-switch to Read mode to prevent accidental edits?

3. Should we support iCloud Drive browsing directly, or just import?

4. Should templates auto-evaluate SynthDef blocks on open?
   (So patterns work immediately without manual evaluation)

5. Should the document browser show a "Running" indicator for files with active synths?

---

## 9. Priority Order

1. **Read/Edit mode toggle** — biggest UX win for phone users
2. **Document browser as launch screen** — better file flow
3. **Templates** — productivity boost
4. **Evaluate feedback** (green flash + toast) — satisfying interaction
5. **iPad sidebar refinement** — already close, just needs polish
6. **Auto-evaluate SynthDefs on file open** — reduces confusion
