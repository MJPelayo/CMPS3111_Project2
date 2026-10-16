# CMPS3111 Project 2 — Raylib Graphical Output (Cell Fill)

**Branch:** `raylib-fill-cell`  
**Language:** Zig 0.16.0  
**Environment:** Ubuntu Linux, Raylib  
**Project:** BNF Grammar, Leftmost Derivation, Parse Tree, and Graphical Output

## Overview

This branch implements CMPS3111 Project 2 using Zig and Raylib. It validates a small graph-command language defined by BNF, shows a leftmost derivation, optionally displays a terminal parse tree, and optionally opens a Raylib window containing numbered graphical plots.

**This branch's distinguishing feature is cell-based FILL:** `fill c2` colors the entire grid cell labeled column `c`, row `2`. Unlike the point-fill alternative, it does not draw a small square centered at a grid-line intersection. The cell-based X and Y labels are centered alongside their respective cells.

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

Each accepted sentence starts with `start`, ends with `end`, and contains one or more plot statements separated by semicolons.

## Graphical Commands

| Command | Example | Behavior | Color | Coordinate labels |
|---|---|---|---|---|
| BAR | `bar b4,2` | Draws an unfilled bar starting at column `b`, height `4`, width `2` grid intervals; thick outline, no internal blue divider | Blue | At grid lines |
| LINE | `line a1,f6` | Connects the exact coordinate intersections `a1` and `f6` with a line and endpoint markers | Red | At grid lines |
| FILL | `fill c2` | Colors the **entire single cell** identified by `c2` | Green | **Centered on cells** |
| GRID | `grid e5` | Displays a grid from `a` to `e` and from `0` to `5`, preserving the existing grid dimensions | Black | At grid lines |

### Important coordinate distinction

BAR, LINE, and GRID use the original **point/grid-line coordinate system**. For these plots, letters sit directly below vertical grid lines and numbers align with horizontal grid lines.

FILL uses a separate **cell coordinate system**. Letters are centered below the corresponding columns, and numbers are centered beside the corresponding rows. This separate rendering logic prevents changes to FILL from shifting the other plots.

The only intended behavioral difference from `raylib-graphics` (the point-fill alternative) is how the FILL command is drawn and labeled.

## Graph Titles and Plot Order

Each panel shows the plot type, its exact input, and its sequential graph number. For example:

```text
BAR b4,2 - Graph 1
LINE a1,f6 - Graph 2
FILL c2 - Graph 3
GRID e5 - Graph 4
```

Multiple plots appear in input order, left to right and then top to bottom. Repeated commands (for example, four BAR commands) receive distinct graph numbers.

## Requirements

- Zig **0.16.0** (the tested version on the Ubuntu laptop)
- Ubuntu Linux with the system graphics libraries required by the project's Raylib build
- Project source, `build.zig`, `build.zig.zon`, and the Raylib dependency files used by the build
- A terminal with UTF-8 support for derivation and parse-tree symbols

The Zig executable used on the presentation laptop is `/opt/zig/zig`. VS Code may have a different Zig version on its PATH, so use the explicit path below.

## Build and Run

From the repository root, switch to the appropriate branch and build:

```bash
git switch raylib-fill-cell
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

A successful `zig build` can return to the prompt without any output.

### Example input

```text
start bar b4,2;line a1,f6;fill c2;grid e5 end
```

For a valid input, the program displays the leftmost derivation, asks whether to show the parse tree, and then asks whether to display graphical output. Answer `y` or `yes` to view the corresponding output.

The Raylib window is separate from the terminal. Closing it should return control to the program, not terminate the application. Use uppercase `STOP` at the input prompt to terminate normally.

## Leftmost Derivation and Parse Tree

The derivation expands the leftmost remaining nonterminal at each step. It displays downward arrows and the derivation symbol `⇒`, with `<graph>` repeated as a visual reference label.

The terminal parse tree uses connected, indented branches. It preserves the recursive rule `<plot_stmts> → <plot> ; <plot_stmts>` for multiple plot commands, and each `<plot>` expands into the terminal command and coordinate nonterminals required by the BNF.

## Project Structure

```text
CMPS3111_Project2/
├── .gitignore
├── README.md
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig           # Main program and input loop
│   ├── grammar.zig        # BNF display
│   ├── lexer.zig          # Lexical analysis
│   ├── parser.zig         # Parsing and syntax validation
│   ├── derivation.zig     # Leftmost derivation
│   ├── parse_tree.zig     # Terminal parse tree
│   ├── plot.zig           # Plot data types
│   └── graphics.zig       # Raylib renderer, cell-based FILL
└── tests/                 # Project tests (if present)
```

## Suggested Test Cases

| Purpose | Input |
|---|---|
| Single bar | `start bar b4,2 end` |
| Single line | `start line a1,f6 end` |
| Single fill | `start fill c2 end` |
| Single grid | `start grid e5 end` |
| Mixed commands | `start bar b4,2;line a1,f6;fill c2;grid e5 end` |
| Multiple fills | `start fill a0;fill b1;fill c2;fill d3;fill e4;fill f5;fill g6;fill h7;fill j9 end` |
| Invalid command | `start banana a1 end` |
| Missing end | `start fill c2` |

### Presentation verification checklist

- [ ] Project builds with Zig 0.16.0
- [ ] BAR has a blue, thick, unfilled outline and correct height/width
- [ ] LINE starts and ends at the exact grid-line intersections
- [ ] GRID uses black lines and retains the original dimensions and grid-line labels
- [ ] FILL colors exactly one complete green cell
- [ ] FILL's X and Y labels are centered on cells, independently of other plot labels
- [ ] Graph titles show the exact commands and numbering in input order
- [ ] The parse tree and derivation remain correct for multiple plots
- [ ] Closing the Raylib window returns to the input loop
- [ ] Uppercase `STOP` terminates normally

## Branches and Version Selection

- `terminal-graphics` — terminal-based plotting implementation
- `raylib-graphics` — Raylib graphical plotting with **point-based FILL**
- **`raylib-fill-cell`** — Raylib graphical plotting with **cell-based FILL** (this branch)
- `main` — final implementation to be selected by the group after review

The group and lecturer can compare the two FILL interpretations before deciding which version to use for the final presentation. No branch selection is implied by this README.

## Git Build Artifacts

Zig's generated `.zig-cache/` and `zig-out/` directories should be ignored by Git. They can be recreated by running `/opt/zig/zig build`. Keep the source and build configuration files under version control.

---

**Course:** CMPS3111 — Programming Project 2  
**Group:** Group 4  
**README version:** Cell-fill branch documentation