# CMPS3111 Programming Project 2 — Graphical Interpreter

**Group 4 — University of Belize**  
**Status:** Updated graphical interpreter on the `main` branch (commit `5b78034`); continue final regression and cross-platform checks before submission.  
**Programming language:** Zig 0.16.0  
**Graphics:** Raylib 6.0.0 through `raylib-zig` 6.0.0  
**Live demonstration environment:** Ubuntu 24.04 LTS  
**Other supported test environment:** Windows 11

**Repository:** https://github.com/MJPelayo/CMPS3111_Project2

## 1. Project purpose

The project implements a small graph-plotting language defined using Backus–Naur Form (BNF). The program displays its grammar, performs lexical and syntax validation, prints a leftmost derivation for valid input, optionally displays a terminal parse tree, and optionally opens a Raylib window to visualize the graphical commands. Invalid input is reported so the user can try again. Enter uppercase `STOP` to terminate.

One valid input sentence produces **one shared graph**. Drawing commands execute in the order in which they appear in the sentence.

## 2. Software and dependencies

| Software | Version | Purpose |
| --- | --- | --- |
| Zig | **0.16.0** | Programming language and compiler |
| Raylib | **6.0.0** | Graphics window, rendering, and drawing functions |
| `raylib-zig` | **6.0.0** | Zig bindings and build integration for Raylib |
| Git | Git for Windows or Linux Git | Cloning and updating the repository |
| Ubuntu | **24.04 LTS** | Linux development, compilation, and demonstration |
| Windows | **11** | Windows development and testing |
| Visual Studio Code | No particular version required | Code editor (optional; not required to compile) |

**Dependency configuration:** The project declares its Raylib Zig dependency in `build.zig.zon` and integrates it through `build.zig`. These configuration files are included in the repository. There is no separate “README package” to install: `README.md` is documentation. The repository's dependency files and build configuration should be retained.

**Version warning:** The official project build uses **Zig 0.16.0**. VS Code's separately managed compiler or language server may use a different version and report editor diagnostics. Check compilation using the correct compiler before treating such diagnostics as actual build failures.

## 3. Installation, compilation, and execution

Use the **`main` branch** for the current group version.

### 3.1 Ubuntu 24.04 LTS

Install Git and the native libraries needed by the existing Raylib build:

```bash
sudo apt update
sudo apt install -y git build-essential pkg-config \
  libgl1-mesa-dev libx11-dev libxrandr-dev \
  libxinerama-dev libxcursor-dev libxi-dev
```

Install **Zig 0.16.0**. On the project owner's Ubuntu laptop, the executable is located at `/opt/zig/zig`; on another machine, adjust the path to wherever Zig 0.16.0 is installed.

Clone the repository **from a directory outside any existing copy of the project**:

```bash
git clone https://github.com/MJPelayo/CMPS3111_Project2.git
cd CMPS3111_Project2
git switch main
```

Confirm the compiler version, compile, and run:

```bash
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

The version command should print `0.16.0`. If Zig 0.16.0 is available on your `PATH` as `zig`, the equivalent commands are `zig build` and `zig build run`.

To update an existing clone without cloning a second copy:

```bash
git switch main
git pull --ff-only origin main
```

### 3.2 Windows 11

Install **Zig 0.16.0** and **Git for Windows**, and add Zig to the system `PATH`. Open PowerShell in the directory where you wish to clone the repository:

```powershell
git clone https://github.com/MJPelayo/CMPS3111_Project2.git
cd CMPS3111_Project2
git switch main
zig version
zig build
zig build run
```

`zig version` should print `0.16.0`.

For correct rendering of the BNF arrows and terminal parse-tree characters in PowerShell, use UTF-8:

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
```

If necessary, run the UTF-8 setup **before** `zig build run`.

**Testing note:** Ubuntu compilation of the updated `main` branch has been confirmed. The latest graphical revision should still be compiled and visually checked on Windows 11 before claiming the final version has passed cross-platform testing.

## 4. BNF grammar (unchanged)

```text
<graph> → start <plot_stmts> end

<plot_stmts> → <plot>
             | <plot> ; <plot_stmts>

<plot> → bar <x><y>,<y>
       | line <x><y>,<x><y>
       | grid <x><y>
       | fill <x><y>

<x> → a | b | c | d | e | f | g | h | i | j

<y> → 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
```

A valid graph starts with `start`, ends with `end`, and contains at least one plot command. Multiple plot commands are separated by semicolons (`;`). Coordinates use a lowercase letter from `a` through `j` followed by a single digit from `0` through `9`.

## 5. Final graphical command behavior

Commands in one sentence render on **one shared coordinate system** and execute **in source order**. Existing shapes and regions remain visible as later commands are applied.

### 5.1 BAR — lecturer-confirmed geometry

**Syntax:** `bar <x><y>,<y>`

The command contains **three separate values**: the starting X letter, the first Y digit representing the **height**, and the second Y digit representing the **horizontal width**. A BAR is a rectangle whose bottom is at **Y = 0**.

For example, `bar b4,2` produces:

- Bottom-left: **B0**
- Top-left: **B4**
- Bottom-right: **D0**
- Top-right: **D4**

It has a blue outline and an initially unfilled interior; a subsequent FILL command can color that interior. This geometry was **explicitly confirmed by Mr. Garcia**.

**Additional example:** `bar a1,9` has a height of **1** and extends horizontally from **A to J**. It does **not** mean nine vertically stacked cells.

### 5.2 LINE

**Syntax:** `line <x><y>,<x><y>`

A LINE connects its two specified coordinates with a **finite red segment**. For example, `line a1,f6` draws a red line from **A1** to **F6**, without visually continuing past F6. Multiple LINE commands add more segments to the shared graph.

### 5.3 GRID — lecturer-confirmed appearance

**Syntax:** `grid <x><y>`

GRID draws **only the X-axis and Y-axis** with coordinate ticks and labels. It must **not display internal horizontal or vertical grid lines**, as explicitly instructed by Mr. Garcia.

The updated renderer uses **adaptive coordinate extents**. For example, `grid f4` shows the X-axis through **F** and the Y-axis through **4** when no other command reaches farther. If other BAR or LINE commands require a larger extent, the graph expands to include them rather than hiding their endpoints. The extent policy is **our design choice**, not an explicit lecturer requirement.

### 5.4 FILL — lecturer-confirmed purpose and documented implementation

**Syntax:** `fill <x><y>`

 FILL as a standard graphics fill function applying color to **the interior of a shape or bounded area**. The coordinate in `fill c2` is a **seed point** at C2; it does **not** specify the width and height of a green square.

The renderer fills a connected region of currently available pixels in **green**, respecting already drawn BAR outlines, LINE segments, axes, and the visible plotting area's edges. A line can divide a bounded region, so FILL colors only the connected portion containing the given seed.

Examples:

| Input | Expected graphical result |
| --- | --- |
| `start bar b4,2;fill c2 end` | Green interior of the blue BAR, while its outline remains blue |
| `start bar b4,2;line a1,f6;fill c2 end` | Green only in the part of the BAR containing C2, below the red line |
| `start line a1,f6;fill c2 end` | With no farther-reaching shapes or GRID, adaptive bounds end at F6; C2 fills the region below the line |
| `start grid j9;fill c2 end` | Green available plotting background; the black axes remain visible |
| `start fill c2 end` | With no other shapes or GRID, the default visible plotting area is filled green |



## 6. Raylib interface and graphical workflow

One valid sentence produces **one Raylib window containing one shared graph**, rather than separate panels for each plot command. The interface includes:

- A readable header and application title.
- The coordinate plot, including axis labels and tick marks, but no internal grid lines.
- A legend distinguishing BAR (blue), LINE (red), FILL (green), and GRID (black axes).
- A session summary with command counts and fill results.
- A list of the first seven commands in the order executed, with indication when additional commands are present.
- A system font when available, and a window intended to support resizing/maximizing where the operating system's window manager allows it.

Closing the Raylib window returns control to the terminal input loop.

## 7. Program processing sequence

1. Display the original BNF grammar.
2. Prompt the user for an input sentence, or uppercase `STOP` to terminate.
3. Check termination and empty-input cases.
4. Perform lexical analysis and report invalid words, coordinates, or characters.
5. Perform syntax analysis according to the BNF grammar.
6. For valid input, print the **leftmost derivation**.
7. Ask whether to display the **terminal parse tree**.
8. Ask whether to display **graphical output**.
9. Build the parsed graph representation; when requested, execute commands in order on the shared Raylib canvas.
10. Close the Raylib window to return to the input loop; if no graphical window was opened, use the terminal Enter-to-continue prompt.

The `STOP` termination command must be uppercase. Invalid input produces an explanatory error and allows another attempt.

## 8. Source-code overview

| File | Role |
| --- | --- |
| `src/main.zig` | Program entry point, console input loop, prompts, error reporting, and integration |
| `src/grammar.zig` | Displays the BNF grammar |
| `src/lexer.zig` | Tokenization and lexical diagnostics |
| `src/parser.zig` | Grammar validation and conversion to plot data |
| `src/derivation.zig` | Leftmost derivation output |
| `src/parse_tree.zig` | Terminal parse-tree output |
| `src/plot.zig` | Plot command / graph data structures |
| `src/graphics.zig` | Shared Raylib graph, BAR/LINE/GRID drawing, FILL behavior, legend, and session summary |
| `build.zig` and `build.zig.zon` | Build configuration and Raylib Zig dependency |

## 9. Regression test cases

Run each input separately after starting the interpreter with `zig build run` or `/opt/zig/zig build run`.

| Input | Expected result |
| --- | --- |
| `start bar b4,2 end` | Blue BAR outline from B0 to D4 |
| `start bar b4,2;fill c2 end` | Green BAR interior, blue outline retained |
| `start line a1,f6 end` | Red finite A1-to-F6 segment |
| `start line a1,f6;fill c2 end` | Green below red segment on adaptive A–F, 0–6 plot |
| `start grid f4 end` | X through F, Y through 4; axes only |
| `start grid j9;fill c2 end` | Green connected plotting background with visible black axes |
| `start bar b4,2;line a1,f6;fill c2 end` | Green lower portion of BAR, upper portion unfilled |
| `start bar b4,2;bar f6,2;fill c2;fill g3 end` | Two blue BARs, with the corresponding seeded interiors filled |
| `start bar b4,2;fill c2;bar b4,2 end` | Green BAR interior remains after its blue outline is redrawn |
| `start line a1,f6;line d9,h2;fill c2 end` | Larger adaptive extent; FILL respects actual connected regions and open boundaries |

Also test these invalid or control inputs:

| Input | Expected behavior |
| --- | --- |
| `start circle a2 end` | Unknown-command/invalid-word error |
| `start bar k4,2 end` | Invalid coordinate error |
| `start line a1 f6 end` | Missing-comma or syntax error |
| `start fill c10 end` | Invalid coordinate error |
| `start bar b4,2; end` | Syntax error after semicolon |
| `stop` | Incorrect termination capitalization error |
| `STOP` | Program terminates normally |

Test both `yes/no` (or `y/n`) prompts, close the graphics window, and confirm the interpreter accepts another input.

