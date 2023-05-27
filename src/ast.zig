const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
pub const Node = struct {
    callback: *const fn (*Node) []const u8,
    pub fn tokenLiteral(self: *Node) []const u8 {
        return self.callback(self);
    }
};

pub const Statement = struct {
    node: Node = .{
        .callback = tokenLiteral,
    },
    callback: *const fn (*Statement) []const u8,
    destroy_fn: *const fn (*Statement, Allocator) void,
    pub fn statementNode(self: *Statement) []const u8 {
        return self.callback(self);
    }
    pub fn tokenLiteral(n: *Node) []const u8 {
        return @fieldParentPtr(Statement, "node", n).statementNode();
    }
    pub fn getNdoe(self: *Statement) *Node {
        return &self.node;
    }
    pub fn destroy(self: *Statement, allocator: std.mem.Allocator) void {
        self.destroy_fn(self, allocator);
    }
};
pub const Expression = struct {
    node: Node = .{ .callback = tokenLiteral },
    callback: *const fn (*Expression) []const u8,
    destroy_fn: *const fn (*Expression, Allocator) void,
    pub fn expressionNode(self: *Expression) []const u8 {
        return self.callback(self);
    }
    pub fn tokenLiteral(n: *Node) []const u8 {
        return @fieldParentPtr(Expression, "node", n).expressionNode();
    }
    pub fn getNode(self: *Expression) *Node {
        return &self.node;
    }
    pub fn destroy(self: *Expression, allocator: Allocator) void {
        self.destroy_fn(self, allocator);
    }
};
pub const Program = struct {
    statements: Array(*Statement),
    pub fn init(allocaor: std.mem.Allocator) Program {
        return .{ .statements = Array(*Statement).init(allocaor) };
    }
    pub fn tokenLiteral(self: *Program) []const u8 {
        if (self.statements.items.len > 0) {
            return self.statements.items[0].getNode().tokenLiteral();
        } else {
            return "";
        }
    }
    pub fn deinit(self: *Program) void {
        self.statements.deinit();
    }
};
pub const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: *Expression,
    class: Statement = .{
        .callback = getTokenLiteral,
        .destroy_fn = destroy,
    },
    pub fn statement(self: *LetStatement) *Statement {
        return &self.class;
    }
    pub fn getTokenLiteral(s: *Statement) []const u8 {
        return @tagName(@fieldParentPtr(LetStatement, "class", s).token);
    }
    pub fn destroy(s: *Statement, allocator: Allocator) void {
        var self = @fieldParentPtr(LetStatement, "class", s);
        allocator.destroy(self);
    }
};
pub const Identifier = struct {
    token: Token,
    class: Expression = .{ .callback = getTokenLiteral, .destroy_fn = destroy },
    pub fn expression(self: *Identifier) *Expression {
        return &self.class;
    }
    pub fn getTokenLiteral(s: *Expression) []const u8 {
        const self = @fieldParentPtr(Identifier, "class", s);
        switch (self.token) {
            .ident => |t| return t,
            else => unreachable,
        }
    }

    pub fn destroy(s: *Expression, allocator: Allocator) void {
        var self = @fieldParentPtr(Identifier, "class", s);
        allocator.destroy(self);
    }
};

const testing = std.testing;
test "let statement statementNode()" {
    var l = LetStatement{ .token = .let, .value = undefined, .name = undefined };
    var statement = l.statement();
    try testing.expectEqualStrings("let", statement.statementNode());
}
test "interfaces" {
    const TestTree = struct {
        const TestTree = @This();
        str: []const u8 = "hello world",
        statement: Statement = .{ .callback = helloWorld, .destroy_fn = undefined },
        fn helloWorld(s: *Statement) []const u8 {
            return @fieldParentPtr(TestTree, "statement", s).str;
        }
        fn statementExpr(self: *TestTree) *Statement {
            return &self.statement;
        }
    };

    var tt = TestTree{};
    try std.testing.expectEqualStrings("hello world", tt.statementExpr().node.tokenLiteral());
}
