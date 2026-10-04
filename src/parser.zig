const std = @import("std");
const lexer = @import("lexer.zig");

pub const ParserError = error{
    UnexpectedEndOfInput,
    UnexpectedToken,
    ExpectedStart,
    ExpectedEnd,
    ExpectedPlot,
    ExpectedCoordinate,
    ExpectedComma,
    ExpectedNumber,
};

pub const Parser = struct {
    tokens: []const lexer.Token,
    position: usize,

    // --------------------------------------------------------
    // Create a new parser.
    // --------------------------------------------------------

    pub fn init(tokens: []const lexer.Token) Parser {
        return .{
            .tokens = tokens,
            .position = 0,
        };
    }

    // --------------------------------------------------------
    // Parse the complete <graph>.
    //
    // <graph> → start <plot_stmts> end
    // --------------------------------------------------------

    pub fn parseGraph(self: *Parser) ParserError!void {
        // <graph> must begin with "start".
        try self.expect(.start);

        // Parse one or more plots.
        try self.parsePlotStatements();

        // <graph> must finish with "end".
        try self.expect(.end);

        // There must not be any tokens after "end".
        if (self.position < self.tokens.len) {
            return error.UnexpectedToken;
        }
    }

    // --------------------------------------------------------
    // Parse <plot_stmts>.
    //
    // <plot_stmts> → <plot>
    //               | <plot> ; <plot_stmts>
    //
    // We use a loop here to represent the recursive grammar.
    // This allows any number of plots.
    // --------------------------------------------------------

    fn parsePlotStatements(self: *Parser) ParserError!void {
        // There must be at least one plot.
        try self.parsePlot();

        // Every semicolon means another plot follows.
        while (self.match(.semicolon)) {
            try self.parsePlot();
        }
    }

    // --------------------------------------------------------
    // Parse one <plot>.
    //
    // <plot> → bar <x><y>,<y>
    //         | line <x><y>,<x><y>
    //         | grid <x><y>
    //         | fill <x><y>
    // --------------------------------------------------------

    fn parsePlot(self: *Parser) ParserError!void {
        // ----------------------------------------------------
        // bar <x><y>,<y>
        // ----------------------------------------------------

        if (self.match(.bar)) {
            try self.parseCoordinate();
            try self.expect(.comma);
            try self.expect(.number);
            return;
        }

        // ----------------------------------------------------
        // line <x><y>,<x><y>
        // ----------------------------------------------------

        if (self.match(.line)) {
            try self.parseCoordinate();
            try self.expect(.comma);
            try self.parseCoordinate();
            return;
        }

        // ----------------------------------------------------
        // grid <x><y>
        // ----------------------------------------------------

        if (self.match(.grid)) {
            try self.parseCoordinate();
            return;
        }

        // ----------------------------------------------------
        // fill <x><y>
        // ----------------------------------------------------

        if (self.match(.fill)) {
            try self.parseCoordinate();
            return;
        }

        // No valid plot command was found.
        return error.ExpectedPlot;
    }

    // --------------------------------------------------------
    // Parse a coordinate.
    //
    // <x><y>
    //
    // The lexer has already recognized the complete coordinate
    // such as "a1", "b5", or "j9".
    // --------------------------------------------------------

    fn parseCoordinate(self: *Parser) ParserError!void {
        try self.expect(.coordinate);
    }

    // --------------------------------------------------------
    // Check whether the current token has a specific kind.
    //
    // If it matches, move to the next token.
    // --------------------------------------------------------

    fn match(
        self: *Parser,
        expected: lexer.TokenKind,
    ) bool {
        if (self.position >= self.tokens.len) {
            return false;
        }

        if (self.tokens[self.position].kind != expected) {
            return false;
        }

        self.position += 1;
        return true;
    }

    // --------------------------------------------------------
    // Require a specific token.
    // --------------------------------------------------------

    fn expect(
        self: *Parser,
        expected: lexer.TokenKind,
    ) ParserError!void {
        if (self.position >= self.tokens.len) {
            return error.UnexpectedEndOfInput;
        }

        if (self.tokens[self.position].kind != expected) {
            return switch (expected) {
                .start => error.ExpectedStart,
                .end => error.ExpectedEnd,

                .bar, .line, .grid, .fill => error.ExpectedPlot,

                .coordinate => error.ExpectedCoordinate,
                .comma => error.ExpectedComma,
                .number => error.ExpectedNumber,
                .semicolon => error.UnexpectedToken,
            };
        }

        self.position += 1;
    }
};

// ============================================================
// Parser tests
// ============================================================

test "parse valid bar graph" {
    const input = "start bar a1,5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse valid bar graph with repeated spaces" {
    const input = "start       bar       a1,5      end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse valid line graph" {
    const input = "start line a1,b2 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse valid grid graph" {
    const input = "start grid c4 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse valid fill graph" {
    const input = "start fill j9 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse multiple bar plots" {
    const input = "start bar a1,5;bar b2,3;bar c4,7 end";

    var tokens: [30]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse multiple mixed plots" {
    const input =
        "start bar a1,5;line b2,c3;grid d4;fill e5 end";

    var tokens: [40]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "parse many plots" {
    const input =
        "start bar a1,5;line b2,c3;grid d4;fill e5;" ++ "bar f6,2;line g7,h8;grid i9;fill j0 end";

    var tokens: [60]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try parser.parseGraph();
}

test "reject graph without start" {
    const input = "bar a1,5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedStart,
        parser.parseGraph(),
    );
}

test "reject graph without end" {
    const input = "start bar a1,5";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.UnexpectedEndOfInput,
        parser.parseGraph(),
    );
}

test "reject graph with no plot" {
    const input = "start end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedPlot,
        parser.parseGraph(),
    );
}

test "reject bar without coordinate" {
    const input = "start bar 5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedCoordinate,
        parser.parseGraph(),
    );
}

test "reject bar without comma" {
    const input = "start bar a1 5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedComma,
        parser.parseGraph(),
    );
}

test "reject bar without number" {
    const input = "start bar a1 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedComma,
        parser.parseGraph(),
    );
}

test "reject line without second coordinate" {
    const input = "start line a1,5 end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedCoordinate,
        parser.parseGraph(),
    );
}

test "reject grid without coordinate" {
    const input = "start grid end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedCoordinate,
        parser.parseGraph(),
    );
}

test "reject fill without coordinate" {
    const input = "start fill end";

    var tokens: [20]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.ExpectedCoordinate,
        parser.parseGraph(),
    );
}

test "reject extra tokens after end" {
    const input = "start grid c4 end bar a1,5";

    var tokens: [30]lexer.Token = undefined;

    const token_count = try lexer.tokenize(
        input,
        &tokens,
    );

    var parser = Parser.init(
        tokens[0..token_count],
    );

    try std.testing.expectError(
        error.UnexpectedToken,
        parser.parseGraph(),
    );
}
