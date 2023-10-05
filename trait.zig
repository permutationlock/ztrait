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

    pub fn check(comptime self: Self, comptime Type: type) void {
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
                @compileError(std.fmt.comptimePrint(
                    "expected '{}' but found '{}'",
                    .{ self.ids[0], type_id }
                ));
            } else if (self.ids.len > 1) {
                @compileError(std.fmt.comptimePrint(
                    "expected one of '{any}' but found '{}'",
                    .{ self.ids, type_id }
                ));
            }
        }
        inline for (self.traits) |trait| {
            const Interface = trait.*(Type);
            inline for (@typeInfo(Interface).Struct.decls) |decl| {
                if (!@hasDecl(Type, decl.name)) {
                    @compileError("missing decl '" ++ decl.name ++ "'");
                }
            }
            inline for (@typeInfo(Interface).Struct.decls) |decl| {
                const FieldType = @field(Interface, decl.name);
                const fld = @field(Type, decl.name);

                if (FieldType == AssociatedType) {
                    FieldType.check(@TypeOf(fld));
                } else if (@TypeOf(fld) != FieldType) {
                    @compileError(std.fmt.comptimePrint(
                        "expected '{}' but found '{}'",
                        .{ FieldType, @TypeOf(fld) }
                    ));
                }
            }
        }
    }
};
