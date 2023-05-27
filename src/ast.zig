const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
pub const StatementId = enum { let };
pub const Statement = union(StatementId) {
    let: LetStatement,
};
pub const ExpressionId = enum { ident };
pub const Expression = union(ExpressionId) {
    ident: Identifier,
};
pub const Program = struct {
    statements: Array(Statement),
    pub fn init(allocaor: std.mem.Allocator) Program {
        return .{ .statements = Array(Statement).init(allocaor) };
    }
    pub fn deinit(self: *Program) void {
        self.statements.deinit();
    }
};
pub const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: *Expression,
};
pub const Identifier = struct {
    token: Token,
};
