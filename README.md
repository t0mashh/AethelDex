# ⚡ AethelDex v1.0 (PRO 2026)

**AethelDex v1.0** — Next-Generation In-Game DataModel Hierarchy Explorer, Properties Inspector, Script Viewer, and Network Debugger for Roblox.

A ground-up, high-performance re-engineering of the legendary **Dark Dex**, rebuilt for the modern 2026 engine specifications, strictly typed in Luau (`--!strict`), optimized for 500,000+ instances with virtualized scrolling, and fully compatible with both Desktop and Mobile / Touch platforms.

---

## 🚀 Quick Start (One-Line Loadstring)

Execute this one-liner in your environment to run AethelDex instantly:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/AethelDex/main/AethelDex.luau"))()
```

*(Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username once pushed!)*

Or load directly from a local file in Studio / executor:
```lua
loadstring(readfile("AethelDex.luau"))()
```

---

## ✨ Features

### 🌲 1. High-Performance Virtualized Explorer
* **O(1) Virtual Windowing**: Uses a recycled pool of ~35 UI rows. Handles **1,000,000+ instances** with flat memory overhead and stable 60–144 FPS.
* **Instant Prefix Search**:
  * `c:RemoteEvent` — filter by ClassName.
  * `p:Anchored=false` — filter by Property value.
  * `t:Interactable` — filter by CollectionService tag.
  * Standard text search by Instance Name or ClassName.
* **Selection Model**: Multi-selection, parent jumping, and hierarchy expansion.

### ⚙️ 2. Dynamic 2026 Properties Inspector
* **Live Reflection**: Detects properties dynamically using in-engine reflection and categorized fallbacks.
* **Full 2026 Types**: Supports `buffer`, `CFrame` matrix editing, `Font` (vector families), `Color3`, `UDim2`, `Vector3`, `ColorSequence`, `NumberSequence`, and `EnumItem`.
* **Inline Editable**: Edit properties directly with type validation, error indicators, and live commit.

### 📡 3. Next-Gen Remote Spy
* Logs incoming and outgoing calls for `RemoteEvent`, `RemoteFunction`, and `UnreliableRemoteEvent`.
* **Code Generator**: Generates ready-to-run copy-pasteable Luau scripts:
  ```lua
  game:GetService("ReplicatedStorage").Events.GiveCoins:FireServer("Gold", 100)
  ```
* Call counter, timestamping, and argument inspection.

### 📜 4. Script Viewer & Decompiler
* Syntax-highlighted viewer for `LocalScript`, `ModuleScript`, and `Script`.
* Seamless integration with native environment `decompile(script)` and `.Source`.
* One-click "Copy Code" to clipboard.

### 👻 5. Nil Instances Scanner
* Dedicated inspector for instances parented to `nil` (`getnilinstances()`).
* Restore orphaned instances back to `Workspace` with one click.

### 🎨 6. Fluent 2026 Design & Mobile Touch
* **Fluent Design**: Modern obsidian palette, subtle borders (`UIStroke`), rounded corners (`UICorner`), and Roblox Studio 2026 vector icons.
* **Spotlight Command Palette**: Press `Ctrl+K` (or `Cmd+K`) to open the instant command bar.
* **Adaptive Mobile Mode**: Automatic touch detection with enlarged 44×44px hitboxes, draggable floating toggle button, and swipe gestures.
* **Stealth Mounting**: Uses `gethui()`, `syn.protect_gui()`, or `CoreGui` to protect the UI from in-game script detection.

---

## ⌨️ Keybindings

| Key | Action |
|---|---|
| **F8** | Toggle AethelDex visibility |
| **Ctrl + K** | Open Command Palette (Spotlight switcher) |
| **Esc** | Close Command Palette |

---

## 📁 Project Architecture

```
├── AethelDex.luau         # Ready-to-run compiled standalone bundle (86 KB)
├── build/
│   └── bundle.ps1        # Automated build script that packs src/ into AethelDex.luau
├── src/
│   ├── Main.luau         # Master orchestrator & lifecycle entrypoint
│   ├── Core/
│   │   ├── Config.luau   # User settings & keybindings
│   │   ├── Janitor.luau  # Connection cleaner & memory leak prevention
│   │   ├── SafeHost.luau # Stealth mounting (gethui / CoreGui)
│   │   ├── Scheduler.luau# Frame-budgeted non-blocking task runner
│   │   └── Signal.luau   # Linked-list Signal implementation
│   ├── Reflection/
│   │   ├── ReflectionEngine.luau # In-engine property reflection
│   │   ├── Serializers.luau      # Luau type parser & stringifier
│   │   └── TypeDefinitions.luau  # Strict Luau types
│   ├── Tree/
│   │   ├── SearchEngine.luau     # Prefix search engine
│   │   ├── TreeState.luau        # Hierarchy state & expansion map
│   │   └── VirtualList.luau      # Virtualized windowing engine
│   ├── Tools/
│   │   ├── NilScanner.luau       # getnilinstances inspector
│   │   ├── PropertiesView.luau   # Real-time properties inspector
│   │   ├── RemoteSpy.luau        # Network traffic monitor & code generator
│   │   └── ScriptViewer.luau     # Decompiler & syntax viewer
│   └── UI/
│       ├── CommandPalette.luau   # Ctrl+K modal
│       ├── Icons.luau            # Studio 2026 icon mapping
│       ├── Theme.luau            # Design tokens & color system
│       ├── TouchEngine.luau      # Mobile touch support
│       └── WindowManager.luau    # Draggable & dockable window manager
```

---

## 🔨 How to Build / Modify

1. Make any edits to the modular files inside `src/`.
2. Run the PowerShell bundle script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\build\bundle.ps1
   ```
3. `AethelDex.luau` will be automatically recompiled and ready for distribution!

---

## 📤 Publishing to GitHub

To publish this project to GitHub:

```bash
git init
git add .
git commit -m "feat: initial release of AethelDex v1.0.0-PRO"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/AethelDex.git
git push -u origin main
```

Once pushed, anyone can load it via:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/AethelDex/main/AethelDex.luau"))()
```

---

## 📄 License
MIT License. Created for advanced Roblox game developers, security researchers, and UI/UX designers.
