const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("monkylang", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const ast_tests = b.addTest("src/ast.zig");
    ast_tests.setTarget(target);
    ast_tests.setBuildMode(mode);

    const lexer_tests = b.addTest("src/lexer.zig");
    lexer_tests.setTarget(target);
    lexer_tests.setBuildMode(mode);

    const parser_tests = b.addTest("src/parser.zig");
    parser_tests.setTarget(target);
    parser_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&lexer_tests.step);
    test_step.dependOn(&parser_tests.step);
    test_step.dependOn(&ast_tests.step);
}
