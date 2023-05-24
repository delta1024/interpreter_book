const std = @import("std");
const Allocator = std.mem.Allocator;
const HashMap = std.StringHashMap;
const TokenType = enum {
    illegal,
    eof,

    // Identifiers + literals
    ident,
    int,

    // Operators
    assign,
    plus,
    minus,
    bang,
    asterisk,
    slash,
    lt,
    gt,

    // Delimiters
    comma,
    semicolon,
    lparen,
    rparen,
    rbrace,
    lbrace,

    // Keywords
    function,
    let,
};

// zig fmt: off
const Token = union(TokenType) { 
    illegal,
    eof,
    ident: []const u8,
    int: []const u8,
    assign,
    plus,
    minus,
    bang,
    asterisk,
    slash,
    lt,
    gt,
    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,
    function,
    let 
};

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    ch: u8 = 0,
    keywords: HashMap(Token),
    pub fn init(allocator: Allocator, input: []const u8) !Lexer {
        var n = Lexer{ .input = input, .keywords = HashMap(Token).init(allocator) };
        try n.keywords.put("fn", .function);
        try n.keywords.put("let", .let);
        n.readChar();
        return n;
    }
    fn lookUpIdent(self: Lexer, ident: []const u8) Token {
        if (self.keywords.get(ident)) |id| {
            return id;
        }
        return .{ .ident = ident };
    }
    fn readChar(self: *Lexer) void {
        if (self.read_position >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }
    fn isLetter(ch: u8) bool {
        return 'a' <= ch and ch <= 'z' or 'A' <= ch and ch <= 'Z' or ch == '_';
    }
    fn readIdentifier(self: *Lexer) []const u8 {
        const position = self.position;
        while (isLetter(self.ch)) : (self.readChar()) {}
        return self.input[position..self.position];
    }
    fn skipWhitesace(self: *Lexer) void {
        while (self.ch == ' ' or self.ch == '\t' or self.ch == '\n' or self.ch == '\r') : (self.readChar()) {}
    }
    fn isDigit(ch: u8) bool {
        return '0' <= ch and ch <= '9';
    }
    fn readNumber(self: *Lexer) []const u8 {
        const position = self.position;
        while (isDigit(self.ch)) : (self.readChar()) {}
        return self.input[position..self.position];
    }

    pub fn nextToken(self: *Lexer) Token {
        var tok: Token = undefined;
        self.skipWhitesace();
        switch (self.ch) {
            '=' => tok = .assign,
            ';' => tok = .semicolon,
            '(' => tok = .lparen,
            ')' => tok = .rparen,
            ',' => tok = .comma,
            '+' => tok = .plus,
            '-' => tok = .minus,
            '!' => tok = .bang,
            '/' => tok = .slash,
            '*' => tok = .asterisk,
            '<' => tok = .lt,
            '>' => tok = .gt,
            '{' => tok = .lbrace,
            '}' => tok = .rbrace,
            0 => tok = .eof,
            else => if (isLetter(self.ch)) {
                const id = self.readIdentifier();
                tok = self.lookUpIdent(id);
                return tok;
            } else if (isDigit(self.ch)) {
                const num = self.readNumber();
                tok = .{ .int = num };
                return tok;
            } else {
                tok = .illegal;
            },
        }
        self.readChar();

        return tok;
    }
};
test "test_next_keyword" {
    const input =
        \\ let five = 5;
        \\ let ten = 10;
        \\ let add = fn(x,y) {
        \\ x + y;
        \\ };
        \\
        \\ let result = add(five, ten);
        \\ !-/*5;
        \\ 5 < 10 > 5;
    ;

    const tests = [_]Token{
        .let,
        .{ .ident = "five"[0..] },
        .assign,
        .{ .int = "5"[0..] },
        .semicolon,
        .let,
        .{ .ident = "ten"[0..] },
        .assign,
        .{ .int = "10"[0..] },
        .semicolon,
        .let,
        .{ .ident = "add"[0..] },
        .assign,
        .function,
        .lparen,
        .{ .ident = "x"[0..] },
        .comma,
        .{ .ident = "y"[0..] },
        .rparen,
        .lbrace,
        .{ .ident = "x"[0..] },
        .plus,
        .{ .ident = "y"[0..] },
        .semicolon,
        .rbrace,
        .semicolon,
        .let,
        .{ .ident = "result"[0..] },
        .assign,
        .{ .ident = "add"[0..] },
        .lparen,
        .{ .ident = "five"[0..] },
        .comma,
        .{ .ident = "ten"[0..] },
        .rparen,
        .semicolon,
        .bang,
        .minus,
        .slash,
        .asterisk,
        .{ .int = "5"[0..] },
        .semicolon,
        .{ .int = "5"[0..] },
        .lt,
        .{ .int = "10"[0..] },
        .gt,
        .{ .int = "5"[0..] },
        .semicolon,
        .eof,
    };
    const allocator = std.testing.allocator;
    var lexer = try Lexer.init(allocator, input[0..]);
    defer lexer.keywords.deinit();
    for (tests) |expected| {
        const tok: Token = lexer.nextToken();
        switch (expected) {
            .ident, .int => |v| {
                switch (tok) {
                    .int, .ident => |v2| {
                        const name = @tagName(expected);
                        const tok_name = @tagName(tok);
                        try std.testing.expect(std.mem.eql(u8, name, tok_name) and std.mem.eql(u8, v, v2));
                    },
                    else => try std.testing.expect(false),
                }
            },
            else => try std.testing.expect(std.meta.eql(tok, expected)),
        }
    }
}
