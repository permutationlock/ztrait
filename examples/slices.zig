const std = @import("std");
const trait = @import("trait");

const SliceChild = trait.SliceChild;
const where = trait.where;
const hasTypeId = trait.hasTypeId;

pub fn sumIntSlice(list: anytype) SliceChild(@TypeOf(list)) {
    const I = SliceChild(@TypeOf(list));
    comptime where(I, hasTypeId(.Int));

    var count: I = 0;
    for (list) |elem| {
        count += elem;
    }
    return count;
}


pub fn main() void {
    {
        const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        const sum = sumIntSlice(&list);
        std.debug.print("sum: {d}\n", .{sum});
    }

    // Uncomment each of the following to see the errors
    {
        const list = [_]f32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        const sum = sumIntSlice(&list);
        std.debug.print("sum: {d}\n", .{sum});
    }
    //{
    //    const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
    //    const sum = sumIntSlice(list);
    //    std.debug.print("sum: {d}\n", .{sum});
    //}
}
