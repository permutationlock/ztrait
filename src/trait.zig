const std = @import("std");

// ------------------
// Core Functionality
// ------------------

pub const TraitFn = *const fn (type) type;

pub fn where(comptime T: anytype, comptime constraint: Constraint) void {
    if (constraint.check(T)) |reason| {
        @compileError(reason);
    }
}

pub fn isAny() Constraint {
    return .{};
}

pub fn hasTypeId(comptime id: TypeId) Constraint {
    return isAny().hasTypeId(id);
}

pub fn hasTypeInfo(comptime info: TypeInfo) Constraint {
    return isAny().hasTypeInfo(info);
}

pub fn implements(comptime trait: TraitFn) Constraint {
    return isAny().implements(trait);
}

pub const Constraint = struct {
    const Self = @This();

    and_constraint: ?* const Constraint = null,
    or_constraint: ?*const Constraint = null,
    requirement: ?union(enum) {
        info: TypeInfo,
        trait: TraitFn,
    } = null,

    pub fn hasTypeId(comptime self: Self, comptime id: TypeId) Self {
        return self.hasTypeInfo(
            @unionInit(TypeInfo, getTypeFieldName(id), .{})
        );
    }

    pub fn hasTypeInfo(comptime self: Self, comptime info: TypeInfo) Self {
        var constraint = self;
        constraint.requirement = .{ .info = info };
        return constraint;
    }

    pub fn implements(comptime self: Self, comptime trait: TraitFn) Self {
        comptime {
            var constraint = self;
            constraint.requirement = .{ .trait = trait };
            return constraint;
        }
    }

    pub fn andAlso(comptime self: Self, comptime sub_constraint: Self) Self {
        comptime {
            var constraint = self;
            constraint.and_constraint = &sub_constraint;
            return constraint;
        }
    }

    pub fn orElse(comptime self: Self, comptime sub_constraint: Self) Self {
        comptime {
            var constraint = self;
            constraint.or_constraint = &sub_constraint;
            return constraint;
        }
    }

    pub fn check(comptime self: Self, comptime Type: type) ?[]const u8 {
        if (self.or_constraint) |constraint| {
            if (constraint.check(Type) == null) {
                return null;
            }
        }
        if (self.and_constraint) |constraint| {
            if (constraint.check(Type)) |reason| {
                return reason;
            }
        }

        if (self.requirement) |requirement| {
            switch (requirement) {
                .info => |info| return checkInfo(Type, info),
                .trait => |trait| return checkTrait(Type, trait)
            }
        }

        return null;
    }
};

fn checkInfo(comptime Type: type, comptime exp_info: TypeInfo) ?[]const u8 {
    const type_info = @typeInfo(Type);
    const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));
    const type_name = getTypeFieldName(type_id);
    const spec_info = @field(type_info, type_name);

    const exp_id: TypeId = exp_info;
    if (exp_id != type_id) {
        return std.fmt.comptimePrint(
            "expected '{}', found '{}'",
            .{ exp_id, type_id }
        );
    }
    const exp = @field(exp_info, type_name);
    const exp_fields = @typeInfo(@TypeOf(exp)).Struct.fields;
    inline for (exp_fields) |fld_info| {
        const maybe_exp_fld = @field(exp, fld_info.name);
        if (maybe_exp_fld) |exp_fld| {
            const act_fld = @field(spec_info, fld_info.name);
            if (exp_fld != act_fld) {
                return std.fmt.comptimePrint(
                    "bad value for '@typeInfo({}).{s}.{s}': "
                        ++ "expected '{}', found '{}'",
                    .{ Type, type_name, fld_info.name, exp_fld, act_fld }
                );
            }
        }
    }

    return null;
}

fn checkTrait(comptime Type: type, comptime trait: TraitFn) ?[]const u8 {
    const type_info = @typeInfo(Type);
    const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));
    const type_name = getTypeFieldName(type_id);
    const spec_info = @field(type_info, type_name);

    if (!@hasField(@TypeOf(spec_info), "decls")) {
        return std.fmt.comptimePrint(
            "type '{}' cannot implement traits: "
                ++ "'@typeInfo({}).{s}' missing field 'decls'",
            .{ Type, Type, type_name });
    }

    const TraitStruct = trait.*(Type);
    const prelude = std.fmt.comptimePrint(
        "trait '{}' failed",
        .{TraitStruct}
    );
    inline for (@typeInfo(TraitStruct).Struct.decls) |decl| {
        if (!@hasDecl(Type, decl.name)) {
            return prelude ++ ": missing decl '" ++ decl.name ++ "'";
        }
    }
    inline for (@typeInfo(TraitStruct).Struct.decls) |decl| {
        const FieldType = @field(TraitStruct, decl.name);
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
                "{s}: decl '{s}': expected '{}', found '{}'",
                .{ prelude, decl.name, FieldType, @TypeOf(fld) }
            );
        }
    }

    return null;
}


// ---------------------
// Convenience functions
// ---------------------
//   All helper functions are defined in the top-level namespace (rather than
//   within the `Contract` type) to allow users to define their own as needed.
//
//   To create custom helper functions:
//     - create a new file, e.g. "mytrait.zig"
//     - add the following line: `pub usingnamespace @import("trait");`
//     - define additional helpers as you please
//     - use `@import("mytrait.zig")` instead of `@import("trait")`

pub fn isConstPointer() Constraint {
    return hasTypeInfo(.{ .Pointer = .{ .size = .One } });
}

pub fn isMutPointer() Constraint {
    return hasTypeInfo(.{ .Pointer = .{ .size = .One, .is_const = false } });
}

pub fn isTuple() Constraint {
    return hasTypeInfo(.{ .Struct = .{ .is_tuple = true } });
}

pub fn isContainer() Constraint {
    return isContainerInternal(null);
}

pub fn isContainerExtern() Constraint {
    return isContainerInternal(.Extern);
}

pub fn isContainerPacked() Constraint {
    return isContainerInternal(.Packed);
}

fn isContainerInternal(
    comptime layout: ?std.builtin.Type.ContainerLayout
) Constraint {
    return hasTypeInfo(.{ .Struct = .{ .layout = layout } })
        .orElse(hasTypeInfo(.{ .Union = .{ .layout = layout } }));
}

pub const Child = std.meta.Child;

pub fn SliceChild(comptime Type: type) type {
    switch (@typeInfo(Type)) {
        .Pointer => |info| {
            switch (info.size) {
                .One => {
                    switch (@typeInfo(info.child)) {
                        .Array => |array_info| return array_info.child,
                        else => {},
                    }
                },
                .Slice => return info.child,
                else => {},
            }
        },
        else => {},
    }
    @compileError(std.fmt.comptimePrint(
        "type '{}' cannot coerce to a slice",
        .{ Type }
    ));
}


// --------------------------
// Function definition syntax
// --------------------------
// A `Returns` helper function allowing for trait requirements in
// function definitions. A warning, error messages are less helpful
// with this method because the error happens before the function is
// generated and thus the call site is not reported when building
// with -freference-trace

pub fn Returns(comptime ReturnType: type, comptime _: anytype) type {
    return ReturnType;
}


// -----------------
// Constructed types
// -----------------
// We compile time construct some types based on types in `std.builtin`.

// build our own version of the TypeId enum for clean error messages
pub const TypeId = @Type(std.builtin.Type{
    .Enum = .{
        .tag_type = @typeInfo(std.builtin.TypeId).Enum.tag_type,
        .fields = @typeInfo(std.builtin.TypeId).Enum.fields,
        .decls = &[0]std.builtin.Type.Declaration{},
        .is_exhaustive = false,
    },
});

fn getTypeFieldName(comptime id: TypeId) []const u8 {
    return @typeInfo(TypeInfo).Union.fields[@intFromEnum(id)].name;
}

// Construct a new union type TypeInfo based on std.builtin.Type such that
// each field std.buitlin.Type has a corresponding field in TypeInfo of type
// struct containing an optional wrapped version of all subfields other than
// 'fields' and 'decls'. The default value of each generated optional field is
// set to null.
//
// The idea is to create a type that can be used to optionally constrain
// metadata for any generic type
pub const TypeInfo = @Type(std.builtin.Type{ .Union = .{
    .layout = @typeInfo(std.builtin.Type).Union.layout,
    .tag_type = TypeId,
    .fields = init: {
        const og_uflds = @typeInfo(std.builtin.Type).Union.fields;
        var uflds: [og_uflds.len]std.builtin.Type.UnionField = undefined;
        inline for (&uflds, og_uflds) |*ufld, og_ufld| {
            const type_info = @typeInfo(og_ufld.type);
            if (type_info == .Struct) {
                const struct_info = type_info.Struct;
                ufld.*.type = @Type(std.builtin.Type{ .Struct = .{
                    .layout = struct_info.layout,
                    .backing_integer = struct_info.backing_integer,
                    .decls = &[0]std.builtin.Type.Declaration{},
                    .is_tuple = struct_info.is_tuple,
                    .fields = sinit: {
                        var og_sflds = struct_info.fields;
                        var sflds: [og_sflds.len]std.builtin.Type.StructField
                            = undefined;
                        var i: usize = 0;
                        inline for (og_sflds) |fld| {
                            if (std.mem.eql(u8, fld.name, "fields")) {
                                continue;
                            } else if (std.mem.eql(u8, fld.name, "decls")) {
                                continue;
                            }
                            sflds[i] = fld;
                            sflds[i].type = @Type(std.builtin.Type{
                                .Optional = .{
                                    .child = fld.type,
                                },
                            });
                            sflds[i].default_value = @ptrCast(
                                &@as(?fld.type, null)
                            );
                            i += 1;
                        }
                        break :sinit sflds[0..i];
                    },
                } });
            } else {
                ufld.*.type = struct {};
            }
            ufld.*.name = og_ufld.name;
            ufld.*.alignment = og_ufld.alignment;
        }
        break :init &uflds;
    },
    .decls = &[0]std.builtin.Type.Declaration{},
} });


test {
    std.testing.refAllDecls(@This());
}
