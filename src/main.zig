const std = @import("std");
const Lexer = @import("lexer.zig");

const Arena = std.heap.ArenaAllocator;
fn startRepl(allocator: std.mem.Allocator, reader: anytype, writer: anytype) !void {
    var buf: [1024]u8 = undefined;
    while (true) {
        try writer.print("> ", .{});
        if (try reader.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            var lexer = try Lexer.init(allocator, user_input);
            defer lexer.deinit();
            var tok = lexer.nextToken();
            while (tok != .eof) : (tok = lexer.nextToken()) {
                std.debug.print("{}\n", .{tok});
            }
        } else {
            break;
        }
    }
}
pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var arena = Arena.init(std.heap.page_allocator);
    defer arena.deinit();
    const user = std.os.getenv("USER");
    if (user) |use| {
        try stdout.print("Hello {s}! This is the Monkey programming language!\n", .{use});
        try stdout.print("Feel free to type in commands\n", .{});
        try startRepl(arena.allocator(), stdin, stdout);
    }
}
