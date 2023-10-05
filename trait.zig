const std = @import("std");
const meta = std.meta;
const maxInt = std.math.maxInt;

pub const TraitFn = fn (type) type;

// build our own version of the TypeId enum for clean error messages
pub const TypeId = @Type(
    std.builtin.Type{
        .Enum = .{
            .tag_type = u64,
            .fields = @typeInfo(std.builtin.TypeId).Enum.fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,
        }, 
    }
);

pub fn any() Constraint { return .{}; }

pub fn is(comptime id: TypeId) Constraint {
    return any().is(id);
}

pub fn isOneOf(comptime ids: anytype) Constraint {
    return any().isOneOf(ids);
}

pub fn implements(comptime trait: TraitFn) Constraint {
    return any().implements(trait);
}

pub fn implementsAll(comptime traits: anytype) Constraint {
    return any().implementsAll(traits);
}

pub const Constraint = struct {
    const Self = @This();

    ids: []const TypeId = &[0]TypeId{},
    traits: []const *const TraitFn = &[0]*const TraitFn{},

    pub fn is(comptime self: Self, comptime id: TypeId) Self {
        return self.isOneOf(.{ id });
    }

    pub fn isOneOf(comptime self: Self, comptime ids: anytype) Self {
        const fields = @typeInfo(@TypeOf(ids)).Struct.fields;
        comptime {
            var idArray: [self.ids.len + fields.len]TypeId = undefined;
            inline for (fields, idArray[0..fields.len]) |fld, *id| {
                id.* = @field(ids, fld.name);
            }
            inline for (self.ids, idArray[fields.len..]) |i, *id| {
                id.* = i;
            }
            return .{ .ids = &idArray, .traits = self.traits };
        }
    }

    pub fn implements(comptime self: Self, comptime trait: TraitFn) Self {
        return self.implementsAll(.{ trait });
    }

    pub fn implementsAll(comptime self: Self, comptime traits: anytype) Self {
        const fields = @typeInfo(@TypeOf(traits)).Struct.fields;
        comptime {
            var traitArray: [self.traits.len + fields.len]*const TraitFn
                = undefined;
            inline for (fields, traitArray[0..fields.len]) |fld, *traitFn| {
                traitFn.* = &@field(traits, fld.name);
            }
            inline for (self.traits, traitArray[fields.len..]) |t, *traitFn| {
                traitFn.* = t;
            }
            return .{ .ids = self.ids, .traits = &traitArray };
        }
    }

    pub fn check(comptime self: Self, comptime Type: type) ?[]const u8 {
        var type_match = false;
        const type_id: TypeId = @enumFromInt(@intFromEnum(@typeInfo(Type)));
        inline for (self.ids) |expected_id| {
            if (type_id == expected_id) {
                type_match = true;
                break;
            }
        }
        if (!type_match) {
            if (self.ids.len == 1) {
                return std.fmt.comptimePrint(
                    "expected '{}' but found '{}'",
                    .{ self.ids[0], type_id }
                );
            } else if (self.ids.len > 1) {
                return std.fmt.comptimePrint(
                    "expected one of '{any}' but found '{}'",
                    .{ self.ids, type_id }
                );
            }
        }
        inline for (self.traits) |trait| {
            const Interface = trait.*(Type);
            const prelude = std.fmt.comptimePrint(
                "'{}' failed to implement '{}'",
                .{ Type, Interface }
            );
            inline for (@typeInfo(Interface).Struct.decls) |decl| {
                if (!@hasDecl(Type, decl.name)) {
                    return prelude ++ ": missing decl '" ++ decl.name ++ "'";
                }
            }
            inline for (@typeInfo(Interface).Struct.decls) |decl| {
                const FieldType = @field(Interface, decl.name);
                const fld = @field(Type, decl.name);

                if (@TypeOf(FieldType) == Constraint) {
                    if (FieldType.check(fld)) |reason| {
                        return std.fmt.comptimePrint(
                            "{s}: decl '{s}': {s}",
                            .{ prelude, decl.name, reason }
                        );
                    }
                } else if (@TypeOf(fld) != FieldType) {
                    return std.fmt.comptimePrint(
                        "{s}: decl '{s}': expected '{}' but found '{}'",
                        .{ prelude, decl.name, FieldType, @TypeOf(fld) }
                    );
                }
            }
        }
        return null;
    }

    pub fn assert(comptime self: Self, comptime Type: type) void {
        comptime {
            if (self.check(Type)) |reason| {
                @compileError(reason);
            }
        }
    }
};
