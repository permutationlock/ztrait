# Zig Type Traits

An attempt at implementing something along the lines of Rust type traits in Zig.
Using this library you can define traits and compile-time verify that types
implement them.

The primary goal of the library is to explore
a formal way to document requirements for generic type.

## Links

Below are some related projects and Zig proposal threads that I read while
implementing the library.  I don't have any strong position on proposed
changes to the Zig language regarding generics, and I respect the Zig team's
reasoning for keeping the type system simple.

 - [Zig Compile-Time-Contracts](https://github.com/yrashk/zig-ctc)
 - Zig issues:
   [#1268](https://github.com/ziglang/zig/issues/1268),
   [#1669](https://github.com/ziglang/zig/issues/1669),
   [#6615](https://github.com/ziglang/zig/issues/6615),
   [#17198](https://github.com/ziglang/zig/issues/17198)

I wrote an article that comparing a few generic
patterns used in Zig by creating a small "real world" example of how
this library might be used.

 - [Patterns for Zig generics: a generic server event handler](https://musing.permutationlock.com/posts/blog-patterns_for_zig_generics.html)

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
```

## Combining traits

Multiple traits can be type checked with a single call.

```Zig
pub fn HasDimensions(comptime _: type) type {
    return struct {
        pub const width = comptime_int;
        pub const height = comptime_int;
    };
}

pub fn computeAreaAndCount(comptime T: type) void {
    comptime where(T, trait.implements(.{ Incrementable, HasDimensions }));

    var counter = T.init();
    while (counter.read() < T.width * T.height) {
        counter.increment();
    }
}
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

## Validating pointer and slice types passed as `anytype`

We can constrain `anytype` parameters to be pointer types that dereference
to types that implement traits.

```Zig
pub fn countToTen(counter: anytype) void {
    comptime where(@TypeOf(counter), hasTypeInfo(.{ .Pointer = .{ .size = .One } }));
    comptime where(Child(@TypeOf(counter)), implements(Incrementable));

    while (counter.read() < 10) {
        counter.increment();
    }
}
```

The `Child` helper funciton used above is simply `std.meta.Child`. In the case
that `T` is a pointer type, `Child(T)` grabs the type that the pointer
dereferences to.

To make this style of type checking less verbose, a helper function
`PointerChild` is provided that verifies a type is a single item
pointer and extracts its child type in one call.

```Zig
pub fn countToTen(counter: anytype) void {
    comptime where(PointerChild(@TypeOf(counter)), implements(Incrementable));

    while (counter.read() < 10) {
        counter.increment();
    }
}
```

Slice types are slightly more complicated because we usually want to
allow for `*[_]T` types as well as `[]T`. In this case we have to use the
`SliceChild` helper function
because `Child(*[_]U)` is `[n]U` not `U`.
The `SliceChild` function verifies that a type can coerce to a slice
and extracts the child type.

```Zig
pub fn incrementAll(list: anytype) void {
    comptime where(SliceChild(@TypeOf(list)), implements(Incrementable));

    for (list) |*counter| {
        counter.increment();
    }
}
```

The above function works directly on types that coerce to a slice,
but if required you can actually coerce the type to a slice as shown below.

```Zig
pub fn incrementAll(list: anytype) void {
    comptime where(SliceChild(@TypeOf(list)), implements(Incrementable));
    
    const slice: []SliceChild(@TypeOf(list)) = list;
    for (slice) |*counter| {
        counter.increment();
    }
}
```
## Extending the library to support other use cases

Users can define their own helper functions as needed by wrapping
the trait module.

```Zig
// mytrait.zig

const trait = @import("trait");
const where = trait.where;
const hasTypeInfo = trait.hasTypeInfo;

// expose all declaraions from the standard trait module
pub usingnamespace trait;

// define your own convenience functions
pub fn BackingInteger(comptime Type: type) type {
    comptime where(Type, hasTypeInfo(.{ .Struct = .{ .layout = .Packed } }));

    return @typeInfo(Type).Struct.backing_integer.?;
}
```

## Interfaces: restricting access to declarations 

Using `where` and `implements` we can require that types have
declaration satisfying trait requirements. We cannot, however,
prevent code from using declarations beyond the scope of the checked
traits. Thus it is on the developer to keep traits up to date with how
types are actually used.

The `Interface` function provides a method to formally restrict
traits to be both necessary and sufficient requirements for types.
Calling `Interface(Type, Trait)` will construct a comptime instance of a
generated struct type that contains a field for each declaration of
`Type` the type that has a matching declaration in `Trait`. The
fields of this interface struct are then used in place of the
declarations of `Type`.

```Zig
pub fn countToTen(comptime C: type) void {
    const Counter = Interface(C, Incrementable);

    var counter = Counter.init();
    while (Counter.read(&counter) < 10) {
        Counter.increment(&counter);
    }
}
```

Interface construction performs the same type checking as `where`.

## Returns syntax: traits in function definitions

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
or `Interface` functionality
because the compile errors occur while a function signature is being
generated. This can result in the line number of the original call
not be reported unless building with `-freference-trace` (and even then
the call site may still be obsucred in some degenerate cases).

