const std = @import("std");
const trait = @import("trait.zig");
const Returns = trait.Returns;
const where = trait.where;
const coercesToConstSliceOf = trait.coercesToConstSliceOf;
const isMutPointerTo = trait.isMutPointerTo;
const hasTypeId = trait.hasTypeId;
const is = trait.is;

pub fn sumIntSlice(count_ptr: anytype, list: anytype) Returns(void, .{
    where(@TypeOf(count_ptr), isMutPointerTo(hasTypeId(.Int))),
    where(@TypeOf(list), coercesToConstSliceOf(
        is(@typeInfo(@TypeOf(count_ptr)).Pointer.child)
    ))
}) {
    for (list) |elem| {
        count_ptr.* += elem;
    }
}

pub fn main() void {
    const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
    var sum: i32 = 0;
    sumIntSlice(&sum, &list);
    std.debug.print("sum: {d}\n", .{sum});
}
