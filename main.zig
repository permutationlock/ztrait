const std = @import("std");

const trait = @import("trait.zig");

pub fn MyTrait(comptime Type: type) type {
    return struct {
        pub const size = comptime_int;
        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
    };
}

pub fn HasDimensions(comptime _: type) type {
    return struct {
        pub const width = comptime_int;
        pub const height = comptime_int;
    };
}

const MyType = struct {
    pub const size = 32;

    count: u32,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
};

const MyTypeMissingDecl = struct {
    count: u32,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
};

const MyTypeWrongFn = struct {
    pub const size = 32;

    count: u32,

    pub fn init() @This() {
        return .{ .count = 0 };
    }

    pub fn increment(self: *@This(), amount: u32) void {
        self.count += amount;
    }
};

const MyTypeExpanded = struct {
    pub const size = 32;
    pub const width = 640;
    pub const height = 480;

    count: u32,
    health: u32,

    pub fn init() @This() {
        return .{ .count = 0, .health = 10 };
    }

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn damage(self: *@This()) void {
        self.health -= 1;
    }
};

const MyUnion = union(enum) {
    pub const size = 64;

    short: u32,
    long: u64,

    pub fn init() @This() {
        return .{ .long = 0 };
    }

    pub fn increment(self: *@This()) void {
        switch (self.*) {
            inline else => |*count| count += 1,
        }
    }
};

const MyEnum = enum(u32) {
    pub const size = 32;

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
};

pub fn main() void {
    // these should all silently succeed
    trait.impl(MyType, MyTrait);
    trait.impl(MyTypeExpanded, MyTrait);
    trait.implAll(MyTypeExpanded, .{MyTrait, HasDimensions});
    trait.impl(MyUnion, MyTrait);
    trait.impl(MyEnum, MyTrait);

    // each of these should produce a compile error
    trait.impl(MyTypeMissingDecl, MyTrait);
    trait.impl(MyTypeWrongFn, MyTrait);
    trait.implAll(MyType, .{MyTrait, HasDimensions});
}
