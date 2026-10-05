const std = @import("std");

pub const TokenKind = enum {
    start,
    end,
    bar,
    line,
    grid,
    fill,
    coordinate,
    number,
    comma,
    semicolon,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    start: usize,
    end: usize,
};

pub const LexerError = error{
    TooManyTokens,
    InvalidWord,
    InvalidCharacter,
    InvalidCoordinate,
    SpaceInsideCoordinate,
    SpaceBeforeComma,
    SpaceAfterComma,
};

//
// ============================================================
// User-facing lexer diagnostics
// ============================================================
//

pub const DiagnosticKind = enum {
    invalid_word,
    invalid_character,
    invalid_coordinate,
    space_inside_coordinate,
    space_before_comma,
    space_after_comma,
    too_many_tokens,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    start: usize,
    end: usize,
};

//
// ============================================================
// Original tokenizer
// ============================================================
//

pub fn tokenize(
    input: []const u8,
    tokens: []Token,
) LexerError!usize {
    try validateWhitespace(input);

    var count: usize = 0;
    var i: usize = 0;

    while (i < input.len) {
        // ----------------------------------------------------
        // Skip separator spaces.
        // ----------------------------------------------------

        if (input[i] == ' ') {
            i += 1;
            continue;
        }

        if (count >= tokens.len) {
            return error.TooManyTokens;
        }

        const token_start = i;

        // ----------------------------------------------------
        // Words and coordinates.
        // ----------------------------------------------------

        if (isLowercaseLetter(input[i])) {

            // A coordinate is exactly:
            //
            // one valid coordinate letter + one digit
            //
            // Examples:
            // a1
            // b5
            // j9
            if (isCoordinateLetter(input[i]) and
                i + 1 < input.len and
                isDigit(input[i + 1]))
            {
                i += 2;

                tokens[count] = .{
                    .kind = .coordinate,
                    .lexeme = input[token_start..i],
                    .start = token_start,
                    .end = i,
                };

                count += 1;
                continue;
            }

            // Otherwise read a complete word.
            while (i < input.len and isLowercaseLetter(input[i])) {
                i += 1;
            }

            const word = input[token_start..i];

            var kind: TokenKind = undefined;

            if (std.mem.eql(u8, word, "start")) {
                kind = .start;
            } else if (std.mem.eql(u8, word, "end")) {
                kind = .end;
            } else if (std.mem.eql(u8, word, "bar")) {
                kind = .bar;
            } else if (std.mem.eql(u8, word, "line")) {
                kind = .line;
            } else if (std.mem.eql(u8, word, "grid")) {
                kind = .grid;
            } else if (std.mem.eql(u8, word, "fill")) {
                kind = .fill;
            } else {
                return error.InvalidWord;
            }

            tokens[count] = .{
                .kind = kind,
                .lexeme = word,
                .start = token_start,
                .end = i,
            };

            count += 1;
            continue;
        }

        // ----------------------------------------------------
        // Comma.
        // ----------------------------------------------------

        if (input[i] == ',') {
            tokens[count] = .{
                .kind = .comma,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Semicolon.
        // ----------------------------------------------------

        if (input[i] == ';') {
            tokens[count] = .{
                .kind = .semicolon,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Standalone digit.
        // ----------------------------------------------------

        if (isDigit(input[i])) {
            tokens[count] = .{
                .kind = .number,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Anything else is not part of our language.
        // ----------------------------------------------------

        return error.InvalidCharacter;
    }

    return count;
}

//
// ============================================================
// Collecting tokenizer
// ============================================================
//
// This version scans the complete input instead of stopping at
// the first lexical error.
//
// It records every lexical error that can be determined
// reliably while still producing valid tokens where possible.
//

pub fn tokenizeCollectErrors(
    input: []const u8,
    tokens: []Token,
    diagnostics: []Diagnostic,
) usize {
    var token_count: usize = 0;
    var diagnostic_count: usize = 0;

    var i: usize = 0;

    // --------------------------------------------------------
    // Collect whitespace errors first.
    // --------------------------------------------------------

    diagnostic_count = collectWhitespaceErrors(
        input,
        diagnostics,
        diagnostic_count,
    );

    while (i < input.len) {
        // ----------------------------------------------------
        // Skip spaces.
        // ----------------------------------------------------

        if (input[i] == ' ') {
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Token storage limit.
        // ----------------------------------------------------

        if (token_count >= tokens.len) {
            diagnostic_count = addDiagnostic(
                diagnostics,
                diagnostic_count,
                .too_many_tokens,
                i,
                i + 1,
            );

            break;
        }

        const token_start = i;

        // ----------------------------------------------------
        // Lowercase words / coordinates.
        // ----------------------------------------------------

        if (isLowercaseLetter(input[i])) {

            // ------------------------------------------------
            // Valid coordinate.
            //
            // a0 through j9
            // ------------------------------------------------

            if (isCoordinateLetter(input[i]) and
                i + 1 < input.len and
                isDigit(input[i + 1]))
            {
                // ------------------------------------------------
                // Detect coordinates containing more than one
                // digit.
                //
                // Example:
                //
                // a10
                //
                // is invalid because the grammar allows exactly
                // one digit after the coordinate letter.
                // ------------------------------------------------

                if (i + 2 < input.len and
                    isDigit(input[i + 2]))
                {
                    i += 2;

                    while (i < input.len and isDigit(input[i])) {
                        i += 1;
                    }

                    diagnostic_count = addDiagnostic(
                        diagnostics,
                        diagnostic_count,
                        .invalid_coordinate,
                        token_start,
                        i,
                    );

                    continue;
                }

                i += 2;

                tokens[token_count] = .{
                    .kind = .coordinate,
                    .lexeme = input[token_start..i],
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            // ------------------------------------------------
            // SPECIAL CASE:
            //
            // If we have:
            //
            // a 1
            //
            // then the whitespace diagnostic already reports
            // the problem as "space inside coordinate".
            //
            // Do NOT also report "a" as an invalid word.
            // ------------------------------------------------

            if (isCoordinateLetter(input[i])) {
                var lookahead = i + 1;

                while (lookahead < input.len and
                    input[lookahead] == ' ')
                {
                    lookahead += 1;
                }

                if (lookahead < input.len and
                    isDigit(input[lookahead]))
                {
                    i += 1;
                    continue;
                }
            }

            // ------------------------------------------------
            // Read the complete lowercase word.
            // ------------------------------------------------

            while (i < input.len and isLowercaseLetter(input[i])) {
                i += 1;
            }

            const word = input[token_start..i];

            // ------------------------------------------------
            // Recognized keywords.
            // ------------------------------------------------

            if (std.mem.eql(u8, word, "start")) {
                tokens[token_count] = .{
                    .kind = .start,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            if (std.mem.eql(u8, word, "end")) {
                tokens[token_count] = .{
                    .kind = .end,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            if (std.mem.eql(u8, word, "bar")) {
                tokens[token_count] = .{
                    .kind = .bar,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            if (std.mem.eql(u8, word, "line")) {
                tokens[token_count] = .{
                    .kind = .line,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            if (std.mem.eql(u8, word, "grid")) {
                tokens[token_count] = .{
                    .kind = .grid,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            if (std.mem.eql(u8, word, "fill")) {
                tokens[token_count] = .{
                    .kind = .fill,
                    .lexeme = word,
                    .start = token_start,
                    .end = i,
                };

                token_count += 1;
                continue;
            }

            // ------------------------------------------------
            // Unknown word.
            // ------------------------------------------------

            diagnostic_count = addDiagnostic(
                diagnostics,
                diagnostic_count,
                .invalid_word,
                token_start,
                i,
            );

            continue;
        }

        // ----------------------------------------------------
        // Comma.
        // ----------------------------------------------------

        if (input[i] == ',') {
            tokens[token_count] = .{
                .kind = .comma,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            token_count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Semicolon.
        // ----------------------------------------------------

        if (input[i] == ';') {
            tokens[token_count] = .{
                .kind = .semicolon,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            token_count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Standalone digit.
        // ----------------------------------------------------

        if (isDigit(input[i])) {
            tokens[token_count] = .{
                .kind = .number,
                .lexeme = input[i .. i + 1],
                .start = i,
                .end = i + 1,
            };

            token_count += 1;
            i += 1;
            continue;
        }

        // ----------------------------------------------------
        // Invalid character.
        //
        // Record it and continue scanning.
        // ----------------------------------------------------

        diagnostic_count = addDiagnostic(
            diagnostics,
            diagnostic_count,
            .invalid_character,
            i,
            i + 1,
        );

        i += 1;
    }

    return diagnostic_count;
}

//
// ============================================================
// Collect whitespace diagnostics
// ============================================================
//

fn collectWhitespaceErrors(
    input: []const u8,
    diagnostics: []Diagnostic,
    diagnostic_count_start: usize,
) usize {
    var diagnostic_count = diagnostic_count_start;
    var i: usize = 0;

    while (i < input.len) {
        if (input[i] != ' ') {
            i += 1;
            continue;
        }

        const space_start = i;

        while (i < input.len and input[i] == ' ') {
            i += 1;
        }

        const space_end = i;

        const previous =
            if (space_start > 0)
                input[space_start - 1]
            else
                null;

        const next =
            if (space_end < input.len)
                input[space_end]
            else
                null;

        // ----------------------------------------------------
        // Space inside coordinate.
        //
        // Example:
        //
        // a 1
        // ----------------------------------------------------

        if (previous != null and
            next != null and
            isCoordinateLetter(previous.?) and
            isDigit(next.?))
        {
            diagnostic_count = addDiagnostic(
                diagnostics,
                diagnostic_count,
                .space_inside_coordinate,
                space_start,
                space_end,
            );
        }

        // ----------------------------------------------------
        // Otherwise, space before comma.
        //
        // Example:
        //
        // a1 ,5
        // ----------------------------------------------------

        else if (next != null and next.? == ',') {
            diagnostic_count = addDiagnostic(
                diagnostics,
                diagnostic_count,
                .space_before_comma,
                space_start,
                space_end,
            );
        }

        // ----------------------------------------------------
        // Otherwise, space after comma.
        //
        // Example:
        //
        // a1, 5
        // ----------------------------------------------------

        else if (previous != null and previous.? == ',') {
            diagnostic_count = addDiagnostic(
                diagnostics,
                diagnostic_count,
                .space_after_comma,
                space_start,
                space_end,
            );
        }
    }

    return diagnostic_count;
}

//
// ============================================================
// Add a diagnostic safely
// ============================================================
//

fn addDiagnostic(
    diagnostics: []Diagnostic,
    count: usize,
    kind: DiagnosticKind,
    start: usize,
    end: usize,
) usize {
    if (count >= diagnostics.len) {
        return count;
    }

    diagnostics[count] = .{
        .kind = kind,
        .start = start,
        .end = end,
    };

    return count + 1;
}

//
// ============================================================
// Existing whitespace validation
// ============================================================
//

fn validateWhitespace(input: []const u8) LexerError!void {
    var i: usize = 0;

    while (i < input.len) {
        if (input[i] != ' ') {
            i += 1;
            continue;
        }

        const space_start = i;

        while (i < input.len and input[i] == ' ') {
            i += 1;
        }

        const space_end = i;

        const previous =
            if (space_start > 0)
                input[space_start - 1]
            else
                null;

        const next =
            if (space_end < input.len)
                input[space_end]
            else
                null;

        // ----------------------------------------------------
        // Space inside a coordinate.
        // ----------------------------------------------------

        if (previous != null and
            next != null and
            isCoordinateLetter(previous.?) and
            isDigit(next.?))
        {
            return error.SpaceInsideCoordinate;
        }

        // ----------------------------------------------------
        // Space before a comma.
        // ----------------------------------------------------

        if (next != null and next.? == ',') {
            return error.SpaceBeforeComma;
        }

        // ----------------------------------------------------
        // Space after a comma.
        // ----------------------------------------------------

        if (previous != null and previous.? == ',') {
            return error.SpaceAfterComma;
        }
    }
}

//
// ============================================================
// Character helpers
// ============================================================
//

fn isLowercaseLetter(character: u8) bool {
    return character >= 'a' and character <= 'z';
}

fn isCoordinateLetter(character: u8) bool {
    return character >= 'a' and character <= 'j';
}

fn isDigit(character: u8) bool {
    return character >= '0' and character <= '9';
}

//
// ============================================================
// Lexer tests
// ============================================================
//

test "tokenize valid input" {
    const input = "start bar a1,5 end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 6),
        count,
    );

    try std.testing.expectEqual(
        TokenKind.start,
        tokens[0].kind,
    );

    try std.testing.expectEqual(
        TokenKind.bar,
        tokens[1].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[2].kind,
    );

    try std.testing.expectEqual(
        TokenKind.comma,
        tokens[3].kind,
    );

    try std.testing.expectEqual(
        TokenKind.number,
        tokens[4].kind,
    );

    try std.testing.expectEqual(
        TokenKind.end,
        tokens[5].kind,
    );
}

test "repeated separator spaces are valid" {
    const input = "start       bar       a1,5      end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 6),
        count,
    );
}

test "space inside coordinate is invalid" {
    const input = "start bar a 1,5 end";

    var tokens: [20]Token = undefined;

    try std.testing.expectError(
        error.SpaceInsideCoordinate,
        tokenize(
            input,
            &tokens,
        ),
    );
}

test "space before comma is invalid" {
    const input = "start bar a1 ,5 end";

    var tokens: [20]Token = undefined;

    try std.testing.expectError(
        error.SpaceBeforeComma,
        tokenize(
            input,
            &tokens,
        ),
    );
}

test "space after comma is invalid" {
    const input = "start bar a1, 5 end";

    var tokens: [20]Token = undefined;

    try std.testing.expectError(
        error.SpaceAfterComma,
        tokenize(
            input,
            &tokens,
        ),
    );
}

test "tokenize line plot" {
    const input = "start line a1,b2 end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 6),
        count,
    );

    try std.testing.expectEqual(
        TokenKind.start,
        tokens[0].kind,
    );

    try std.testing.expectEqual(
        TokenKind.line,
        tokens[1].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[2].kind,
    );

    try std.testing.expectEqual(
        TokenKind.comma,
        tokens[3].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[4].kind,
    );

    try std.testing.expectEqual(
        TokenKind.end,
        tokens[5].kind,
    );
}

test "tokenize grid plot" {
    const input = "start grid c4 end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 4),
        count,
    );

    try std.testing.expectEqual(
        TokenKind.start,
        tokens[0].kind,
    );

    try std.testing.expectEqual(
        TokenKind.grid,
        tokens[1].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[2].kind,
    );

    try std.testing.expectEqual(
        TokenKind.end,
        tokens[3].kind,
    );
}

test "tokenize fill plot" {
    const input = "start fill j9 end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 4),
        count,
    );

    try std.testing.expectEqual(
        TokenKind.start,
        tokens[0].kind,
    );

    try std.testing.expectEqual(
        TokenKind.fill,
        tokens[1].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[2].kind,
    );

    try std.testing.expectEqual(
        TokenKind.end,
        tokens[3].kind,
    );
}

test "tokenize multiple plots" {
    const input = "start bar a1,5;line b2,c3 end";

    var tokens: [20]Token = undefined;

    const count = try tokenize(
        input,
        &tokens,
    );

    try std.testing.expectEqual(
        @as(usize, 11),
        count,
    );

    try std.testing.expectEqual(
        TokenKind.start,
        tokens[0].kind,
    );

    try std.testing.expectEqual(
        TokenKind.bar,
        tokens[1].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[2].kind,
    );

    try std.testing.expectEqual(
        TokenKind.comma,
        tokens[3].kind,
    );

    try std.testing.expectEqual(
        TokenKind.number,
        tokens[4].kind,
    );

    try std.testing.expectEqual(
        TokenKind.semicolon,
        tokens[5].kind,
    );

    try std.testing.expectEqual(
        TokenKind.line,
        tokens[6].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[7].kind,
    );

    try std.testing.expectEqual(
        TokenKind.comma,
        tokens[8].kind,
    );

    try std.testing.expectEqual(
        TokenKind.coordinate,
        tokens[9].kind,
    );

    try std.testing.expectEqual(
        TokenKind.end,
        tokens[10].kind,
    );
}

test "invalid word is rejected" {
    const input = "start banana a1,5 end";

    var tokens: [20]Token = undefined;

    try std.testing.expectError(
        error.InvalidWord,
        tokenize(
            input,
            &tokens,
        ),
    );
}

test "invalid character is rejected" {
    const input = "start bar a1,5 @ end";

    var tokens: [20]Token = undefined;

    try std.testing.expectError(
        error.InvalidCharacter,
        tokenize(
            input,
            &tokens,
        ),
    );
}

//
// ============================================================
// Collecting lexer tests
// ============================================================
//

test "collect multiple invalid characters" {
    const input = "start bar a1,@5 # end";

    var tokens: [20]Token = undefined;
    var diagnostics: [20]Diagnostic = undefined;

    const count = tokenizeCollectErrors(
        input,
        &tokens,
        &diagnostics,
    );

    try std.testing.expectEqual(
        @as(usize, 2),
        count,
    );

    try std.testing.expectEqual(
        DiagnosticKind.invalid_character,
        diagnostics[0].kind,
    );

    try std.testing.expectEqual(
        DiagnosticKind.invalid_character,
        diagnostics[1].kind,
    );
}

test "collect multiple whitespace errors" {
    const input = "start bar a 1 , 5 end";

    var tokens: [20]Token = undefined;
    var diagnostics: [20]Diagnostic = undefined;

    const count = tokenizeCollectErrors(
        input,
        &tokens,
        &diagnostics,
    );

    try std.testing.expectEqual(
        @as(usize, 3),
        count,
    );

    try std.testing.expectEqual(
        DiagnosticKind.space_inside_coordinate,
        diagnostics[0].kind,
    );

    try std.testing.expectEqual(
        DiagnosticKind.space_before_comma,
        diagnostics[1].kind,
    );

    try std.testing.expectEqual(
        DiagnosticKind.space_after_comma,
        diagnostics[2].kind,
    );
}

test "collect invalid word and invalid character" {
    const input = "start baar a1,@5 end";

    var tokens: [20]Token = undefined;
    var diagnostics: [20]Diagnostic = undefined;

    const count = tokenizeCollectErrors(
        input,
        &tokens,
        &diagnostics,
    );

    try std.testing.expectEqual(
        @as(usize, 2),
        count,
    );

    try std.testing.expectEqual(
        DiagnosticKind.invalid_word,
        diagnostics[0].kind,
    );

    try std.testing.expectEqual(
        DiagnosticKind.invalid_character,
        diagnostics[1].kind,
    );
}

test "collect invalid coordinate with extra digit" {
    const input = "start bar a10,5 end";

    var tokens: [20]Token = undefined;
    var diagnostics: [20]Diagnostic = undefined;

    const count = tokenizeCollectErrors(
        input,
        &tokens,
        &diagnostics,
    );

    try std.testing.expectEqual(
        @as(usize, 1),
        count,
    );

    try std.testing.expectEqual(
        DiagnosticKind.invalid_coordinate,
        diagnostics[0].kind,
    );
}
