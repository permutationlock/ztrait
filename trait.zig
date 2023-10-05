const std = @import("std");
const meta = std.meta;
const maxInt = std.math.maxInt;

pub const TraitFn = fn (type) type;

const TagType = u64;
const TraitTypeFields = @typeInfo(std.builtin.TypeId).Enum.fields;

// build our own version of the TypeId enum for clean error messages
pub const TypeId = @Type(
    std.builtin.Type{
        .Enum = .{
            .tag_type = TagType,
            .fields = TraitTypeFields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,
        }, 
    }
);

pub fn associatedType() AssociatedType { return .{}; }

pub const AssociatedType = struct {
    const Self = @This();

    ids: []const TypeId = &[0]TypeId{},
    traits: []const *const TraitFn = &[0]*const TraitFn{},

    pub fn is(comptime self: Self, comptime id: TypeId) Self {
        comptime  {
            return self.isOneOf(.{ id });
        }
    }

    pub fn isOneOf(comptime self: Self, comptime ids: anytype) Self {
        const fields = @typeInfo(@TypeOf(ids)).Struct.fields;
        comptime {
            var idArray: [self.ids.len + fields.len]TypeId = undefined;
            inline for (idArray[0..], fields) |*id, fld| {
                id.* = @field(ids, fld.name);
            }
            inline for (idArray[fields.len..], self.ids) |*id, i| {
                id.* = i;
            }
            return .{ .ids = &idArray, .traits = self.traits };
        }
    }

    pub fn impl(comptime self: Self, comptime trait: TraitFn) Self {
        comptime {
            return self.implAll(.{ trait });
        }
    }

    pub fn implAll(comptime self: Self, comptime traits: anytype) Self {
        const fields = @typeInfo(@TypeOf(traits)).Struct.fields;
        comptime {
            var traitArray: [self.traits.len + fields.len]*const TraitFn
                = undefined;
            inline for (traitArray[0..], fields) |*traitFn, fld| {
                traitFn.* = &@field(traits, fld.name);
            }
            inline for (traitArray[fields.len..], self.traits) |*traitFn, t| {
                traitFn.* = t;
            }
            return .{ .ids = self.ids, .traits = &traitArray };
        }
    }
};

pub fn impl(comptime T: type, comptime Trait: TraitFn) void {
    const Interface = Trait(T);
    const prelude = std.fmt.comptimePrint(
        "'{}' fails to implement '{}'",
        .{ T, Interface }
    );

    // check decls exist before type checking to allow any definition order
    inline for (@typeInfo(Interface).Struct.decls) |decl| {
        if (!@hasDecl(T, decl.name)) {
            @compileError(prelude ++ ": missing decl '" ++ decl.name ++ "'");
        }
    }

    inline for (@typeInfo(Interface).Struct.decls) |decl| {
        const interface_fld = @field(Interface, decl.name);
        const type_fld = @field(T, decl.name);
        if (@TypeOf(interface_fld) == AssociatedType) {
            var type_match = false;
            const type_id: TypeId = @enumFromInt(
                @intFromEnum(
                    @typeInfo(type_fld)
                )
            );
            for (interface_fld.ids) |expected_id| {
                if (type_id == expected_id) {
                    type_match = true;
                    break;
                }
            }
            if (!type_match) {
                if (interface_fld.ids.len == 1) {
                    @compileError(std.fmt.comptimePrint(
                        "{s}: decl '{s}' expected '{}' but found '{}'",
                        .{
                            prelude,
                            decl.name,
                            interface_fld.ids[0],
                            type_id
                        }
                    ));
                } else if (interface_fld.ids.len > 1) {
                    @compileError(std.fmt.comptimePrint(
                        "{s}: decl '{s}' expected one of '{any}' but found '{}'",
                        .{
                            prelude,
                            decl.name,
                            interface_fld.ids,
                            type_id
                        }
                    ));
                }
            }
            for (interface_fld.traits) |traitFn| {
                impl(type_fld, traitFn.*);
            }
        } else if (interface_fld != @TypeOf(type_fld)) {
            @compileError(std.fmt.comptimePrint(
                "{s}: decl '{s}' expected '{}' but found '{}'",
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

pub fn implAll(comptime T: type, comptime traits: anytype) void {
    inline for (@typeInfo(@TypeOf(traits)).Struct.fields) |fld| {
        const traitFn = @field(traits, fld.name);
        impl(T, traitFn);
    }
}
