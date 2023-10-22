const std = @import("std");

const trait = @import("trait.zig");

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.hasTypeId(.Int);

        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*Type) Type.Count;
    };
}

pub fn HasIncrementable(comptime _: type) type {
    return struct {
        pub const Counter = trait.hasTypeId(.Optional).hasChild(
            trait.hasTypeId(.Pointer).hasChild(
                trait.implements(Incrementable)
            )
        );
    };
}

pub const MyCounter = struct {
    //comptime { trait.implements(Incrementable).assert(@This()); }

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

pub const CounterHolder = struct {
    comptime { trait.implements(HasIncrementable).assert(@This()); }

    pub const Counter = ?*MyCounter;
};

pub fn main() void {
    //comptime { trait.implements(Incrementable).assert(MyCounter); }
}

test {
    std.testing.refAllDecls(@This());
}
