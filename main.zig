const std = @import("std");

const trait = @import("trait.zig");

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.is(.Int);

        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*Type) Type.Count;
    };
}

pub fn HasDimensions(comptime _: type) type {
    return struct {
        pub const width = comptime_int;
        pub const height = comptime_int;
    };
}

pub fn HasIncrementable(comptime _: type) type {
    return struct {
        pub const Counter = trait.implements(Incrementable);
    };
}

const MyCounter = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

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

const MyCounterMissingType = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

    count: u32,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn read(self: *@This()) u32 {
        return self.count;
    }
};

const MyCounterMissingDecl = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

    pub const Count = u32;

    count: Count,

    pub fn init() @This() {
        return .{ .count = 0 };
    }
 
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};

const MyCounterInvalidType = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

    pub const Count = struct { n: u32 };
    count: Count,

    pub fn init() @This() {
        return .{ .count = .{ .n = 0} };
    }

    pub fn increment(self: *@This()) void {
        self.count.n += 1;
    }
    
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};

const MyCounterWrongFn = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

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

const MyCounterWithDimensions = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }
    comptime { trait.implements(HasDimensions).assert(@This()); }

    pub const Count = u32;
    pub const width = 640;
    pub const height = 480;

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

const MyCounterUnion = union(enum) {
    comptime { trait.implements(Incrementable).assert(@This()); }

    pub const Count = u64;

    short: u32,
    long: u64,

    pub fn init() @This() {
        return .{ .long = 0 };
    }

    pub fn increment(self: *@This()) void {
        switch (self.*) {
            inline else => |*count| count.* += 1,
        }
    }
    
    pub fn read(self: *@This()) Count {
        switch (self.*) {
            inline else => |count| return count,
        }
    }
};

const MyCounterEnum = enum(u32) {
    comptime { trait.implements(Incrementable).assert(@This()); }

    pub const Count = u32;

    red = 0,
    green,
    blue,

    _,

    pub fn init() @This() {
        return .red;
    }

    pub fn increment(self: *@This()) void {
        self.* = @enumFromInt(@intFromEnum(self.*) + 1);
    }
    
    pub fn read(self: *@This()) Count {
        return @intFromEnum(self.*);
    }
};

pub fn countToTen(comptime Counter: type) void {
    comptime { trait.implements(Incrementable).assert(Counter); }
    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}

pub fn computeArea(comptime T: type) comptime_int {
    comptime { trait.implements(HasDimensions).assert(T); }
    return T.width * T.height;
}

pub fn computeAreaAndCount(comptime T: type) void {
    comptime {
        trait.implementsAll(.{ Incrementable, HasDimensions }).assert(T);
    }
    var counter = T.init();
    while (counter.read() < T.width * T.height) {
        counter.increment();
    }
}

pub fn useHolderToCountToTen(comptime T: type) void {
    comptime { trait.implements(HasIncrementable).assert(T); }
    var counter = T.Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}

pub const CounterHolder = struct {
    comptime { trait.implements(HasIncrementable).assert(@This()); }

    pub const Counter = MyCounter;
};

pub const InvalidCounterHolder = struct {
    comptime { trait.implements(HasIncrementable).assert(@This()); }

    pub const Counter = MyCounterMissingDecl;
};

pub fn main() void {
    // these should all silently work without errors
    countToTen(MyCounter);
    countToTen(MyCounterWithDimensions);
    countToTen(MyCounterEnum);
    countToTen(MyCounterUnion);
    computeAreaAndCount(MyCounterWithDimensions);
    useHolderToCountToTen(CounterHolder);
    _ = computeArea(MyCounterWithDimensions);

    // each of these should produce a compile error
    countToTen(MyCounterMissingType);
    countToTen(MyCounterMissingDecl);
    countToTen(MyCounterInvalidType);
    countToTen(MyCounterWrongFn);
    computeAreaAndCount(MyCounterEnum);
    useHolderToCountToTen(MyCounter);
    useHolderToCountToTen(InvalidCounterHolder);
    _ = computeArea(MyCounter);    
}

test {
    std.testing.refAllDecls(@This());
}
