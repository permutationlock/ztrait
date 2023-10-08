const std = @import("std");
const trait = @import("trait.zig");
const Returns = trait.Returns;
const where = trait.where;

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.is(.Int);

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

pub fn countToTen(comptime T: type, comptime U: type) Returns(void, .{
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

pub fn main() void {
    countToTen(MyCounter, MyCounterWrongFn);
}
