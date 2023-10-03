const std = @import("std");
const meta = std.meta;

pub const TraitFn = fn (type) type;

const TraitTypeTag = @typeInfo(std.builtin.TypeId).Enum.tag_type;
const TraitTypeFields = @typeInfo(std.builtin.TypeId).Enum.fields;
pub const TraitType = @Type(
    std.builtin.Type{
        .Enum = .{
            .tag_type = TraitTypeTag,
            .fields = TraitTypeFields ++ [1]std.builtin.Type.EnumField{
                .{
                    .name = "Any",
                    .value = std.math.maxInt(TraitTypeTag)
                },
            },
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,
        }, 
    }
);

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
