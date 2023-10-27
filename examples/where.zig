const std = @import("std");
const trait = @import("trait");

const Child = std.meta.Child;

const Returns = trait.Returns;
const where = trait.where;
const coercesToConstSliceOf = trait.coercesToConstSliceOf;
const isMutPointerTo = trait.isMutPointerTo;
const hasTypeId = trait.hasTypeId;
const is = trait.is;

// a function takeing an arg of single item ponter typ *I with I an integer type
// and a second arg of a pointer type L that can coerce to []I
pub fn sumIntSlice(count_ptr: anytype, list: anytype) Returns(void, .{
    where(@TypeOf(count_ptr), isMutPointerTo(hasTypeId(.Int))),
    where(@TypeOf(list), coercesToConstSliceOf(is(Child(@TypeOf(count_ptr)))))
}) {
    for (list) |elem| {
        count_ptr.* += elem;
    }
}

pub fn main() void {
    {
        const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        var sum: i32 = 0;
        sumIntSlice(&sum, &list);
        std.debug.print("sum: {d}\n", .{sum});
    }

    // Uncomment each of the following to see the errors
    //{
    //    const list = [_]i64{ 1, -1, 2, -3, 5, -8, 13, -21 };
    //    var sum: i32 = 0;
    //    sumIntSlice(&sum, &list);
    //    std.debug.print("sum: {d}\n", .{sum});
    //}
    //{
    //    const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
    //    const sum: i32 = 0;
    //    sumIntSlice(&sum, &list);
    //    std.debug.print("sum: {d}\n", .{sum});
    //}
    //{
    //    const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
    //    var sum: f32 = 0;
    //    sumIntSlice(&sum, &list);
    //    std.debug.print("sum: {d}\n", .{sum});
    //}
    {
        const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
        var sum: i32 = 0;
        sumIntSlice(&sum, list);
        std.debug.print("sum: {d}\n", .{sum});
    }
    //{
    //    const list = [_]i32{ 1, -1, 2, -3, 5, -8, 13, -21 };
    //    var sum: i32 = 0;
    //    sumIntSlice(sum, &list);
    //    std.debug.print("sum: {d}\n", .{sum});
    //}
}
