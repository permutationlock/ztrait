const std = @import("std");
const trait = @import("trait.zig");
const Returns = trait.Returns;
const where = trait.where;

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.hasTypeId(.Int);

        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*const Type) Type.Count;
        pub const reset = fn (*Type) void;
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
    
    pub fn read(self: *const @This()) Count {
        return self.count;
    }

    pub fn reset(self: *@This()) void {
        self.count = 0;
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
    
    pub fn read(self: *const @This()) Count {
        return self.count;
    }

    pub fn reset(self: *@This()) void {
        self.count = 0;
    }
};

pub fn countWithBoth(c1: anytype, c2: anytype) Returns(void, .{
    where(@TypeOf(c1)).mutRef().implements(Incrementable),
    where(@TypeOf(c2)).mutRef().implements(Incrementable)
}) {
    c1.reset();
    while (c1.read() < 10) {
        c2.reset();
        while (c2.read() < 10) {
            c2.increment();
        }
        c1.increment();
    }
}

pub fn incrementAll(ctrs: anytype) Returns(void, .{
    where(@TypeOf(ctrs)).coercesToMutSlice().implements(Incrementable)
}) {
    for (ctrs) |*ctr| {
        while (ctr.read() < 10) {
            ctr.increment();
        }
    }
}

pub fn main() void {
    const counters = [2]MyCounter{ MyCounter.init(), MyCounter.init() };
    incrementAll(&counters);
    countWithBoth(&counters[0], &counters[1]);
}
