# Patterns for Zig generics

I love type systems and generic programming, almost certainly to the
detriment of my productivity. I also love the Zig programming
language, which has an interesting approach to generics.

I tend to agree with the opinion that generics should generally be
avoided. Nevertheless, I have spent a decent chunk of type exploring
Zig's generics and I made a stab at implementing
[my own version of Rust-style traits][1]. The rest of this article will
assume that you have at least skimmed the readme of that project.

## An example situation

Suppose that we are a librar writer who has created a `Server` struct
to manage a collection of TCP connections. We would like `Server`
to exposes a `poll` function that will poll for events on the
server's internal collection of connnected sockets.

There
are three possible events that we want to handle: client connection,
message received, and client disconnection.

Below I'll go over a few different ways that we could write a
`Server.poll` function that accepts a generic `handler` parameter
to handle reported events.

**Note:** There are many non-generic ways to tackle this, e.g.
by using an interface struct that wraps a pointer
to a specific handler implementation. In this
article I'll just be focusing on
compile-time generics, and won't be discussing whether they
are actually best solution for this particular sceneario.

## Just use `anytype`

Zig allows generic functions to take `anytype` parameters, generating
a new function at compile-time for each different type of parameter
passed. Compile time duck-typing is used to verify that the passed
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

## Use a context pointer and take functions as parameters

If we want to be clear about what the caller should provide, we could
instead take each of the functions that will be called on `handler` as
separate parameters.

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

Unfortunately, this does make calling `Server.poll` quite a bit more verbose.

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

## Specific type checking with traits

Lets go back to the `anytype` example, but add some immediate type
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

Then we can add a trait verification line at the top of `Server.poll`.

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

To someone familiar with the trait convention, this immediately
declares the type requirements for the `handler` parameter, and
provides nice error messages if an insufficient parameter type is
passed.

**Note:** My trait library is obviously only one possible way to do
explicit type checking. You could do it from basics with `if`
and `switch` statements and the `@typeInfo` builtin, or define your
own conventions and helper functions.

### Bonus: trait interfaces

Trait verification requires the library maker to manually make sure
that they keep the trait definitions up to date with how types are actually
used. If we really need to adopt a convention that forces traits to match
with how the type is used, we can use `trait.Interface`.

The `trait.Interface` comptime function takes a type `T` and a trait (or tuple
of traits) and returns a struct instance containing one
field for `T`'s implementation of each declaration of the trait.

As long as the parameter is only accessed via the declarations of this
interface struct, we have a guarantee that the specified trait(s)
define "necessary and sufficient" conditions for parameter types.

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

[1]: https://github.com/permutationlock/zig_type_traits

