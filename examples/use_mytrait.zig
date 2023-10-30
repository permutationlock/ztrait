const std = @import("std");
const trait = @import("mytrait.zig");

pub fn addToPackedStruct(
    s1: anytype,
    n: trait.BackingInteger(@TypeOf(s1))
) trait.BackingInteger(@TypeOf(s1)) {
    return @as(@TypeOf(n), @bitCast(s1)) + n;
}

pub fn main() void {
    const S = packed struct {
        a: u16, b: u16
    };

    const s: S = .{ .a = 0x0, .b = 0xaa };
    const n1: u32 = 0xaa;
    std.debug.print("sum: {x}\n", .{ addToPackedStruct(s, n1) });
}
