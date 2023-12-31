const std = @import("std");
const ztrait = @import("ztrait");

const SliceChild = ztrait.SliceChild;
const where = ztrait.where;
const isNumber = ztrait.isNumber;

pub fn sumNumbers(list: anytype) SliceChild(@TypeOf(list)) {
    comptime where(SliceChild(@TypeOf(list)), isNumber());

    var count: SliceChild(@TypeOf(list)) = 0;
    for (list) |elem| {
        count += elem;
    }
    return count;
}


pub fn main() void {
    {
        const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        const sum = sumNumbers(&list);
        std.debug.print("sum: {d}\n", .{sum});
    }
    {
        const list = [_]f32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        const sum = sumNumbers(&list);
        std.debug.print("sum: {e}\n", .{sum});
    }
}
