const std = @import("std");
const meta = std.meta;

pub const TraitFn = fn (type) type;

pub const AssociatedType = std.builtin.TypeId;

pub fn impl(comptime Type: type, comptime Trait: TraitFn) void {
    const Interface = Trait(Type);
    const prelude = std.fmt.comptimePrint(
        "'{}' fails to implement '{}'",
        .{ Type, Interface }
    );

    // check decls exist before type checking to allow any definition order
    inline for (@typeInfo(Interface).Struct.decls) |decl| {
        if (!@hasDecl(Type, decl.name)) {
            @compileError(prelude ++ ": missing decl '" ++ decl.name ++ "'");
        }
    }

    inline for (@typeInfo(Interface).Struct.decls) |decl| {
        const interface_fld = @field(Interface, decl.name);
        const type_fld = @field(Type, decl.name);
        if (@TypeOf(interface_fld) == std.builtin.TypeId) {
            const type_id: std.builtin.TypeId = @typeInfo(type_fld);
            if (type_id != interface_fld) {
                @compileError(std.fmt.comptimePrint(
                    "{s}: decl '{s}' expected TypeId '{}' but found '{}'",
                    .{
                        prelude,
                        decl.name,
                        interface_fld,
                        type_id
                    }
                ));
            }
        } else if (interface_fld != @TypeOf(type_fld)) {
            @compileError(std.fmt.comptimePrint(
                "{s}: decl '{s}' expected type '{}' but found '{}'",
                .{
                    prelude,
                    decl.name,
                    interface_fld,
                    @TypeOf(type_fld)
                }
            ));
        }
    }
}

pub fn implAll(comptime Type: type, comptime traits: anytype) void {
    inline for (@typeInfo(@TypeOf(traits)).Struct.fields) |fld| {
        const traitFn = @field(traits, fld.name);
        impl(Type, traitFn);
    }
}
