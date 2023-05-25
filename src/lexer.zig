const std = @import("std");
const Allocator = std.mem.Allocator;
const HashMap = std.ComptimeStringMap;
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
    eq,
    notEq,
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
    true,
    false,
    If,
    Else,
    Return,
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
    eq, 
    notEq,
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
    let ,
    true,
    false,
    If,
    Else,
    Return,
    pub fn format(self: Token, comptime _: []const u8, _: std.fmt.FormatOptions, w: anytype) !void {
        const name = @tagName(self);
        switch (self) {
            .ident, .int => |v| {
                try w.print("{s}({s})", .{name, v});
            },
            else => try w.print("{s}",.{name})
        }
    }
};

pub const Lexer = @This();
const KEYWORDS =  HashMap(Token, .{.{"fn", .function}, .{"let", .let}, .{"true",  .true}, .{"false",  .false}, .{"if",  .If}, .{"else",  .Else}, .{"return",  .Return}});
input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    ch: u8 = 0,
    pub fn init( input: []const u8) Lexer {
        var n = Lexer{ .input = input };
        n.readChar();
        return n;
    }
fn lookUpIdent(ident: []const u8) Token {
    if (KEYWORDS.get(ident)) |id| {
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
fn peekChar(self: *const Lexer) ?u8 {
    if (self.read_position >= self.input.len) {
        return null;
    } else {
        return self.input[self.read_position];
    }
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
    self.skipWhitesace();
    const tok: Token = switch (self.ch) {
        '=' => if (self.peekChar())|c| blk: {
            if (c == '=') {
                self.readChar();
                break :blk .eq;
            } else break :blk .assign;
        } else  .assign,
        ';' => .semicolon,
        '(' => .lparen,
        ')' => .rparen,
        ',' => .comma,
        '+' => .plus,
        '-' => .minus,
        '!' => if (self.peekChar()) |c| blk: {
            if (c == '=') {
                self.readChar();
                break :blk .notEq;
            } else break :blk .bang;
        } else .bang ,
        '/' =>  .slash,
        '*' =>  .asterisk,
        '<' =>  .lt,
        '>' =>  .gt,
        '{' =>  .lbrace,
        '}' =>  .rbrace,
        0 =>  .eof,
        'a'...'z' , 'A' ... 'Z', '_' => {
            const id = self.readIdentifier();
            return    lookUpIdent(id);
        },
        '0'...'9' =>  {
            const num = self.readNumber();
            return  .{ .int = num };
        },
        else =>.illegal,
    };
    self.readChar();

    return tok;
}
test "test_next_keyword" {
    const testing = std.testing;
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
        \\
        \\ if (5 < 10) {
        \\     return true;
        \\ } else {
        \\     return false;
        \\ }
        \\
        \\ 10 == 10;
        \\ 10 != 9;
        ;

        const tests = [_]Token{
        .let,
        .{ .ident = "five" },
        .assign,
        .{ .int = "5" },
        .semicolon,
        .let,
        .{ .ident = "ten" },
        .assign,
        .{ .int = "10" },
        .semicolon,
        .let,
        .{ .ident = "add" },
        .assign,
        .function,
        .lparen,
        .{ .ident = "x" },
        .comma,
        .{ .ident = "y" },
        .rparen,
        .lbrace,
        .{ .ident = "x" },
        .plus,
        .{ .ident = "y" },
        .semicolon,
        .rbrace,
        .semicolon,
        .let,
        .{ .ident = "result" },
        .assign,
        .{ .ident = "add" },
        .lparen,
        .{ .ident = "five" },
        .comma,
        .{ .ident = "ten" },
        .rparen,
        .semicolon,
        .bang,
        .minus,
        .slash,
        .asterisk,
        .{ .int = "5" },
        .semicolon,
        .{ .int = "5" },
        .lt,
        .{ .int = "10" },
        .gt,
        .{ .int = "5" },
        .semicolon,
        .If,
        .lparen,
        .{ .int = "5" },
        .lt,
        .{ .int = "10" },
        .rparen,
        .lbrace,
        .Return,
        .true,
        .semicolon,
        .rbrace,
        .Else,
        .lbrace,
        .Return,
        .false,
        .semicolon,
        .rbrace,
        .{ .int = "10" },
        .eq,
        .{ .int = "10" },
        .semicolon,
        .{ .int = "10" },
        .notEq,
        .{ .int = "9" },
        .semicolon,
        .eof,
    };
var lexer = Lexer.init(input[0..]);
for (tests) |expected| {
    const tok: Token = lexer.nextToken();
    switch (expected) {
        .ident, .int => |v| {
            switch (tok) {
                .int, .ident => |v2| {
                    try testing.expectEqual(@as(TokenType, expected), @as(TokenType, tok));
                    try testing.expectEqualStrings(v, v2);
                },
                else => try testing.expect(false),
            }
        },
        else => try testing.expectEqual(@as(TokenType, expected), @as(TokenType, tok)),
    }
}
}
