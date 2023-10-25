# Zig Type Traits

A simple version of Rust style type traits for Zig. Allows defining traits
and compile-time verifying that types satisfy them.

**Note:** Nothing is done to require that every declaration referenced on a type
must belong to a trait that was implemented. In other words, duck-typing still
works as usual, but trait verification runs first. Therefore the library mainly
serves as a convention that provides nice error messages and type documentation.

## Related links
 - [Zig Compile-Time-Contracts](https://github.com/yrashk/zig-ctc)
 - [Ziggit discussion on type constraints in function definitions](https://ziggit.dev/t/implementing-generic-concepts-on-function-declarations/1490/29)
 - Zig issue discussions: [#1268](https://github.com/ziglang/zig/issues/1268), [#6615](https://github.com/ziglang/zig/issues/6615), [#17198](https://github.com/ziglang/zig/issues/17198) (I don't have a strong position on these proposals, I respect the Zig team's reasoning for keeping the type system simple)

## Basic use

A trait is simply a comptime function taking a type and returning a struct type.
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
        pub const Count = trait.hasTypeId(.Int);

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
    comptime trait.implements(Incrementable).assert(Counter);
    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

**Note:** If we don't specify that the trait verification is comptime then
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

## Pointers and slices with `anytype`

With the ability to verify `@typeInfo` properties as well, we can constrain
`anytype` parameters to be pointers to types implementing traits. The
following function takes a mutable pointer `*T` to a type `T` that implements
the `Incrementable` interface from above.

```
pub fn countToTen(counter: anytype) usize {
    comptime trait.hasTypeInfo(.{
            .Pointer = .{ .size = .One, .is_const = false }
        }).hasChild(
            trait.implements(Incrementable)
        ).assert(@TypeOf(counter));
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

Using the available primitives, it is possible to create helper functions
that e.g. constrain an `anytype` parameter to be a type that can
coerce to a slice `[]T` where `T` is further constrained.

The following function takes a mutable single item pointer `*I` where
`I` is an integer type, and a second const pointer type `L` where `L` coerces
to the slice type `[]const I`.

```
const meta = @import("std").meta;

pub fn sumIntSlice(count_ptr: anytype, list: anytype) void {
    comptime {
        isMutPointerTo(hasTypeId(.Int)).assert(@TypeOf(count_ptr));
        coercesToConstSliceOf(is(meta.Child(@TypeOf(count_ptr))))
            .assert(@TypeOf(list));
    }

    for (list) |elem| {
        count_ptr.* += elem;
    }
}
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

## Traits in function definitions: 'where' syntax

Sometimes it can be useful to have type signatures directly in function
definitions. Zig currently does not support that, but with a few hacks we can
accomplish a janky version of Rust's `where` syntax.

```Zig
pub fn countToTen(comptime Counter: type) Returns(void, .{
    where(Counter, implements(Incrementable))
}) {
    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

The first parameter of `Returns` is the return type of the function, while the
second is an unreferenced `anytype` parameter allowing us to put type
verification here. The `where` syntax is just a wrapper around the regular
`assert` API for readability.

A more practical use-case for this style of syntax is if we want to take a
pointer to type that implements a given trait.
The following example shows a function that takes a parameter that is
a mutable pointer type (not `const`) that can coerce to a slice type
`[]T` such that the child type `T` implements the `Incrementable` trait.

```Zig
pub fn incrementAll(ctrs: anytype) Returns(void, .{
    where(@TypeOf(ctrs), coercesToMutSliceOf(implements(Incrementable)))
}) {
    for (ctrs) |*ctr| {
        ctr.increment();
    }
}
```

Multiple `where` statements can be evaluated.

```Zig
pub fn countToTen(comptime T: type, comptime U: type) Returns(void, .{
    where(T, implements(Incrementable)),
    where(U, implements(Incrementable))
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
```
