# Patterns for Zig generics

This article assumes that you have at least skimmed the readme of
my [Zig type trait library][1].

## An example situation

Suppose that we are writing a networking library and have created a
`Server` struct
that will accept and manage TCP connections. We would like `Server`
to exposes a `poll` function that will poll for events on the
server's internal collection of connnected sockets.

There
are three possible events that we want to handle: client connection,
message received, and client disconnection.

Below I'll go over a few different ways that we could write a
`Server.poll` function that accepts a generic `handler` parameter
to handle reported events.

**Note:** There are many non-generic ways to tackle this, e.g.
by using an interface struct that wraps a type-erased pointer
to a specific handler implementation. In this
article I'll just be focusing on
compile-time generics.

## Just use `anytype`

Zig allows generic functions to take `anytype` parameters, generating
a new concrete function at compile-time for each different parameter
type used. Compile time [duck-typing][2] is used to verify that the passed
parameters have the required declarations and fields.

A `poll` function for our `Server` struct
using `anytype` is provided below.

```Zig
pub const Server = struct {
    // ... 
    const Event = union(enum) {
        open: Handle,
        event: struct { handle: Handle, bytes: []const u8 },
        close: Handle,
    };
    
    fn pollForEvent(self: *Self) Event {
        // ...
    }

    pub fn poll(self: *Self, handler: anytype) void {
        while (self.pollForEvent()) |event| {
            switch (event) {
                .open => |handle| handler.onOpen(handle),
                .msg => |msg| handler.onMessage(msg.handle, msg.bytes),
                .close => |handle| handler.onClose(handle),
            }
        }
    }
    // ...
}
```

Someone using our library could then write their own simple server
that logs the reported events.

```Zig
const std = @import("std");
const log = std.log.scoped(.log_server);

const my_server_lib = @import("my_server_lib")
const Server = my_server_lib.Server;
const Handle = Server.Handler;

pub const LogHandler = struct {
    pub fn onOpen(_: *Self, handle: Handle) void {
        log.info("connection {} opened", .{ handle });
    }

    pub fn handleClose(_: *Self, handle: Handle) void {
        log.info("connection {} closed", .{ handle });
    }

    pub fn handleMessage(self: *Self, handle: Handle, msg: []const u8) void {
        log.info("connection {} sent: {s}", .{ handle, msg });
    }
};

pub fn main() void {
    var server = Server{};
    var handler = LogHandler{};
    server.listen(port);
    while (true) {
        server.poll(&handler);
    }
}
```

This works, but for the library user to figure out what they needed to
pass for the `handler` parameter of `poll` they had to track down the
return type of `Server.pollForEvent` and the definition of
`Server.Event`.

Obviously this is not a big deal in our case, but it would be nice to have
the type requirements available right near the function signature.

## Take required functions as explicit parameters

If we want to be clear about what the caller should provide, we could
instead take each of the functions that will be called on `handler` as
a separate parameter.

```Zig
    // ...
    pub fn poll(
        self: *Self,
        handler: anytype, 
        onOpen: fn (@TypeOf(handler), Handle) void,
        onMessage: fn (@TypeOf(handler), Handle, Message) void,
        onClose: fn (@TypeOf(handler), Handle) void
    ) void {
        while (self.pollForEvent()) |event| {
            switch (event) {
                .open => |handle| onOpen(handler, handle),
                .msg => |msg| onMessage(handler, msg.handle, msg.bytes),
                .close => |handle| onClose(handler, handle),
            }
        }
    }
    // ...
```

Unfortunately, while this makes requirements explicit, it also makes calling
`Server.poll` quite a bit more verbose.

```Zig
var server = Server{};
var handler = MyHandler{};
server.listen(port);
while (true) {
    server.poll(
        &handler,
        MyHandler.onOpen,
        MyHandler.onMessage,
        MyHandler.onClose
    );
}
```

## Explicit type checking with traits

Lets go back to the raw `anytype` method, but this time add some explicit type
checking using traits. We can define a `Handler` trait as follows.

```Zig
pub fn Handler(comptime Type: type) type {
    return struct {
        pub const onOpen = fn (*Type, Handle) void;
        pub const onMessage = fn (*Type, Handle, []const u8) void;
        pub const onClose = fn (*Type, Handle) void;
    };
}
```

Then we add a trait verification line at the top of `Server.poll`.

```Zig
    // ...
    pub fn poll(self: *Self, handler: anytype) void {
        comptime where(PointerChild(@TypeOf(handler)), implements(Handler));

        while (self.pollForEvent()) |event| {
            while (self.pollForEvent()) |event| {
                switch (event) {
                    .open => |handle| handler.onOpen(handle),
                    .msg => |msg| handler.onMessage(msg.handle, msg.bytes),
                    .close => |handle| handler.onClose(handle),
                }
            }
        }
    }
    // ...
```

To someone familiar with the trait convention, it is now immediately
clear what the type requirements are for the `handler` parameter.
Trait verification also
provides nice compiler error messages if a `handler` of
an invalid type is passed to `poll`.

**Note:** My trait library is obviously only one possible way to do
explicit type checking. You could do it from basics with `if`
and `switch` statements and the `@typeInfo` builtin, or define your
own conventions and helper functions.

### Bonus: trait interfaces

Trait verification requires a library writer to manually make sure
that they keep their trait definitions up to date with how types are actually
used. If we really need to adopt a convention that forces traits to match
with how types that implement them are used, we can use `trait.Interface`.

The `trait.Interface` comptime function takes a type `T` and a trait (or tuple
of traits) and returns a struct instance containing one
field for `T`'s implementation of each declaration of the trait.

A version of `Server.poll` using `trait.Interface` is provided below.

```Zig
    // ...
    pub fn poll(self: *Self, handler: anytype) void {
        const HandlerIfc = Interface(PointerChild(@TypeOf(handler)), Handler);

        while (self.pollForEvent()) |event| {
            while (self.pollForEvent()) |event| {
                switch (event) {
                    .open => |handle| HanlderIfc.onOpen(handler, handle),
                    .msg => |msg| HandlerIfc.onMessage(handler, msg.handle, msg.bytes),
                    .close => |handle| HandlerIfc.onClose(handler, handle),
                }
            }
        }
    }
    // ...
```

As long as the `handler` parameter is only accessed via the declarations of
the `HandlerIfc` interface struct, we have a guarantee that the `Handler` trait
defines "necessary and sufficient" conditions for the type of `handler`.

[1]: https://github.com/permutationlock/zig_type_traits
[2]: https://ziglang.org/documentation/master/#Introducing-the-Compile-Time-Concept
