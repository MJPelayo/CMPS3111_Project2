# CMPS3111 Programming Project 2 — BNF Graph Interpreter

**Final implementation:** `raylib-graphics` (terminal derivation and parse tree; Raylib graphical plots)  
**Course:** CMPS3111 Programming Languages  
**Compiler:** Zig **0.16.0**  
**Graphics:** Raylib 6.0.0 via `raylib-zig` 6.0.0  
**Platforms tested:** Ubuntu 24.04 and Windows 11  
**Submission deadline:** Thursday, 22 October 2026, before class (see official assignment).

## 1. What the program does

The interpreter displays the BNF grammar, reads a proposed sentence, validates its lexical and syntactic structure, and displays a **leftmost derivation**. For valid sentences, it can show a **terminal parse tree** and a **Raylib graphical output window**. For invalid sentences, it displays relevant errors and waits for **one Enter** before returning to the input prompt. Type uppercase `STOP` at the input prompt to terminate normally. Closing the graphics window returns control to the program.

**Selected FILL interpretation:** `fill c2` draws a **small filled green square centered at the coordinate intersection** `c2`, not a full-cell fill. This is the selected project's implementation of the assignment's less-specific “fill area starting at point” wording.

## 2. BNF grammar

```text
<graph> → start <plot_stmts> end
<plot_stmts> → <plot> | <plot> ; <plot_stmts>
<plot> → bar <x><y>,<y>
       | line <x><y>,<x><y>
       | grid <x><y>
       | fill <x><y>
<x> → a | b | c | d | e | f | g | h | i | j
<y> → 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
```

- `bar b4,2`: blue, unfilled bar outline, left top at `b4`, bottom at y=0, width 2 grid units.
- `line a1,f6`: red line between the two coordinate intersections.
- `grid e5`: black grid with axes extending through the specified coordinate range.
- `fill c2`: green filled point marker centered on the `c2` intersection.

The input may contain multiple plot commands separated by semicolons.

## 3. Files and dependency management

| File or directory | Purpose |
| --- | --- |
| `src/main.zig` | Input loop, BNF display, error handling and orchestration |
| `src/` (other `.zig` files) | Lexer, parsing, derivation, terminal parse tree, plotting and graphics modules |
| `build.zig` | Zig executable, Raylib module import, build and run steps |
| `build.zig.zon` | Dependency manifest and pinned Raylib Zig revision |
| `zig-pkg/` | Dependency source files included in this repository snapshot |
| `.zig-cache/`, `zig-out/` | Generated build artifacts; intentionally ignored by Git |

The project manifest specifies `raylib_zig` at revision `8758f4cd3a5ae0df6941c4715257223d34c5ad3e`, with package identity `raylib_zig-6.0.0-KE8RECZ8BQDm-txuospkpZHbJ6DNpacUF7D88RWQ_qAe`. **Do not substitute an arbitrary newer Zig or Raylib release** for this tested configuration.

The repository currently includes approximately 96 MB of `zig-pkg/` dependency sources (1,392 tracked files at the time of review). Their presence does **not** guarantee a fully offline build: dependency resolution and caches may still be needed. Use a network connection for the initial build if necessary.

## 4. Ubuntu 24.04 — installation and execution

### Prerequisites

1. Install **Zig 0.16.0**. In the tested Ubuntu environment its executable is `/opt/zig/zig`. If installed elsewhere, substitute the correct executable path.
2. Install Git and native graphics build prerequisites (package names for Ubuntu 24.04):

```bash
sudo apt update
sudo apt install -y git build-essential pkg-config \
  libgl1-mesa-dev libx11-dev libxrandr-dev \
  libxinerama-dev libxcursor-dev libxi-dev
```

3. Use a graphical desktop session with working OpenGL support.

### Obtain and run the project

```bash
git clone https://github.com/MJPelayo/CMPS3111_Project2.git
cd CMPS3111_Project2
# If main has not yet been updated, select the tested implementation:
git switch raylib-graphics
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

`zig version` must report **0.16.0**. A successful `zig build` can return without any output. After `main` is promoted, a new clone can build the default branch without switching.

## 5. Windows 11 — installation and execution

### Prerequisites

1. Install **Zig 0.16.0** and add the Zig executable directory to Windows `PATH`.
2. Install **Git for Windows** and ensure `git` is available in PowerShell.
3. Use a Windows desktop session with a working graphics driver and OpenGL support.
4. Internet access may be needed during dependency resolution. The test machine successfully built using Zig 0.16.0 and Git 2.52.0.windows.1; a separate Visual Studio installation was **not established as required** by these tests.

### Open PowerShell and configure UTF-8

**Important:** PowerShell's console code page may otherwise show corrupted BNF arrows and tree branches (`ΓåÆ`, etc.). In **each new terminal session** before running the program, enter:

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
```

These are **session-level settings**. They do not automatically persist when PowerShell is closed. A terminal font supporting Unicode box-drawing characters is also needed (Windows Terminal is recommended).

### Obtain, compile and run

```powershell
git clone https://github.com/MJPelayo/CMPS3111_Project2.git
cd CMPS3111_Project2
# Until main is updated:
git switch raylib-graphics
zig version
git --version
zig build
zig build run
```

If the folder already exists, use a fresh name, for example:

```powershell
git clone https://github.com/MJPelayo/CMPS3111_Project2.git CMPS3111_Project2_WindowsTest
cd CMPS3111_Project2_WindowsTest
git switch raylib-graphics
zig build
zig build run
```

The Windows 11 test machine compiled the project successfully, displayed the grammar, derivation and terminal parse tree, and reached the Raylib graphical-output stage. Verify the actual graphics window and normal return to the input loop on the presentation computer.

## 6. Demonstration and sample tests

**Valid combined sentence:**

```text
start bar b4,2;line a1,f6;fill c2;grid e5 end
```

Expected: leftmost derivation → prompt to display terminal parse tree → prompt to display Raylib graphical output. Choose `y` for each display. Close the Raylib window to continue.

**Invalid sentence:**

```text
ff
```

Expected: `INPUT INVALID`, an explanation such as `Unknown word "ff"`, and `Press Enter to continue...`. Press **Enter once**; the program must return to the input prompt. On some Windows terminals the earlier text may remain in scrollback rather than being erased; verify the new prompt, not only the old text.

**Empty input:** press Enter at the main input prompt; expect `The input cannot be empty.` Then press Enter once at the pause prompt and try again.

**Terminate:** type **`STOP`** (uppercase) at the main input prompt; expected: `Program terminated.`

## 7. Troubleshooting

| Symptom | Check / solution |
| --- | --- |
| `zig` not recognized | Install Zig 0.16.0, add it to `PATH`, reopen PowerShell; run `zig version`. |
| Wrong Zig version | Use 0.16.0; newer or older releases may have incompatible APIs. |
| `git clone` says destination exists | Use another folder name or open the existing repository; do not delete existing work. |
| BNF arrows show `ΓåÆ` or parse tree shows `Γö...` | Run the three UTF-8 PowerShell commands in §5 in the current session. |
| Raylib dependency resolution fails | Check network access, manifest integrity and Zig version; keep `build.zig.zon` unchanged. |
| Linux native graphics build errors | Install the Ubuntu packages in §4 and verify desktop/OpenGL support. |
| Graphical window does not open | Run on a graphical desktop; check GPU drivers and that no remote/headless terminal is being used. |
| Invalid input seems to stop the program | Use the verified input-handling commit `8009e8c` or later; press Enter **once** at the pause, then enter a new sentence. |
| Old error remains visible | The terminal may retain scrollback. Check whether a fresh `Enter an input string...` prompt has appeared. |

## 8. Reproducibility record

| Platform | Observed test result |
| --- | --- |
| Ubuntu 24.04 | Zig 0.16.0 build succeeded; derivation, parse tree and graphical plots observed; corrected invalid-input loop and STOP tested. |
| Windows 11 | Zig 0.16.0 build succeeded; grammar, derivation and parse tree observed; Windows UTF-8 console fix tested; corrected invalid-input loop and STOP tested. |

These results reflect the group's reported tests, not an independent clean-room verification on the lecturer's machine. Test the submission ZIP on the intended presentation machine before class.


## 9. Repository and branch policy

Repository: https://github.com/MJPelayo/CMPS3111_Project2

`raylib-graphics` is the selected final implementation. Other implementations remain available on separate branches for comparison and backup. Merge the verified `raylib-graphics` branch into `main` only after the documentation and code are committed and checked.