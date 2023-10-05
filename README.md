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
type that implements this trait. A special `AssociatedType` enum is defined to
allow traits to declare and constrain associated types. 

Below is a trait that requires implementing types to define a `Count` integer
type and provide an `init` funciton as well as member functions `increment` and
`decrement`.

```Zig
const trait = @import("trait.zig");

pub fn Incrementable(comptime Type: type) type {
    return struct {
        pub const Count = trait.AssociatedType.Int;

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
    comptime { trait.impl(Counter, Incrementable); }

    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

**Note:** If we don't place the trait verification inside a comptime block,
verification might be evaluated later during compilation which results in
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
trait.zig:36:13: error: 'main.MyCounterMissingDecl' fails to implement 'main.Incrementable(main.MyCounterMissingDecl)': missing decl 'increment'
            @compileError(prelude ++ ": missing decl '" ++ decl.name ++ "'");
            ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
main.zig:171:26: note: called from here
    comptime { trait.impl(Counter, Incrementable); }
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
trait.zig:50:17: error: 'main.MyCounterInvalidType' fails to implement 'main.Incrementable(main.MyCounterInvalidType)': decl 'Count' expected TypeId 'trait.AssociatedType.Int' but found 'trait.AssociatedType.Struct'
                @compileError(std.fmt.comptimePrint(
                ^~~~~~~~~~~~~
main.zig:171:26: note: called from here
    comptime { trait.impl(Counter, Incrementable); }
               ~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~
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
trait.zig:61:13: error: 'main.MyCounterWrongFn' fails to implement 'main.Incrementable(main.MyCounterWrongFn)': decl 'increment' expected type 'fn(*main.MyCounterWrongFn) void' but found 'fn(*main.MyCounterWrongFn, u32) void'
            @compileError(std.fmt.comptimePrint(
            ^~~~~~~~~~~~~
main.zig:171:26: note: called from here
    comptime { trait.impl(Counter, Incrementable); }
               ~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~
```
