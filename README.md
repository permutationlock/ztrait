# Zig Type Traits

An attempt at implementing Rust style type traits in Zig. Using this library
you can define traits and compile-time verify that types satisfy them.

**Note:** Nothing is done to require that every declaration referenced on a type
must belong to a trait that was implemented. In other words: duck-typing still
works as usual, but trait verification runs first. The library mainly
serves as a convention that provides nice error messages and type documentation.

## Related links

I read several related projects and discussion threads while implementing
the library. Links to the things that I found most memorable and/or useful
are provided below.

 - [Zig Compile-Time-Contracts](https://github.com/yrashk/zig-ctc)
 - Zig proposals: [#1268](https://github.com/ziglang/zig/issues/1268), [#1669](https://github.com/ziglang/zig/issues/1669), [#6615](https://github.com/ziglang/zig/issues/6615), [#17198](https://github.com/ziglang/zig/issues/17198)

I don't have any strong position on the above proposals. I respect the Zig team's
reasoning for keeping the type system simple.

## Basic use

A trait is simply a comptime function taking a type and returning a struct type.
Each declaration of the returned struct defines a required declaration that the
type must have if it implements the trait. 

Below is a trait that requires implementing types to define an integer
sub-type `Count`, define an `init` funciton, and define member functions
`increment` and `read`.

```Zig
pub fn Incrementable(comptime Type: type) type {
    return struct {
        // below is the same as `pub const Count = type` except that during
        // trait verification it requires that '@typeInfo(Type.Count) == .Int'
        pub const Count = hasTypeId(.Int);

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
need to add a comptime verification line at the start of your function.

```Zig
pub fn countToTen(comptime Counter: type) void {
    comptime where(Counter, implements(Incrementable));
    var counter = Counter.init();
    while (counter.read() < 10) {
        counter.increment();
    }
}
```

**Note:** If we don't specify that trait verification is comptime then
verification might be evaluated later during compilation. This results in
regular duck-typing errors rather than trait implementation errors.

If we define a type that fails to implement the `Incrementable` trait and pass
it to `countToTen`, then the call to `where` will produce a compile error.

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
trait.zig:12:13: error: trait 'count.Incrementable(count.MyCounterMissingDecl)' failed: missing decl 'increment'
            @compileError(reason);
            ^~~~~~~~~~~~~~~~~~~~~
examples/count.zig:182:19: note: called from here
    comptime where(Counter, implements(Incrementable));
             ~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
trait.zig:12:13: error: trait 'count.Incrementable(count.MyCounterInvalidType)' failed: decl 'Count': expected 'trait.TypeId.Int', found 'trait.TypeId.Struct'
            @compileError(reason);
            ^~~~~~~~~~~~~~~~~~~~~
examples/count.zig:182:19: note: called from here
    comptime where(Counter, implements(Incrementable));
             ~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
trait.zig:12:13: error: trait 'count.Incrementable(count.MyCounterWrongFn)' failed: decl 'increment': expected 'fn (*count.MyCounterWrongFn) void', found 'fn (*count.MyCounterWrongFn, u32) void'
            @compileError(reason);
            ^~~~~~~~~~~~~~~~~~~~~
examples/count.zig:182:19: note: called from here
    comptime where(Counter, implements(Incrementable));
             ~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## Constraining subtypes

Traits can require each implementing type to declare subtypes
that are constrained by further traits.

```Zig
pub fn HasIncrementable(comptime _: type) type {
    return struct {
        pub const Counter = implements(Incrementable);
    };
}

```

```Zig
pub fn useHolderToCountToTen(comptime T: type) void {
    comptime where(T, implements(HasIncrementable));
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
trait.zig:12:13: error: trait 'count.HasIncrementable(count.InvalidCounterHolder)' failed: decl 'Counter': trait 'count.Incrementable(count.MyCounterMissingDecl)' failed: missing decl 'increment'
            @compileError(reason);
            ^~~~~~~~~~~~~~~~~~~~~
examples/count.zig:203:19: note: called from here
    comptime where(T, implements(HasIncrementable));
             ~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## Declaring that a type implements a trait

Alongside enforcing trait implementation in generic functions, types themselves
can delare that they implement a given trait.

```Zig
const MyCounter = struct {
    comptime { where(@This(), implements(Incrementable)); }

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

## Pointers and slices with `anytype`

With the ability to verify `@typeInfo` properties as well, we can constrain
`anytype` parameters to be pointers to types implementing traits. The
following function takes a mutable slice `[]T` where `T` implements
the `Incrementable` interface from above.

```Zig
pub fn incrementAll(list: anytype) usize {
    comptime where(@TypeOf(list), hasTypeInfo(.{ .Pointer = .{ .size = .Slice, .is_const = false } }).hasChild(implements(Incrementable)));

    for (list) |*counter| {
        counter.increment();
    }
}
```

The example above is quite verbose, and also couldn't accept parameters like `*[_]T`
that coerce to `[]T`. Luckily it is quite simple to create helper functions
to make things more functional and readable.
The `coercesToMutSliceOf` helper verifies that a type
can coerce to a slice type `[]T` where `T` is further constrained.

```Zig
pub fn incrementAll(list: anytype) usize {
    comptime where(@TypeOf(list), coercesToMutSliceOf(implements(Incrementable)));

    for (list) |*counter| {
        counter.increment();
    }
}
```

Users can define their own helper functions as needed by expanding
the trait module

```Zig
// mytrait.zig

const trait = @import("trait");
pub usingnamespace trait;

pub fn isU32PackedStruct() trait.Constraint {
    return trait.hasTypeInfo(.{
        .Struct = .{
            .layout = .Packed,
            .backing_integer = u32,
        }
    });
}
```

## Traits in function definitions: 'Returns' syntax

Sometimes it can be useful to have type signatures directly in function
definitions. Zig currently does not support this, but there is a hacky
workaround using the fact that Zig can evaluate a `comptime` function in
the return value.

```Zig
pub fn incrementAll(list: anytype) Returns(void, .{
    where(@TypeOf(list), coercesToMutSliceOf(implements(Incrementable)))
}) {
    for (list) |*counter| {
        counter.increment();
    }
}
```

The first parameter of `Returns` is the actual return type of the function,
while the second is an unreferenced `anytype` parameter.

```Zig
pub fn Returns(comptime ReturnType: type, comptime _: anytype) type {
    return ReturnType;
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

**Note:** error messages can be less helpful when using `Returns`
because the compile error happens before the function is even
generated. Therefore the call site generating the error is not
reported when building with `-freference-trace`.
