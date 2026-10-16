# CMPS3111 Programming Project 2

## Terminal Graphics Branch --- Group 4

**Branch:** `terminal-graphics`\
**Language:** Zig 0.16.0\
**Platform used for development and presentation:** Ubuntu Linux\
**Project:** BNF Grammar, Leftmost Derivation, Parse Tree, and Terminal
Graphical Output

## Overview

This branch implements a small interpreter for a graph-command language
defined by a Backus--Naur Form (BNF) grammar. The program accepts an
input sentence, checks its lexical and syntactic validity, displays a
leftmost derivation for accepted sentences, optionally displays a parse
tree, and optionally renders the plot commands directly in the terminal.

This version does **not** need a separate Raylib graphical window. It is
maintained as an independent, terminal-only implementation for
demonstration and backup.

## BNF Grammar

``` text
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

The input begins with `start`, contains one or more plot commands
separated by semicolons, and ends with `end`. Each coordinate contains a
lowercase letter from `a` through `j` followed immediately by one digit
from `0` through `9`.

## Requirements

-   Ubuntu Linux or another environment supported by the Zig build
    configuration
-   **Zig 0.16.0** (the version used for successful testing)
-   A terminal with UTF-8 support for arrows and tree-drawing characters
-   The project source files and its build configuration

On the Ubuntu presentation laptop, Zig 0.16.0 is available at
`/opt/zig/zig`. The `zig` command on `PATH` may point to a different
version, so use the explicit path below when testing.

## Build and Run

From the project root:

``` bash
/opt/zig/zig version
/opt/zig/zig build
/opt/zig/zig build run
```

The first command should print `0.16.0`. A successful `zig build` may
return to the shell without printing anything.

## Program Workflow

1.  Display the BNF grammar and prompt for an input sentence.
2.  If the input is exactly `STOP`, terminate normally.
3.  Check for empty input and incorrectly capitalized versions of
    `STOP`.
4.  Tokenize the sentence and collect lexical diagnostics.
5.  Parse the tokens and report syntax errors when necessary.
6.  For valid input, display the **leftmost derivation**.
7.  Ask `Display parse tree? (yes/no):`.
8.  If selected, show the connected, indented parse tree in the
    terminal.
9.  Ask `Display graphical output? (yes/no):`.
10. If selected, render the graph commands in the terminal.
11. Display acceptance feedback, then wait for **Enter**.
12. Clear the terminal and return to the BNF input prompt.

The prompts accept `yes`, `y`, `no`, or `n` without regard to case. Only
uppercase `STOP` is accepted as the termination command.

## Leftmost Derivation

The display shows `<graph>` at the top and repeats `<graph>` as a
**visual reference label** beside the derivation steps, with `↓`
indicating progression and `⇒` indicating derivation. The repeated label
does not mean the grammar symbol `<graph>` is expanded again at every
step.

Example input:

``` text
start line a1,f6 end
```

Example display:

``` text
<graph>
   ↓
<graph> ⇒ start <plot_stmts> end
   ↓
<graph> ⇒ start <plot> end
   ↓
<graph> ⇒ start line <x><y>,<x><y> end
   ↓
<graph> ⇒ start line a<y>,<x><y> end
   ↓
<graph> ⇒ start line a1,<x><y> end
   ↓
<graph> ⇒ start line a1,f<y> end
   ↓
<graph> ⇒ start line a1,f6 end
```

## Parse Tree

The terminal parse tree uses Unicode box-drawing characters (`├──`, `│`,
and `└──`). Its connectors are indented to make each parent-child
relationship easier to follow. Recursive plot statements preserve the
exact grammar production:

``` text
<plot_stmts> → <plot> ; <plot_stmts>
```

For multiple plots, each recursive `<plot_stmts>` contains its own
`<plot>`, optional semicolon, and following `<plot_stmts>`. The final
statement expands to `<plot>` only.

## Terminal Plot Commands

  Command   Input form     Terminal rendering
  --------- -------------- -----------------------------------------
  BAR       `bar b4,2`     Text-based bar/rectangle
  LINE      `line a1,f6`   Text-based line between two coordinates
  GRID      `grid e5`      Bounded grid representation
  FILL      `fill c3`      Filled area/marker representation

The program renders multiple plot commands in their input order and
labels the outputs by plot number.

## Example Inputs

**Single plots**

``` text
start bar b4,2 end
start line a1,f6 end
start grid e5 end
start fill c3 end
```

**Multiple plots**

``` text
start bar b4,2;line a1,f6;fill c3 end
```

**Nine plots (recursive-statement stress test)**

``` text
start fill a0;fill b1;fill c2;fill d3;fill e4;fill f5;fill g6;fill h7;fill j9 end
```

**Invalid examples**

``` text
start banana a1,5 end
start bar a 1,5 end
start bar a1, 5 end
start line a1,f6
stop
```

These examples exercise unknown words, coordinate spacing, comma
spacing, missing grammar elements, and the uppercase termination rule.

## Source Code Organization

``` text
CMPS3111_Project2/
├── .gitignore
├── README.md
├── build.zig
├── build.zig.zon
└── src/
    ├── main.zig
    ├── grammar.zig
    ├── lexer.zig
    ├── parser.zig
    ├── derivation.zig
    ├── parse_tree.zig
    ├── plot.zig
    └── terminal_graphics.zig
```

  -----------------------------------------------------------------------
  File                                Responsibility
  ----------------------------------- -----------------------------------
  `main.zig`                          Main input loop, prompts, feedback,
                                      and control flow

  `grammar.zig`                       BNF grammar display

  `lexer.zig`                         Tokenization and lexical
                                      diagnostics

  `parser.zig`                        Grammar validation and plot-data
                                      construction

  `derivation.zig`                    Leftmost derivation display

  `parse_tree.zig`                    Connected terminal parse tree

  `plot.zig`                          Plot and graph data structures

  `terminal_graphics.zig`             Terminal rendering of BAR, LINE,
                                      GRID, and FILL
  -----------------------------------------------------------------------

## Testing Checklist

-   [ ] Compile with Zig 0.16.0
-   [ ] Test each of the four plot commands
-   [ ] Verify leftmost derivation for a single plot
-   [ ] Verify recursive derivation for multiple plots
-   [ ] Verify parse-tree connections and indentation
-   [ ] Verify terminal graphics output
-   [ ] Test invalid words, characters, coordinates, and syntax
-   [ ] Test nine plot commands
-   [ ] Confirm Enter clears the terminal and repeats the program
-   [ ] Confirm uppercase `STOP` terminates normally

**Note:** The checklist is intended for a fresh checkout or presentation
rehearsal. Previous tests on the Ubuntu laptop confirmed successful
compilation and demonstrated derivation and parse-tree output; run the
remaining checks before presenting.

## Git and Build Artifacts

The `.gitignore` file excludes generated artifacts:

``` gitignore
.zig-cache/
zig-out/
```

These folders are recreated by Zig when needed and should not be
committed. Keep the source files, build configuration, and any required
dependency files in the repository.

## Branch Strategy

-   `terminal-graphics` --- terminal-only implementation and backup
-   `raylib-graphics` --- terminal derivation/tree with Raylib plot
    output
-   `raylib-full-graphics` --- planned graphical parse-tree and
    plot-window implementation

The group will compare the implementations before selecting one to merge
into `main`.

## Group and Submission

**Course:** CMPS3111 --- Programming Project 2\
**Group:** Group 4

The branch-specific README accompanies the source code. The project
report and presentation are separate submission materials and should
describe the final selected implementation accurately.