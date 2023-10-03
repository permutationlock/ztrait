# Zig Type Traits

A simplified version of Rust style type traits for Zig.

## Example

A trait is simply a comptime function taking a type and returning a struct.
Below is a trait that requires implementing types to define a Count integer type
and provide an `init` funciton as well as member functions `increment` and
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

Each declaration of the returned struct defines a required declaration for any
type that implements this trait. A special `AssociatedType` enum is defined to
allow traits to declare and constrain associated types. 

An example type that implements the above `Incrementable` trait is provided
below.

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
need to add a small `comptime` block at the start of the function.

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

If we define a type that fails to implement the `Incrementable` trait and pass
it to `countToTen` we get a nice compile error.

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
