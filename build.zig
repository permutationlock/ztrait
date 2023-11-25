const std = @import("std");
const Builder = std.build.Builder;

const Test = struct { name: []const u8, path: []const u8 };
const paths = [_]Test{
    .{ .name = "count", .path = "examples/count.zig" },
    .{ .name = "reader", .path = "examples/reader.zig" },
};

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ztrait = b.addModule("ztrait", .{
        .source_file = .{ .path = "src/ztrait.zig" },
    });

    const test_step = b.step("test", &.{});
    inline for (paths) |example| {
        const exe = b.addTest(.{
            .name = example.name,
            .root_source_file = .{ .path = example.path },
            .target = target,
            .optimize = optimize
        });
        exe.addModule("ztrait", ztrait);
        test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
