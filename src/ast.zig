const std = @import("std");
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;
const Array = std.ArrayList;
const Allocator = std.mem.Allocator;
fn VTable(comptime T: type) type {
    return struct {
        const Self = @This();
        literal_fn: *const fn (*T) []const u8,
        destroy_fn: *const fn (*T, Allocator) void,
        pub fn init(literal: *const fn (*T) []const u8, destroy: *const fn (*T, Allocator) void) Self {
            return .{
                .literal_fn = literal,
                .destroy_fn = destroy,
            };
        }
    };
}
pub const Node = struct {
    vtable: VTable(Node),
    pub fn tokenLiteral(self: *Node) []const u8 {
        return self.vtable.literal_fn(self);
    }
    pub fn destroy(self: *Node, allocator: Allocator) void {
        self.vtable.destroy_fn(self, allocator);
    }
};

pub const Statement = struct {
    node: Node = .{ .vtable = VTable(Node).init(tokenLiteral, destroyNode) },
    vtable: VTable(Statement),
    pub fn statementNode(self: *Statement) []const u8 {
        return self.vtable.literal_fn(self);
    }
    pub fn tokenLiteral(n: *Node) []const u8 {
        return @fieldParentPtr(Statement, "node", n).statementNode();
    }
    pub fn getNdoe(self: *Statement) *Node {
        return &self.node;
    }
    pub fn destroy(self: *Statement, allocator: std.mem.Allocator) void {
        self.vtable.destroy_fn(self, allocator);
    }
    pub fn destroyNode(s: *Node, allocator: Allocator) void {
        const self = @fieldParentPtr(Statement, "node", s);
        self.vtable.destroy_fn(self, allocator);
    }
};
pub const Expression = struct {
    node: Node = .{ .vtable = VTable(Node).init(tokenLiteral, destroyNode) },
    vtable: VTable(Expression),
    pub fn expressionNode(self: *Expression) []const u8 {
        return self.vtable.literal_fn(self);
    }
    pub fn tokenLiteral(n: *Node) []const u8 {
        return @fieldParentPtr(Expression, "node", n).expressionNode();
    }
    pub fn getNode(self: *Expression) *Node {
        return &self.node;
    }
    pub fn destroy(self: *Expression, allocator: Allocator) void {
        self.vtable.destroy_fn(self, allocator);
    }
    pub fn destroyNode(s: *Node, allocator: Allocator) void {
        const self = @fieldParentPtr(Expression, "node", s);
        self.vtable.destroy_fn(self, allocator);
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
    pub fn deinit(self: *Program, allocator: Allocator) void {
        for (self.statements.items) |s| {
            s.destroy(allocator);
        }
        self.statements.deinit();
    }
};
pub const LetStatement = struct {
    token: Token,
    name: Identifier,
    value: *Expression,
    class: Statement = .{ .vtable = VTable(Statement).init(getTokenLiteral, destroy) },
    pub fn statement(self: *LetStatement) *Statement {
        return &self.class;
    }
    pub fn getTokenLiteral(s: *Statement) []const u8 {
        return @tagName(@fieldParentPtr(LetStatement, "class", s).token);
    }
    pub fn destroy(s: *Statement, allocator: Allocator) void {
        var self = @fieldParentPtr(LetStatement, "class", s);
        // self.value.destroy(allocator);
        allocator.destroy(self);
    }
};
pub const Identifier = struct {
    token: Token,
    class: Expression = .{ .vtable = VTable(Expression).init(getTokenLiteral, destroy) },
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

pub const ReturnStatement = struct {
    token: Token,
    return_value: *Expression,
    class: Statement = .{ .vtable = VTable(Statement).init(getTokenLiteral, destory) },
    pub fn getTokenLiteral(s: *Statement) []const u8 {
        return @tagName(@fieldParentPtr(ReturnStatement, "class", s).token);
    }
    pub fn destory(s: *Statement, allocator: Allocator) void {
        var self = @fieldParentPtr(ReturnStatement, "class", s);
        // self.return_value.destory(allocator);
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
        const Self = @This();
        str: []const u8 = "hello world",
        statement: Statement = .{ .vtable = VTable(Statement).init(helloWorld, undefined) },
        fn helloWorld(s: *Statement) []const u8 {
            return @fieldParentPtr(Self, "statement", s).str;
        }
        fn statementExpr(self: *Self) *Statement {
            return &self.statement;
        }
    };

    var tt = TestTree{};
    try std.testing.expectEqualStrings("hello world", tt.statementExpr().node.tokenLiteral());
}
