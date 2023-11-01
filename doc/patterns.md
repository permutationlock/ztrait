# Patterns for Zig generics

I like type systems and generic programming, almost certainly to the
detriment to my own productivity. I also love the Zig programming
language, which has an interesting approach to generics.

I tend to agree with the opinion that generics should generally be
avoided, but nonetheless I spent a decent chunk of type exploring
Zig's generics and made a stab at implementing
[my own version of Rust-style traits][1]. The rest of the article will
assume that you have at least skimmed the readme.

## The example situation

Suppose that we have a `Server` struct that exposes a `poll` function that
will poll for events on an internal collection sockets. There
are three possible events that we want to handle: client connection,
message received, and client disconnection.

Below I'll go over a few different ways that we could write a
`Server.poll` function which accepts a generic `handler` type to
handle reported events.

**Note:** There are many non-generic ways to tackle this, e.g.
by using an interface struct that wraps a pointer
to a specific handler implementation. In this
article I'll be focusing on
compile-time generics, and won't be discussing whether they
are actually best solution for this particular sceneario.

## Just use `anytype`

Zig allows generic functions to take `anytype` parameters, generating
a new function at compile-time for each different type of parameter
passed. Compile time duck-typing is used to verify that the passed
parameters have the required declarations and fields.

A version of a `poll` function declaration for our server struct
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
that simply logs events.

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

Obviously not a big deal in this simple case, but would be nice to have
the type requirements available right near the function signature.

## Use a context pointer and function parameters

If we want to be clear about what the caller should provide, we could
instead take the functions that will be called on `handler` as
separate parameters.

```Zig
    // ...
    pub fn poll(
        self: *Self,
        handler: anytype, 
        onOpen: fn (@TypeOf(handler), ConnectionHandle, Key) void,
        onMessage: fn (@TypeOf(handler), ConnectionHandle, Message) void,
        onClose: fn (@TypeOf(handler), ConnectionHandle) void
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

## Comptime type checking

Lets go back to the `anytype` example, but add some immediate type
checking using traits. Let's define a `Handler` trait as follows.

```Zig
pub fn Handler(comptime Type: type) type {
    return struct {
        pub const onOpen = fn (*Type, Handle) void;
        pub const onMessage = fn (*Type, Handle, []const u8) void;
        pub const onClose = fn (*Type, Handle) void;
    };
}
```

Then we can add a trait verification line to the top of `Server.poll`.

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

### Bonus: trait interfaces

Trait verification requires the library maker to manually make sure
that they keep the trait definitions up to date with how types are actually
used. If we really need to adopt a convention that forces traits to match
with how the type is used, we can use `trait.Interface`.

The `trait.Interface` comptime function takes a type `T` and a trait (or tuple
of traits) and returns a struct instance containing one
field for `T`'s implementation of each declaration of the trait.

So long as the parameter is only accessed via the declarations of this
interface struct, we now have a guarantee that the specified trait(s)
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

