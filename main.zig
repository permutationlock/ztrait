const std = @import("std");

const trait = @import("trait.zig");

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*Type) Type.Count;

        pub const Count: trait.AssociatedType = .Int;
    };
}

pub fn HasDimensions(comptime _: type) type {
    return struct {
        pub const width = comptime_int;
        pub const height = comptime_int;
    };
}

const MyType = struct {
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

const MyTypeMissingType = struct {
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

const MyTypeMissingDecl = struct {
    pub const Count = u32;

    count: Count,

    pub fn init() @This() {
        return .{ .count = 0 };
    }
 
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};

const MyTypeInvalidType = struct {
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

const MyTypeWrongFn = struct {
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

const MyTypeExpanded = struct {
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

const MyUnion = union(enum) {
    pub const Count = u64;

    short: u32,
    long: u64,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        switch (self.*) {
            inline else => |*count| count += 1,
        }
    }
    
    pub fn read(self: *@This()) Count {
        switch (self.*) {
            inline else => |count| return count,
        }
    }
};

const MyEnum = enum(u32) {
    pub const Count = u32;

    red = 0,
    green,
    blue,

    _,

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

pub fn area(comptime T: type) comptime_int {
    trait.impl(T, HasDimensions);
    return T.width * T.height;
}

pub fn main() void {
    // these should all succeed
    trait.impl(MyType, Incrementable);
    trait.impl(MyTypeExpanded, Incrementable);
    trait.implAll(MyTypeExpanded, .{Incrementable, HasDimensions});
    trait.impl(MyEnum, Incrementable);
    trait.impl(MyUnion, Incrementable);
    std.debug.print("{} area: {}\n", .{MyTypeExpanded, area(MyTypeExpanded)});

    // each of these should produce a compile error
    trait.impl(MyTypeMissingType, Incrementable);
    trait.impl(MyTypeMissingDecl, Incrementable);
    trait.impl(MyTypeInvalidType, Incrementable);
    trait.impl(MyTypeWrongFn, Incrementable);
    trait.implAll(MyType, .{Incrementable, HasDimensions});
    std.debug.print("{} area: {}\n", .{MyType, area(MyType)});
}
