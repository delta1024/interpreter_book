const std = @import("std");
const Tuple = std.meta.Tuple;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig");
const Token = Lexer.Token;
const TokenType = Lexer.TokenType;
const Err = error{OutOfMemory};
const Vtable = struct {
    literal_fn: *const fn (*anyopaque) TokenType,
    deinit_fn: *const fn (*anyopaque, Allocator) void,
};

pub const Node = struct {
    const Ptr = *anyopaque;
    const Self = @This();
    ptr: Ptr,
    vtable: Vtable,
    pub fn tokenLiteral(self: Self) TokenType {
        return self.vtable.literal_fn(self.ptr);
    }
    pub fn deinit(self: Self, allocator: Allocator) void {
        self.vtable.deinit_fn(self.ptr, allocator);
    }
};

pub const Statement = struct {
    const Ptr = *anyopaque;
    const Self = @This();
    ptr: Ptr,
    vtable: Vtable,
    pub fn tokenLiteral(self: Self) TokenType {
        return self.vtable.literal_fn(self.ptr);
    }
    pub fn deinit(self: Self, allocator: Allocator) void {
        self.vtable.deinit_fn(self.ptr, allocator);
    }
    pub fn node(self: Self) Node {
        return .{
            .ptr = self.ptr,
            .vtable = self.vtable,
        };
    }
};

pub const Expression = struct {
    const Ptr = *anyopaque;
    const Self = @This();
    ptr: Ptr,
    vtable: Vtable,
    pub fn tokenLiteral(self: Self) TokenType {
        return self.vtable.literal_fn(self.ptr);
    }
    pub fn deinit(self: Self, allocator: Allocator) void {
        self.vtable.deinit_fn(self.ptr, allocator);
    }
    pub fn node(self: Self) Node {
        return .{
            .ptr = self.ptr,
            .vtable = self.vtable,
        };
    }
};

pub const Program = struct {
    statements: ArrayList(Statement),
    pub fn init(allocator: Allocator) Program {
        return .{
            .statements = ArrayList(Statement).init(allocator),
        };
    }
    pub fn deinit(self: *Program, allocator: Allocator) void {
        for (self.statements) |s| {
            s.deinit(allocator);
        }
    }
};
pub const LetStatement = struct {
    id: TokenType,
    name: Identifier,
    value: ?Expression,
    fn acceptTokenLiteral(s: *anyopaque) TokenType {
        const self = @ptrCast(*LetStatement, @alignCast(@alignOf(LetStatement), s));
        return self.tokenLiteral();
    }
    fn acceptDeinit(s: *anyopaque, allocator: Allocator) void {
        const self = @ptrCast(*LetStatement, @alignCast(@alignOf(LetStatement), s));
        self.deinit(allocator);
    }
    pub fn deinit(self: *LetStatement, allocator: Allocator) void {
        // allocator.destroy(self.name);
        if (self.value) |v| {
            v.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn tokenLiteral(self: *LetStatement) TokenType {
        return self.id;
    }
    pub fn statement(self: *LetStatement) Statement {
        return .{
            .ptr = self,
            .vtable = .{ .literal_fn = acceptTokenLiteral, .deinit_fn = acceptDeinit },
        };
    }
};
pub const Identifier = struct {
    id: TokenType,
    value: []const u8,
    fn acceptTokenLiteral(s: *anyopaque) TokenType {
        const self = @ptrCast(*Identifier, @alignCast(@alignOf(Identifier), s));
        return self.tokenLiteral();
    }
    fn acceptDeinit(s: *anyopaque, allocator: Allocator) void {
        const self = @ptrCast(*Identifier, @alignCast(@alignOf(Identifier), s));
        self.deinit(allocator);
    }
    pub fn tokenLiteral(self: *Identifier) TokenType {
        return self.id;
    }
    pub fn deinit(self: *Identifier, allocator: Allocator) void {
        allocator.destroy(self);
    }
    pub fn expression(self: *Identifier) Expression {
        return .{
            .ptr = self,
            .vtable = .{ .literal_fn = acceptTokenLiteral, .deinit_fn = acceptDeinit },
        };
    }
};
