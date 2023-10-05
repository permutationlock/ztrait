# Zig Type Traits

A simple version of Rust style type traits for Zig. Allows defining type traits
and compile time verifying that types satisfy them.

It does not constrain that every declaration referenced on a type
must belong to a trait that was implemented. Thus
this trait library mainly serves as a convention that provides nice error
messages and type documentation for comptime generics.

## Example

A trait is simply a comptime function taking a type and returning a struct.
Each declaration of the returned struct defines a required declaration for any
type that implements this trait. 

Below is a trait that requires implementing types to define an integer subtype
`Count`, provide an `init` funciton, and provide the member functions
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
it to `countToTen`, then `trait.impl` will produce a descriptive compile error.

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
trait.zig:138:17: error: 'main.MyCounterMissingDecl' failed to implement 'main.Incrementable(main.MyCounterMissingDecl)': missing decl 'increment'
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
trait.zig:138:17: error: 'main.MyCounterInvalidType' failed to implement 'main.Incrementable(main.MyCounterInvalidType)': decl 'Count': expected 'trait.TypeId.Int' but found 'trait.TypeId.Struct'
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
trait.zig:138:17: error: 'main.MyCounterWrongFn' failed to implement 'main.Incrementable(main.MyCounterWrongFn)': decl 'increment': expected 'fn(*main.MyCounterWrongFn) void' but found 'fn(*main.MyCounterWrongFn, u32) void'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
```

We can even define a trait that requires implementing types to define a subtype
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

```Zig
trait.zig:138:17: error: 'main.InvalidCounterHolder' failed to implement 'main.HasIncrementable(main.InvalidCounterHolder)': decl 'Counter': 'main.MyCounterMissingDecl' failed to implement 'main.Incrementable(main.MyCounterMissingDecl)': missing decl 'increment'
                @compileError(reason);
                ^~~~~~~~~~~~~~~~~~~~~
main.zig:201:50: note: called from here
        trait.implements(HasIncrementable).assert(T);
        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~
```

Hooray! We have successfully implemented C++ template type errors in Zig...
