const std = @import("std");
const Builder = std.build.Builder;

const Example = struct { name: []const u8, path: []const u8 };
const paths = [_]Example{
    .{ .name = "incrementable", .path = "examples/incrementable.zig" },
    .{ .name = "where", .path = "examples/where.zig" },
    .{ .name = "mytrait", .path = "examples/use_mytrait.zig" },
};

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const trait = b.addModule("trait", .{
        .source_file = .{ .path = "trait.zig" },
    });

    inline for (paths) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = .{ .path = example.path },
            .target = target,
            .optimize = optimize
        });
        exe.addModule("trait", trait);
        const run_step = b.step(example.name, &.{});
        run_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
