# CMPS3111 Programming Project 2 — Graphical Interpreter

**Group 4 — University of Belize**  
**Status:** graphics-fix **review candidate**; compile and run all tests before merging into `main`.  
**Language:** Zig 0.16.0  
**Graphics:** Raylib 6.0.0 through `raylib-zig`  
**Live demonstration:** Ubuntu 24.04 (also retain Windows 11 compatibility)

## 1. Project purpose

The program implements a small BNF-based graph plotting language. It displays the grammar, checks lexical and syntax validity, prints a leftmost derivation, optionally prints a terminal parse tree, and optionally opens a Raylib window showing graphical commands. Invalid input is reported and the user can continue. Enter uppercase `STOP` to terminate.

## 2. BNF grammar (unchanged)

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

The `start` and `end` tokens enclose one or more plot commands, separated by `;`.

## 3. Confirmed lecturer guidance and graph rules

### BAR — lecturer-confirmed geometry

`bar b4,2` creates a rectangle with its **bottom at Y=0**, top-left at **B4**, bottom-left at **B0**, width **2** coordinate units, and top-right at **D4**. In the visualization, BAR has a **blue outline**; it need not be filled until a subsequent FILL command.

The syntax has **three separate values**: the X letter, first Y digit (height), and second Y digit (width). `bar a1,9` is a bar of height 1 extending horizontally from A to J (not nine stacked cells).

### LINE

`line a1,f6` draws the **red finite segment** connecting A1 to F6. It does not visually continue beyond F6. Multiple LINE commands draw additional segments on the same canvas.

### GRID — lecturer-confirmed appearance

GRID draws **only the X and Y axes**—**no internal grid lines**. The implementation uses the supplied coordinate as one contributor to the displayed axis extent: e.g., `grid f4` shows X through F and Y through 4 if there are no farther-reaching BAR/LINE commands. When more distant shapes are present, the graph expands to include them rather than hide their endpoints. This axis-extent policy is our **design choice**, not an explicit lecturer quote.

### FILL — lecturer-confirmed purpose; group-agreed edge policy

The lecturer described FILL as **a standard graphics fill operation applying color to the interior of a shape or bounded area**. `fill c2` provides the seed coordinate C2, *not* width/height. The renderer uses a four-direction connected-region fill of currently empty pixels, stopping at previously drawn BAR borders, LINE segments, axis lines and the **visible plot area's edges**. Fills are **green**.

- `bar b4,2;fill c2` — colors the bar interior.
- `bar b4,2;line a1,f6;fill c2` — colors only the portion of the bar containing C2, below the red line.
- `line a1,f6;fill c2` — with no GRID or other farther-reaching shapes, the visible graph ends at F6, so that segment reaches the upper-right edge and separates the graph. C2 colors the region below the line.
- `grid j9;fill c2` — with no other boundary, the fill colors the available plotting background, while axes remain visible.
- `fill c2` by itself — the graph defaults to the full A–J/0–9 region and fills the connected available background.

**Important limitation/interpretation:** The lecturer has **not** expressly required automatic plot extents or the above behavior for an open line with no enclosed BAR. These are documented **project design decisions** so that the fill seed determines which visible region is colored. A segment that does **not** meet the plot's perimeter may not separate the area, so filling can flow around its endpoint. Later commands do not retroactively recompute a preceding fill.

## 4. One combined Raylib graph

A single input sentence produces **one shared graph**. Commands run in source order; no command clears earlier shapes. A BAR redrawn over an already filled bar restores its outline without erasing the green interior. There is a command legend and a side panel showing the count and first seven commands in execution order. The application uses a readable system font where available, supports window resizing/maximizing under the desktop window manager, and returns to the input loop when the Raylib window closes.



## 5 Ubuntu prerequisites

On the project owner's Ubuntu 24.04 laptop the Zig executable is `/opt/zig/zig`. The native Linux packages needed for the existing Raylib build are:

```bash
sudo apt update
sudo apt install -y git build-essential pkg-config \
    libgl1-mesa-dev libx11-dev libxrandr-dev \
    libxinerama-dev libxcursor-dev libxi-dev
```

When obtaining the repo on a new machine:

```bash
git clone https://github.com/MJPelayo/CMPS3111_Project2.git
cd CMPS3111_Project2
git switch graphics-fix  # AFTER the tested branch is pushed to origin
/opt/zig/zig build
/opt/zig/zig build run
```


## 6 Regression tests for group review

| Input (include `start` and `end`) | Expected graphical result |
| --- | --- |
| `start bar b4,2 end` | Blue outline from B0 to D4 |
| `start bar b4,2;fill c2 end` | Only blue bar's interior green |
| `start line a1,f6 end` | Red A1-to-F6 segment |
| `start line a1,f6;fill c2 end` | Green **below** the red line on the A–F, 0–6 plot |
| `start grid f4 end` | X-axis A–F, Y-axis 0–4, with no grid lines |
| `start grid j9;fill c2 end` | Green available plotting background, axes remain black |
| `start bar b4,2;line a1,f6;fill c2 end` | Lower portion of bar green, upper part white |
| `start bar b4,2;bar f6,2;fill c2;fill g3 end` | Two bars, interiors selected by their fill seeds |
| `start bar b4,2;fill c2;bar b4,2 end` | Green interior retained, outline re-applied |
| `start line a1,f6;line d9,h2;fill c2 end` | Larger adaptive extent, and fill follows **actual**, possibly open, boundaries |

Also test lexical errors, syntax errors, lowercase `stop`, uppercase `STOP`, and both `y/n` graphics prompts. Close the Raylib window and confirm another input is accepted.


