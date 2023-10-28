const std = @import("std");
const trait = @import("mytrait.zig");

pub fn addU32PackedStructs(s1: anytype, s2: anytype) u32 {
    comptime trait.where(@TypeOf(s1), trait.isU32PackedStruct());
    comptime trait.where(@TypeOf(s2), trait.isU32PackedStruct());

    return @as(u32, @bitCast(s1)) + @as(u32, @bitCast(s2));
}

pub fn main() void {
    const S1 = packed struct {
        a: u16, b: u16
    };
    const S2 = packed struct {
        a: u8, b: u8, c: u8, d: u8
    };

    const s1: S1 = .{ .a = 15, .b = 0xaa };
    const s2: S2 = .{ .a = 'o', .b = 'h', .c = 0, .d = 0 };
    std.debug.print("sum: {x}\n", .{ addU32PackedStructs(s1, s2) });
}
