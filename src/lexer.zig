const std = @import("std");

const TokenType = enum {
    illegal,
    eof,

    // Identifiers + literals
    ident,
    int,

    // Operators
    assign,
    plus,

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

const Token = union(TokenType) { illegal, eof, ident: []const u8, int: []const u8, assign, plus, comma, semicolon, lparen, rparen, lbrace, rbrace, function, let };

const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    read_position: usize = 0,
    ch: u8 = 0,
    fn init(input: []const u8) Lexer {
        var n = Lexer{ .input = input };
        n.read_char();
        return n;
    }
    fn read_char(self: *Lexer) void {
        if (self.read_position >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_position];
        }
        self.position = self.read_position;
        self.read_position += 1;
    }
    fn next_token(self: *Lexer) Token {
        var tok: Token = undefined;
        switch (self.ch) {
            '=' => tok = .assign,
            ';' => tok = .semicolon,
            '(' => tok = .lparen,
            ')' => tok = .rparen,
            ',' => tok = .comma,
            '+' => tok = .plus,
            '{' => tok = .lbrace,
            '}' => tok = .rbrace,
            0 => tok = .eof,
            else => @panic("unimplemented"),
        }
        self.read_char();

        return tok;
    }
};
test "test_next_keyword" {
    const input = "=+(){},;";

    const tests = [_]Token{
        .assign,
        .plus,
        .lparen,
        .rparen,
        .lbrace,
        .rbrace,
        .comma,
        .semicolon,
        .eof,
    };
    var lexer = Lexer.init(input[0..]);
    for (tests) |expected| {
        const tok: Token = lexer.next_token();
        try std.testing.expect(std.mem.eql(u8, @tagName(tok), @tagName(expected)));
    }
}
