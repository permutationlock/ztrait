# Zig Type Traits

An attempt at implementing something along the lines of Rust type traits in Zig.
Using this library you can define traits and compile-time verify that types
implement them.

You can only "implement" traits by adding declarations to a type's definition,
so it might be more accurate to call them type classes or interfaces.

**Note:** Duck-typing still works as usual, but trait verification runs first.
The main value the library hopes to provide is nice error messages and
a formal way to document requirements for generic type.

## Related links

Below are some related projects and Zig proposal threads that I read while
implementing the library.

 - [Zig Compile-Time-Contracts](https://github.com/yrashk/zig-ctc)
 - Zig issues:
   [#1268](https://github.com/ziglang/zig/issues/1268),
   [#1669](https://github.com/ziglang/zig/issues/1669),
   [#6615](https://github.com/ziglang/zig/issues/6615),
   [#17198](https://github.com/ziglang/zig/issues/17198)

I don't have any strong position on proposed changes to the Zig language
regarding generics, and I respect the Zig team's reasoning for keeping the
type system simple.

## Basic use

A trait is simply a comptime function taking a type and returning a struct type
containing only declarations.
Each declaration of the returned struct is a required declaration that a
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

Traits can require typese to declare subtypes
that are constrained traits.

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

## Traits in function definitions: 'Returns' syntax

Sometimes it can be useful to have type signatures directly in function
definitions. Zig currently does not support this, but there is a hacky
workaround using the fact that Zig can evaluate a `comptime` function in
the return type location.

```Zig
pub fn sumIntSlice(comptime I: type, list: []const  I) Returns(I, .{
    where(I, hasTypeId(.Int)),
}) {
    var count: I = 0;
    for (list) |elem| {
        count += elem;
    }
    return count;
}
```

The first parameter of `Returns` is the actual return type of the function,
while the second is an unreferenced `anytype` parameter.

```Zig
pub fn Returns(comptime ReturnType: type, comptime _: anytype) type {
    return ReturnType;
}
```

**Warning:** Error messages can be less helpful when using `Returns`
because the compile error occurs before the function is even
generated. Therefore the call line number of the call site generating
the trait error will not be reported when building with `-freference-trace`.

## Pointer and slice parameters using `anytype`

We can constrain `anytype` parameters to be pointer types that dereference
to types implementing traits.

```Zig
pub fn countToTen(counter: anytype) void {
    comptime where(@TypeOf(counter), hasTypeInfo(.{ .Pointer = .{ .size = .One } }));
    comptime where(Child(@TypeOf(counter)), implements(Incrementable));

    while (counter.read() < 10) {
        counter.increment();
    }
}
```

The `trait.Child` helper funciton is simply `std.meta.Child`. In the case that
`T` is a pointer type, `Child(T)` grabs the type that the pointer dereferences
to.

Slice types are slightly more complicated because we usually want to
allow for type coercion, and this doesn't happen with anytype. A workaround
is to use the `SliceChild` helper function to grab the child type of
any type that can coerce to a slice, and then call a helper function
to perform the coercion.

```Zig
pub fn incrementAll(list: anytype) void {
    incrementAllInt(SliceChild(@TypeOf(list)), list);
}

fn incrementAllInt(comptime Counter: type, list: []Counter) void {
    comptime where(Counter, implements(Incrementable));

    for (list) |*counter| {
        counter.increment();
    }
}
```

**Note:** We must use the custom `trait.SliceChild` helper function
instead of `std.meta.Child` because it might be that `T = *[n]U` in
which case `Child(T) = [n]U` and not `U`.

Users can define their own helper functions as needed by expanding
the trait module

```Zig
// mytrait.zig

const trait = @import("trait");
const where = trait.where;
const hasTypeInfo = trait.hasTypeInfo;

pub usingnamespace trait;

pub fn BackingInteger(comptime Type: type) type {
    comptime where(Type, hasTypeInfo(.{ .Struct = .{ .layout = .Packed } }));

    return @typeInfo(Type).Struct.backing_integer.?;
}
```

