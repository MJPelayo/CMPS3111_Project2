# CMPS3111 Project 2 — Raylib Graphics (Point Fill)

**Branch:** `raylib-graphics`  
**Implementation:** Zig 0.16.0 and Raylib  
**Group:** Group 4

## Overview

This branch implements a BNF-based plotting language. The application reads a plotting statement, validates its syntax, displays a leftmost derivation, optionally prints a connected parse tree in the terminal, and optionally opens a Raylib window to display the plots. Closing the graphics window returns control to the application rather than ending the input loop.

**The distinguishing behavior of this branch is point-based FILL:** `fill c2` draws a small green square centered on the intersection of column `c` and row `2`. This differs from the `raylib-fill-cell` branch, which colors a complete grid cell and uses cell-centered labels.

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

A valid input starts with `start`, contains one or more plot commands separated by semicolons, and ends with `end`.

## Graphical Commands

| Command | Example | Expected display |
|---|---|---|
| BAR | `bar b4,2` | A thick blue, unfilled outline starting at column `b`, reaching height `4`, and spanning width `2` grid intervals. No interior blue divider. |
| LINE | `line a1,f6` | A red line joining the exact coordinate intersections `a1` and `f6`, with endpoint markers. |
| FILL | `fill c2` | A green square smaller than one grid cell, centered at the `c2` intersection. |
| GRID | `grid e5` | A black coordinate grid extending through `e` horizontally and `5` vertically, preserving the original grid behavior. |

### Coordinate labels

In **this point-fill branch**, all four commands use grid-line coordinates:

- X-axis letters are centered **under their corresponding vertical grid lines**, not between lines.
- Y-axis numbers align **with their corresponding horizontal grid lines**, not between lines.
- FILL's square is centered at the intersection, rather than centered inside a cell.

### Titles and panel layout

Each plot has a title showing the exact input and its sequence number, for example:

```text
BAR b4,2 - Graph 1
LINE a1,f6 - Graph 2
FILL c2 - Graph 3
GRID e5 - Graph 4
```

Plots are displayed in the order entered, with multiple panels arranged in the Raylib window.

## Requirements

- Zig **0.16.0** (the version used on the Ubuntu development laptop)
- Raylib dependency as configured in the project
- Ubuntu Linux graphical desktop, or another compatible build environment
- A UTF-8 terminal for the derivation and parse-tree symbols

On the Ubuntu development laptop, Zig 0.16.0 is installed at `/opt/zig/zig`. The `zig` executable selected by VS Code may be a different version, so use the explicit path below.

## Build and Run

Open a terminal in the repository directory:

```bash
cd ~/Desktop/CMPS3111_Project2
git switch raylib-graphics
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

The version command should report `0.16.0`. A successful build may produce no terminal output.

## Example Session

Enter this input at the program prompt:

```text
start bar b4,2;line a1,f6;fill c2;grid e5 end
```

The program displays the leftmost derivation, then asks whether to show the parse tree and graphical output. Answer `y` to each prompt to inspect both. Close the Raylib window to return to the terminal flow. Continue testing additional inputs; enter uppercase `STOP` to terminate the program normally.

### Leftmost derivation and parse tree

- The leftmost derivation progresses downward using `↓` and `⇒`. A repeated `<graph>` at the left serves as a visual reference label.
- The parse tree is printed in the terminal with connected parent-child branches.
- Multiple plot commands use the recursive `<plot_stmts> → <plot> ; <plot_stmts>` production.

## Project Structure

```text
CMPS3111_Project2/
├── .gitignore
├── README.md
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig
│   ├── grammar.zig
│   ├── lexer.zig
│   ├── parser.zig
│   ├── derivation.zig
│   ├── parse_tree.zig
│   ├── plot.zig
│   └── graphics.zig
└── tests/
```

| File | Purpose |
|---|---|
| `main.zig` | Program input and output loop |
| `grammar.zig` | Displays BNF rules |
| `lexer.zig` | Tokenizes input |
| `parser.zig` | Validates grammar and parses commands |
| `derivation.zig` | Prints leftmost derivation |
| `parse_tree.zig` | Prints the terminal parse tree |
| `plot.zig` | Graph and plot data types |
| `graphics.zig` | Raylib window, panels, grid lines, plot rendering and point-fill marker |

## Testing Checklist

- [ ] Build using Zig 0.16.0
- [ ] Test BAR width and height, including no internal blue divider
- [ ] Test LINE endpoints at exact grid intersections
- [ ] Test FILL point marker at `c2` (not a whole cell)
- [ ] Test FILL at edge coordinates such as `a0` and `j9`
- [ ] Test GRID dimensions using `grid e5`
- [ ] Verify X and Y labels align with grid lines on every plot
- [ ] Verify each graph title reproduces the correct command and sequence number
- [ ] Test multiple plot commands in one input
- [ ] Verify parse tree and derivation
- [ ] Verify closing the Raylib window returns to the input loop
- [ ] Verify uppercase `STOP` exits normally

The checklist is for final rehearsal and fresh checkouts; checking an item requires actually running that test.

## Git and Branch Comparison

Generated Zig cache and build output should be excluded from Git tracking:

```gitignore
.zig-cache/
zig-out/
```

| Branch | Main distinction |
|---|---|
| `terminal-graphics` | Terminal-based graphics output |
| `raylib-graphics` | **This branch:** Raylib graphics with point-based FILL |
| `raylib-fill-cell` | Raylib graphics with full-cell FILL and cell-centered labels |
| `raylib-full-graphics` | Planned separate graphical parse-tree and plot windows |

The group and lecturer will review the alternatives before choosing which version to merge into `main`.

## Submission Notes

This README describes the **point-fill Raylib implementation only**. Reports and presentation slides should match the final selected branch and its verified behavior.