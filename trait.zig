const std = @import("std");
const meta = std.meta;

pub const TraitFn = fn (type) type;

pub fn impl(comptime Type: type, comptime Trait: TraitFn) void {
    const Interface = Trait(Type);
    const prelude = std.fmt.comptimePrint(
        "'{}' fails to implement '{}'",
        .{ Type, Interface }
    );
    inline for (@typeInfo(Interface).Struct.decls) |decl| {
        if (!@hasDecl(Type, decl.name)) {
            @compileError(std.fmt.comptimePrint(
                "{s}: missing decl '{s}'",
                .{ prelude, decl.name }
            ));
        }
        const interface_fld = @field(Interface, decl.name);
        const type_fld = @field(Type, decl.name);
        if (interface_fld != @TypeOf(type_fld)) {
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
