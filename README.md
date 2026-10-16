# CMPS3111 Project 2 — Full Raylib Graphics

**Branch:** `raylib-full-graphics`  
**Language:** Zig 0.16.0  
**Presentation platform:** Ubuntu Linux  
**Group:** Group 4

## Overview

This version implements a small BNF-based graph-command interpreter. It validates user input, prints a leftmost derivation in the terminal, optionally opens a **Raylib graphical parse-tree viewer**, and optionally opens a **separate Raylib graphical-output window**. Closing either graphical window returns control to the terminal; uppercase `STOP` ends the input loop.

This branch builds on the completed `raylib-graphics` (point-fill) version. The original BAR, LINE, GRID, and point-based FILL behavior is retained.

## BNF Grammar

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

The grammar supports one or more plot statements separated by semicolons. The coordinate syntax uses a lowercase letter from `a` to `j` followed by one digit from `0` to `9`.

## Requirements

- Ubuntu Linux with a working desktop graphical session (X11 and OpenGL support for Raylib)
- Zig **0.16.0** (tested installation path: `/opt/zig/zig`)
- The project's Zig build files and existing Raylib Zig dependency
- Recommended font: DejaVu Sans (`/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`); the viewer includes a fallback font path

## Build and Run

From the repository root:

```bash
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

The version command should print `0.16.0`. A successful build may finish without any messages.

## Program Workflow

1. Display the BNF grammar and request an input sentence in the terminal.
2. Validate and parse the sentence. Invalid input produces diagnostics rather than a plot.
3. Display the leftmost derivation for a valid sentence.
4. Ask `Display parse tree? (yes/no):`. Answer `y` to open the **first Raylib window**.
5. Inspect the graphical parse tree, then close its window to return to the terminal.
6. Ask `Display graphical output? (yes/no):`. Answer `y` to open the **second Raylib window**.
7. Inspect the plot panels, then close the window to return to the program loop.
8. Enter uppercase `STOP` at the input prompt to terminate normally.

The two graphical windows open **sequentially**, not simultaneously. Selecting `no` skips the corresponding window without ending the program.

## Leftmost Derivation

The terminal derivation starts with `<graph>` and shows successive **leftmost** nonterminal expansions using `⇒` and vertical progression arrows `↓`. The repeated `<graph>` at the left of displayed steps is a visual reference label, not an additional grammar expansion.

Example input:

```text
start line a1,f6 end
```

## Window 1 — Graphical BNF Parse Tree

The first Raylib window shows a connected, top-down parse tree with the correct grammar structure:

- `<graph>` expands into `start`, `<plot_stmts>`, and `end`.
- Each `<plot_stmts>` expands to `<plot>` or `<plot> ; <plot_stmts>`.
- Each `<plot>` expands into its command terminal and the corresponding coordinate nonterminals, punctuation, and terminal values.
- `<x>` and `<y>` appear as separate nonterminal nodes above their actual letter or digit values.

### Viewer Interface

The viewer uses color-coded rounded nodes, connecting lines, a legend, an input-string panel, and a parsed-structure summary. Its typography uses a TrueType font when available for better readability. The layout is intended to remain navigable for longer recursive parse trees.

### Controls

| Action | Control |
|---|---|
| Zoom tree | Mouse wheel while hovering over the tree area |
| Pan tree | Left-click and drag inside the tree area |
| Reset view | `R` |
| Fullscreen toggle | `F11` |
| Resize / maximize / minimize | Standard Ubuntu window controls |
| Close viewer | Window `X` button |

Closing this window returns to the terminal; it does **not** terminate the application.

## Window 2 — Graphical Plot Output

The second Raylib window displays plot panels in input order. Each panel title includes its graph number, command type, and exact command arguments.

| Command | Example | Graphical behavior |
|---|---|---|
| BAR | `bar b4,2` | Thick blue, unfilled bar outline starting at `b`, height `4`, width `2` grid intervals |
| LINE | `line a1,f6` | Red line connecting the exact `a1` and `f6` grid intersections |
| GRID | `grid e5` | Black grid retaining the original width-to-`e` and height-to-`5` behavior |
| FILL | `fill c2` | Green square, smaller than a grid cell, centered on the exact `c2` intersection |

**Coordinate labeling:** This branch uses grid-line-aligned X and Y labels for all four plot types, including point-based FILL. The separate `raylib-fill-cell` branch instead fills an entire cell and centers FILL's labels within cells.

## Sample Inputs

Single commands:

```text
start bar b4,2 end
start line a1,f6 end
start grid e5 end
start fill c2 end
```

Multiple commands:

```text
start bar b4,2;line a1,f6;fill c2;grid e5 end
```

A longer recursive input:

```text
start fill a0;fill b1;fill c2;fill d3;fill e4;fill f5;fill g6;fill h7;fill j9 end
```

Try invalid commands and coordinates as part of testing, such as `start banana a1 end`, `start line a1,f6`, or `start fill z2 end`.

## Source Organization

| File | Role |
|---|---|
| `src/main.zig` | Terminal input loop, prompts, validation flow, and opening the two windows |
| `src/grammar.zig` | BNF grammar display |
| `src/lexer.zig` | Lexical processing |
| `src/parser.zig` | Parsing and syntax validation |
| `src/derivation.zig` | Leftmost derivation |
| `src/parse_tree.zig` | Terminal parse-tree logic retained from earlier implementations |
| `src/parse_tree_graphics.zig` | Graphical parse-tree viewer, node layout, font, zoom, and pan |
| `src/graphics.zig` | Raylib graphical plot output |
| `src/plot.zig` | Plot and Graph data structures |

The repository also includes `build.zig` and `build.zig.zon` for building and dependencies.

## Presentation Testing Checklist

- [ ] Compile successfully with `/opt/zig/zig build`
- [ ] Test a single plot and multiple recursive plots
- [ ] Verify the leftmost derivation
- [ ] Verify all parse-tree grammar symbols and parent-child connections
- [ ] Check the font and compact tree layout
- [ ] Test mouse zoom, panning, reset, maximize, and F11 fullscreen
- [ ] Close the parse-tree window and confirm the graphical-output question appears
- [ ] Verify BAR, LINE, GRID, and point-based FILL render correctly
- [ ] Close the graphical-output window and confirm the terminal loop continues
- [ ] Confirm uppercase `STOP` terminates normally

## Git Branches

| Branch | Purpose |
|---|---|
| `terminal-graphics` | Terminal-only backup implementation |
| `raylib-fill-cell` | Raylib output with full-cell FILL |
| `raylib-graphics` | Raylib output with point-based FILL and terminal parse tree |
| `raylib-full-graphics` | This version: graphical parse tree and separate graphical plot window |
| `main` | Final selection pending group and lecturer review |

## Build Artifacts

`.gitignore` excludes generated Zig build output:

```gitignore
.zig-cache/
zig-out/
```

These directories are regenerated during compilation and should not be committed. Keep source files, build scripts, and dependency information in version control.

---

**CMPS3111 Project 2 — Group 4**  
**Implementation:** Full Raylib graphical parse tree + point-fill plot renderer  
**Branch:** `raylib-full-graphics`