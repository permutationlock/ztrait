const std = @import("std");
const trait = @import("trait.zig");
const Returns = trait.Returns;
const where = trait.where;

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.hasTypeId(.Int);

        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*Type) Type.Count;
    };
}

const MyCounter = struct {
    pub const Count = u32;

    count: Count,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};

const MyCounterWrongFn = struct {
    pub const Count = u32;

    count: Count,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This(), amount: Count) void {
        self.count += amount;
    }
    
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};

pub fn countWithBoth(comptime T: type, comptime U: type) Returns(void, .{
    where(T).implements(Incrementable),
    where(U).implements(Incrementable)
}) {
    var counter1 = T.init();
    while (counter1.read() < 10) {
        var counter2 = U.init();
        while (counter2.read() < 10) {
            counter2.increment();
        }
        counter1.increment();
    }
}

pub fn countToTen(ctrs: anytype) Returns(void, .{
    where(@TypeOf(ctrs)).hasTypeInfo(.{ .Pointer = .{ .size = .Slice } })
        .child().implements(Incrementable)
}) {
    for (ctrs) |*ctr| {
        while (ctr.read() < 10) {
            ctr.increment();
        }
    }
}

pub fn main() void {
    var counters = [2]MyCounter{ MyCounter.init(), MyCounter.init() };
    //var slice: []MyCounter = counters[0..];
    countToTen(counters[0..]);
}
