const std = @import("std");
const trait = @import("trait");

const Interface = trait.Interface;

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const increment = fn (*Type) void;
        pub const read = fn (*const Type) usize;
    };
}

const MyCounter = struct {
    count: usize,

    pub fn increment(self: *@This()) void {
        self.count += 1;
    }
    
    pub fn read(self: *const @This()) usize {
        return self.count;
    }
};

const MyCounterMissingDecl = struct {
    count: usize,
 
    pub fn read(self: *const @This()) usize {
        return self.count;
    }
};

const MyCounterWrongFn = struct {
    count: usize,

    pub fn increment(self: *@This(), amt: usize) void {
        self.count += amt;
    }
    
    pub fn read(self: *const @This()) usize {
        return self.count;
    }
};

pub fn countToTen(
    counter: anytype,
    Ifc: Interface(@TypeOf(counter), Incrementable)
) void {
    while (Ifc.read(counter) < 10) {
        Ifc.increment(counter);
    }
}

const USize = struct {
    pub fn increment(i: *usize) void {
        i.* += 1;
    }

    pub fn read(i: *const usize) usize {
        return i.*;
    }
};


pub fn main() void {
    // these should all silently work without errors
    var count: usize = 0;
    countToTen(&count, .{ .increment = USize.increment, .read = USize.read });

    var counter: MyCounter = .{ .count = 0 };
    countToTen(&counter, .{});

    var counter_missing_decl: MyCounterMissingDecl = .{ .count = 0 };
    const CustomImpl = struct {
        pub fn increment(self: *MyCounterMissingDecl) void {
            self.count += 1;
        }
    };
    countToTen(&counter_missing_decl, .{ .increment = CustomImpl.increment });

    // each of these should produce a compile error
    //countToTen(&counter_missing_decl, .{});

    //var counter_wrong_fn: MyCounterWrongFn = .{ .count = 0 };
    //countToTen(&counter_wrong_fn, .{});
}
