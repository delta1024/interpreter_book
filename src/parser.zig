const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;
const ast = @import("ast.zig");
const Parser = @This();

const Err = error{ OutOfMemory, UnexpectedToken };

lexer: Lexer,
cur_token: Token = undefined,
peek_token: Token = undefined,
arena: Arena,

pub fn init(allocator: Allocator, lexer: Lexer) Parser {
    var p = Parser{
        .lexer = lexer,
        .arena = Arena.init(allocator),
    };
    // Read two tokens, so cur_token and peek_token are both set.
    p.nextToken();
    p.nextToken();
    return p;
}

pub fn deinit(self: *Parser) void {
    self.arena.deinit();
}

fn nextToken(self: *Parser) void {
    self.cur_token = self.peek_token;
    self.peek_token = self.lexer.nextToken();
}

pub fn parseProgram(self: *Parser) Err!*ast.Program {
    var program = try self.arena.allocator().create(ast.Program);
    program.* = ast.Program.init(self.arena.allocator());

    while (@as(TokenType, self.cur_token) != .eof) {
        var stmt = try self.parseStatement();
        try program.statements.append(stmt);
        self.nextToken();
    }

    return program;
}

fn parseStatement(self: *Parser) Err!ast.Statement {
    switch (@as(TokenType, self.cur_token)) {
        .let => return (try self.parseLetStatement()).statement(),
        else => unreachable,
    }
}
fn parseLetStatement(self: *Parser) Err!*ast.LetStatement {
    var stmt = try self.arena.allocator().create(ast.LetStatement);
    if (!self.expectPeek(.ident)) {
        return error.UnexpectedToken;
    }

    const name = switch (self.cur_token) {
        .ident => |i| ast.Identifier{
            .id = .ident,
            .value = i,
        },
        else => unreachable,
    };

    if (!self.expectPeek(.assign)) {
        return error.UnexpectedToken;
    }

    while (!self.curTokenIs(.semicolon)) {
        self.nextToken();
    }

    stmt.* = .{
        .id = .let,
        .name = name,
        .value = null,
    };
    return stmt;
}
fn curTokenIs(self: *Parser, expect: TokenType) bool {
    return @as(TokenType, self.cur_token) == expect;
}
fn peekTokenIs(self: *Parser, expect: TokenType) bool {
    return @as(TokenType, self.peek_token) == expect;
}
fn expectPeek(self: *Parser, expect: TokenType) bool {
    if (self.peekTokenIs(expect)) {
        self.nextToken();
        return true;
    } else {
        return false;
    }
}
fn testLetStatement(s: ast.Statement, name: []const u8) !void {
    const testing = std.testing;
    try testing.expectEqual(TokenType.let, s.tokenLiteral());

    const let_stmt = @ptrCast(*ast.LetStatement, @alignCast(@alignOf(ast.LetStatement), s.ptr));

    try testing.expectEqualStrings(name, let_stmt.name.value);

    try testing.expectEqual(TokenType.ident, let_stmt.name.id);
}

test "parse LetStatement" {
    const input =
        \\ let x = 5;
        \\ let y = 10;
        \\ let foobar = 838383;
    ;
    const testing = std.testing;
    const allocator = testing.allocator;
    var lexer = Lexer.init(input);
    var parser = Parser.init(allocator, lexer);
    defer parser.deinit();

    const program = try parser.parseProgram();
    const len: usize = program.statements.items.len;
    const expect_statement_len: usize = 3;
    try testing.expectEqual(expect_statement_len, len);

    const tests = [_][]const u8{ "x", "y", "foobar" };

    for (tests) |t, i| {
        const statement = program.statements.items[i];
        try testLetStatement(statement, t);
    }
}
