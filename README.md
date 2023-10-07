# Zig Type Traits

A simple version of Rust style type traits for Zig. Allows defining traits
and compile-time verifying that types satisfy them.

**Note:** Nothing is done to require that every declaration referenced on a type
must belong to a trait that was implemented. In other words, duck-typing still
works as usual, but trait verification runs first. Therefure the library mainly
serves as a convention that provides nice error messages and type documentation.

## Basic use

A trait is simply a comptime function taking a type and returning a struct.
Each declaration of the returned struct defines a required declaration that the
type must have if it implements the trait. 

Below is a trait that requires implementing types to define an integer
sub-type `Count`, define an `init` funciton, and define member functions
`increment` and `read`.

```Zig
const trait = @import("trait.zig");

pub fn Incrementable(comptime Type: type) type {
    return struct {
        // below is the same as `pub const Count = type` except that during
        // trait verification it requires that '@typeInfo(Type.Count) == .Int'
        pub const Count = trait.is(.Int);

        pub const init = fn () Type;
        pub const increment = fn (*Type) void;
        pub const read = fn (*Type) Type.Count;
    };
}
```

A type that implements the above `Incrementable` trait is provided below.

```Zig
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
```

To require that a generic type parameter implenents a given trait you simply
need to add a comptime verification block at the start of the function.

```Zig
const trait = @import("trait.zig");

pub fn countToTen(comptime Counter: type) void {
    comptime { trait.implements(Incrementable).assert(Counter); }
    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

**Note:** If we don't place the trait verification inside a comptime block then
verification might be evaluated later during compilation. This results in
regular duck-typing errors rather than trait implementation errors.

If we define a type that fails to implement the `Incrementable` trait and pass
it to `countToTen`, then `assert` will produce a compile error.

```Zig
const MyCounterMissingDecl = struct {
    pub const Count = u32;

    count: Count,

    pub fn init() @This() {
        return .{ .count = 0 };
    }
 
    pub fn read(self: *@This()) Count {
        return self.count;
    }
};
```

```Shell
trait.zig:138:17: error: trait 'main.Incrementable(main.MyCounterMissingDecl)' failed: missing decl 'increment'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
main.zig:177:54: note: called from here
    comptime { trait.implements(Incrementable).assert(Counter); }
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~
```

```Zig
const MyCounterInvalidType = struct {
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
```

```Shell
trait.zig:138:17: error: trait 'main.Incrementable(main.MyCounterInvalidType)' failed: decl 'Count': expected 'trait.TypeId.Int', found 'trait.TypeId.Struct'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
main.zig:177:54: note: called from here
    comptime { trait.implements(Incrementable).assert(Counter); }
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~
```

```Zig
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
```

```Shell
trait.zig:138:17: error: trait 'main.Incrementable(main.MyCounterWrongFn)' failed: decl 'increment': expected 'fn(*main.MyCounterWrongFn) void', found 'fn(*main.MyCounterWrongFn, u32) void'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
main.zig:177:54: note: called from here
    comptime { trait.implements(Incrementable).assert(Counter); }
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~
```

## Recursion

Traits can require that each implementing type defines a subtype
that is itself constrained by a trait.

```Zig
pub fn HasIncrementable(comptime _: type) type {
    return struct {
        pub const Counter = trait.implements(Incrementable);
    };
}

```

```Zig
pub fn useHolderToCountToTen(comptime T: type) void {
    comptime { trait.implements(HasIncrementable).assert(T); }
    var counter = T.Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

```Zig
pub const CounterHolder = struct {
    pub const Counter = MyCounter;
};

pub const InvalidCounterHolder = struct {
    pub const Counter = MyCounterMissingDecl;
};
```

```Shell
trait.zig:138:17: error: trait 'main.HasIncrementable(main.InvalidCounterHolder)' failed: decl 'Counter': trait 'main.Incrementable(main.MyCounterMissingDecl)' failed: missing decl 'increment'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
main.zig:200:57: note: called from here
    comptime { trait.implements(HasIncrementable).assert(T); }
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~
```

## Verifying that a type implements a trait in its definition

Alongside enforcing trait implementation in generic functions, types can
call assert directly in their definition to declare that they implement a given
trait.

```Zig
const MyCounter = struct {
    comptime { trait.implements(Incrementable).assert(@This()); }

    // ...
};
```

Then with `testing.refAllDecls` you can run `zig test` to automatically verify
that these traits are implemented.

```Zig
test {
    std.testing.refAllDecls(@This);
}
```

Credit to "NewbLuck" on the Zig Discord for pointing out this nice pattern.
