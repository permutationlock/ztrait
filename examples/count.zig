const std = @import("std");
const ztrait = @import("ztrait");

const Impl = ztrait.Impl;
const PtrChild = ztrait.PtrChild;
const implements = ztrait.implements;
const hasTypeId = ztrait.hasTypeId;

pub fn Incrementable(comptime Self: type) ztrait.Interface {
    return .{
        .Requires = struct {
            pub const Count = hasTypeId(.Int);

            pub const increment = fn (*Self) void;
            pub const read = fn (*const Self) Self.Count;
        },
        .Using = struct {
            pub fn add(self: *Self, n: Self.Count) void {
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    Self.increment(self);
                }
            }
        },
    };
}

pub fn countToTen(
    ctr_data: anytype,
    comptime ctr_impl: Impl(PtrChild(@TypeOf(ctr_data)), Incrementable),
) void {
    while (ctr_impl.read(ctr_data) < 10) {
        ctr_impl.increment(ctr_data);
    }
}

const MyCounter = struct {
    count: u32,

    pub const Count = u32;

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }

    pub fn read(self: *const @This()) u32 {
        return self.count;
    }
};

test "count with struct" {
    var counter = MyCounter{ .count = 0 };
    countToTen(&counter, .{});
    try std.testing.expectEqual(@as(MyCounter.Count, 10), counter.read());
}

const MyCounterUnion = union(enum) {
    short: u32,
    long: u64,

    pub const Count = u64;

    pub fn init() @This() {
        return .{ .long = 0 };
    }

    pub fn increment(self: *@This()) void {
        switch (self.*) {
            inline else => |*count| count.* += 1,
        }
    }

    pub fn read(self: *const @This()) Count {
        switch (self.*) {
            inline else => |count| return count,
        }
    }
};

test "count with union" {
    var counter = MyCounterUnion{ .short = 0 };
    countToTen(&counter, .{});
    try std.testing.expectEqual(@as(MyCounterUnion.Count, 10), counter.read());
}

const MyCounterEnum = enum(u32) {
    red = 0,
    green,
    blue,

    _,

    pub const Count = u32;

    pub fn init() @This() {
        return .red;
    }

    pub fn increment(self: *@This()) void {
        self.* = @enumFromInt(@intFromEnum(self.*) + 1);
    }

    pub fn read(self: *const @This()) Count {
        return @intFromEnum(self.*);
    }
};

test "count with enum" {
    var counter = MyCounterEnum.red;
    countToTen(&counter, .{});
    try std.testing.expectEqual(@as(MyCounterEnum.Count, 10), counter.read());
}

pub fn HasIncrementable(comptime Type: type) ztrait.Interface {
    return .{
        .Requires = struct {
            pub const Counter = implements(Incrementable);
            pub const getCounter = fn (*Type) *Type.Counter;
        },
    };
}

pub fn countWithContainedCounter(
    hldr_data: anytype,
    comptime hldr_impl: Impl(PtrChild(@TypeOf(hldr_data)), HasIncrementable),
) void {
    const counter = hldr_impl.getCounter(hldr_data);
    countToTen(counter, .{});
}

const MyCounterHolder = struct {
    counter: MyCounter = .{ .count = 0 },

    pub const Counter = MyCounter;

    pub fn getCounter(self: *@This()) *Counter {
        return &self.counter;
    }
};

test "count with contained counter" {
    var holder = MyCounterHolder{};
    countWithContainedCounter(&holder, .{});
    try std.testing.expectEqual(
        @as(MyCounter.Count, 10),
        holder.counter.read(),
    );
}

test "override member function" {
    const Local = struct {
        pub fn myIncrement(self: *MyCounter) void {
            self.count = self.count * 2 + 1;
        }
    };
    var counter = MyCounter{ .count = 0 };
    countToTen(&counter, .{ .increment = Local.myIncrement });
    try std.testing.expectEqual(@as(MyCounter.Count, 15), counter.read());
}

pub fn countToTenAllAtOnce(
    ctr_data: anytype,
    comptime ctr_impl: Impl(PtrChild(@TypeOf(ctr_data)), Incrementable),
) void {
    const diff: i63 = 10 - ctr_impl.read(ctr_data);
    ctr_impl.add(ctr_data, @intCast(diff));
}

test "count all at once" {
    var counter = MyCounter{ .count = 0 };
    countToTenAllAtOnce(&counter, .{});
    try std.testing.expectEqual(@as(MyCounter.Count, 10), counter.read());
}
