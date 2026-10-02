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
        // Words and coordinates
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
        // Comma
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
        // Semicolon
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
        // Standalone digit
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

// ============================================================
// Whitespace validation
// ============================================================

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
        // Space inside a coordinate
        //
        // Invalid:
        //
        // a 1
        // ----------------------------------------------------

        if (previous != null and
            next != null and
            isCoordinateLetter(previous.?) and
            isDigit(next.?))
        {
            return error.SpaceInsideCoordinate;
        }

        // ----------------------------------------------------
        // Space before a comma
        //
        // Invalid:
        //
        // a1 ,5
        // ----------------------------------------------------

        if (next != null and next.? == ',') {
            return error.SpaceBeforeComma;
        }

        // ----------------------------------------------------
        // Space after a comma
        //
        // Invalid:
        //
        // a1, 5
        // ----------------------------------------------------

        if (previous != null and previous.? == ',') {
            return error.SpaceAfterComma;
        }
    }
}

// ============================================================
// Character helpers
// ============================================================

fn isLowercaseLetter(character: u8) bool {
    return character >= 'a' and character <= 'z';
}

fn isCoordinateLetter(character: u8) bool {
    return character >= 'a' and character <= 'j';
}

fn isDigit(character: u8) bool {
    return character >= '0' and character <= '9';
}

// ============================================================
// Lexer tests
// ============================================================

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
