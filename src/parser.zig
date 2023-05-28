const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Lexer = @import("lexer.zig");
const Parser = @This();
const Token = Lexer.Token;
const ast = @import("ast.zig");

lexer: *Lexer,
allocator: Allocator,
cur_token: Token,
peek_token: Token,
errors: ArrayList([]u8),

pub fn init(allocator: Allocator, lexer: *Lexer) Parser {
    return .{
        .cur_token = lexer.nextToken(),
        .peek_token = lexer.nextToken(),
        .lexer = lexer,
        .allocator = allocator,
        .errors = ArrayList([]u8).init(allocator),
    };
}
pub fn deinit(self: *Parser) void {
    for (self.errors.items) |err| {
        self.allocator.free(err);
    }
    self.errors.deinit();
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
const ParseError = error{ UnexpectedToken, UnknownToken, InvalideStatementToken, ParserHadErrors };
fn parseStatement(self: *Parser) !*ast.Statement {
    switch (self.cur_token) {
        .let => return try self.parseLetStatement(),
        .Return => return try self.parseReturnStatement(),
        else => return error.InvalideStatementToken,
    }
}
fn parseReturnStatement(self: *Parser) !*ast.Statement {
    var stmt = try self.allocator.create(ast.ReturnStatement);
    stmt.* = .{ .token = self.cur_token, .return_value = undefined };

    self.nextToken();

    // TODO: We're skipping the expressions until
    // we encounter a semicolon.
    while (!self.curTokenIs(.semicolon)) {
        self.nextToken();
    }

    return &stmt.class;
}
fn parseLetStatement(self: *Parser) !*ast.Statement {
    const token = self.cur_token;

    _ = try self.expectPeek(.ident);

    const name = .{ .token = self.cur_token };
    _ = try self.expectPeek(.assign);

    // TODO: we're skipping the expressions until we encounter a semicolon
    while (!self.curTokenIs(.semicolon)) {
        self.nextToken();
    }

    var let = try self.allocator.create(ast.LetStatement);
    let.* = .{ .token = token, .name = name, .value = undefined };
    return let.statement();
}
fn peekError(self: *Parser, token: Lexer.TokenType) !void {
    var msg = try std.fmt.allocPrint(self.allocator, "expected next token to be {s}, got {s} instead", .{ @tagName(token), @tagName(self.peek_token) });
    try self.errors.append(msg);
}
fn expectPeek(self: *Parser, ident: Lexer.TokenType) !bool {
    if (self.peekTokenIs(ident)) {
        self.nextToken();
        return true;
    } else {
        try self.peekError(ident);
        return false;
    }
}
fn peekTokenIs(self: *const Parser, ident: Lexer.TokenType) bool {
    return @as(Lexer.TokenType, self.peek_token) == ident;
}
fn curTokenIs(self: *const Parser, ident: Lexer.TokenType) bool {
    return @as(Lexer.TokenType, self.cur_token) == ident;
}
fn checkParseErrors(self: *Parser) !void {
    const log = std.log;
    const errors = self.errors.items;
    if (errors.len == 0) return;
    log.err("parser has {d} errors", .{errors.len});
    for (errors) |err| {
        log.err("parser error: {s}", .{err});
    }
    return error.ParserHadErrors;
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
        \\ let foobar =  838383;
    ;
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();
    var program = try parser.parseProgram();
    defer program.deinit(allocator);

    try parser.checkParseErrors();

    if (program.statements.items.len != 3) {
        std.log.err("Program statements does not contaion 3 statments got {d}", .{program.statements.items.len});
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
    }
}
test "return statement" {
    const input =
        \\ return 5;
        \\ return 10;
        \\ return 993322;
    ;
    const log = std.log;
    const allocator = std.testing.allocator;
    var lexer = Lexer.init(input);
    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit(allocator);
    try parser.checkParseErrors();

    if (program.statements.items.len != 3) {
        log.err("program statements does not contain 3 statemetns. got {d}", .{program.statements.items.len});
        try testing.expect(false);
    }

    for (program.statements.items) |stmt| {
        testing.expectEqualStrings("Return", stmt.statementNode()) catch {
            log.err("stmt not ast.ReturnStatement. got {s}", .{stmt.statementNode()});
            continue;
        };
    }
}
