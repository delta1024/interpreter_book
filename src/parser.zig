const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig");
const Parser = @This();
const Token = Lexer.Token;
const ast = @import("ast.zig");

lexer: *Lexer,
allocator: Allocator,
cur_token: Token,
peek_token: Token,

pub fn init(allocator: Allocator, lexer: *Lexer) Parser {
    return .{
        .cur_token = lexer.nextToken(),
        .peek_token = lexer.nextToken(),
        .lexer = lexer,
        .allocator = allocator,
    };
}
fn nextToken(self: *Parser) void {
    self.cur_token = self.peek_token;
    self.peek_token = self.lexer.nextToken();
}

pub fn parseProgram(self: *Parser) !ast.Program {
    var program = ast.Program.init(self.allocator);
    while (self.cur_token != .eof) {
        var stmt = try self.parseStatement();
        try program.statements.append(stmt);
        self.nextToken();
    }
    return program;
}
const ParseError = error{ UnexpectedToken, UnknownToken, InvalideStatementToken };
fn parseStatement(self: *Parser) !*ast.Statement {
    switch (self.cur_token) {
        .let => return try self.parseLetStatement(),
        else => return error.InvalideStatementToken,
    }
}
fn parseLetStatement(self: *Parser) !*ast.Statement {
    const token = self.cur_token;

    if (!self.expectPeek(.ident)) {
        return error.UnexpectedToken;
    }

    const name = .{ .token = self.cur_token };
    if (!self.expectPeek(.assign)) {
        return error.UnexpectedToken;
    }

    // TODO: we're skipping the expressions until we encounter a semicolon
    while (!self.curTokenIs(.semicolon)) {
        self.nextToken();
    }

    var let = try self.allocator.create(ast.LetStatement);
    let.* = .{ .token = token, .name = name, .value = undefined };
    return let.statement();
}
fn expectPeek(self: *Parser, ident: Lexer.TokenType) bool {
    if (self.peekTokenIs(ident)) {
        self.nextToken();
        return true;
    } else {
        return false;
    }
}
fn peekTokenIs(self: *const Parser, ident: Lexer.TokenType) bool {
    return @as(Lexer.TokenType, self.peek_token) == ident;
}
fn curTokenIs(self: *const Parser, ident: Lexer.TokenType) bool {
    return @as(Lexer.TokenType, self.cur_token) == ident;
}
const testing = std.testing;
fn testLetStatement(s: *ast.Statement, name: []const u8) !void {
    try testing.expectEqualStrings("let", s.statementNode());

    var let_statement = @fieldParentPtr(ast.LetStatement, "class", s);

    try testing.expectEqualStrings(let_statement.name.expression().getNode().tokenLiteral(), name);
}
test "let statements" {
    const input =
        \\ let x = 5;
        \\ let y = 10;
        \\ let foobar = 838383;
    ;
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = Parser.init(allocator, &lexer);
    var program = try parser.parseProgram();
    defer program.deinit();

    if (program.statements.items.len != 3) {
        std.log.warn("Program statements does not contaion 3 statments got {d}", .{program.statements.items.len});
        try testing.expect(false);
    }
    const Expected = struct { expected_identifier: []const u8 };
    const tests = [_]Expected{
        .{ .expected_identifier = "x" },
        .{ .expected_identifier = "y" },
        .{ .expected_identifier = "foobar" },
    };

    for (tests) |tt, i| {
        const stmt = program.statements.items[i];
        try testLetStatement(stmt, tt.expected_identifier);
        stmt.destroy(std.testing.allocator);
    }
}
