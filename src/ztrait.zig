const std = @import("std");

// ------------------
// Core Functionality
// ------------------

pub const TraitFn = *const fn (type) Interface;

pub const Interface = struct {
    Requires: type = struct {},
    Using: type = struct {},
};

pub fn where(comptime T: anytype, comptime constraint: Constraint) void {
    if (constraint.check(T)) |reason| {
        @compileError(reason);
    }
}

pub fn isAny() Constraint {
    return .any;
}

pub fn hasTypeId(comptime id: TypeId) Constraint {
    return hasTypeInfo(@unionInit(TypeInfo, getTypeFieldName(id), .{}));
}

pub fn hasTypeInfo(comptime info: TypeInfo) Constraint {
    comptime {
        const infos = [1]TypeInfo{info};
        return .{ .infos = &infos };
    }
}

pub fn hasOneOfTypeInfos(comptime infos: anytype) Constraint {
    comptime {
        const fields = @typeInfo(@TypeOf(infos)).Struct.fields;
        var info_array: [fields.len]TypeInfo = undefined;
        inline for (fields, info_array[0..fields.len]) |fld, *t_info| {
            t_info.* = @field(infos, fld.name);
        }
        return .{ .infos = &info_array };
    }
}

// Expects TraitFn, []const TraitFn, or a tuple with each field a TraitFn
pub fn implements(comptime trait: anytype) Constraint {
    comptime {
        switch (@typeInfo(@TypeOf(trait))) {
            .Struct => |tuple_info| {
                const fields = tuple_info.fields;
                var trait_array: [fields.len]TraitFn = undefined;
                inline for (fields, trait_array[0..fields.len]) |fld, *tFn| {
                    tFn.* = @field(trait, fld.name);
                }
                return .{ .traits = &trait_array };
            },
            .Pointer => |info| if (info.size == .Slice) {
                return .{ .traits = trait };
            },
            else => {},
        }
        const traits = [1]TraitFn{trait};
        return .{ .traits = &traits };
    }
}

fn checkType(comptime Type: type, comptime Expected: type) ?[]const u8 {
    if (Type != Expected) {
        return std.fmt.comptimePrint("expected '{}', found '{}'", .{ Expected, Type });
    }
    return null;
}

pub const Constraint = union(enum) {
    const Self = @This();

    any: void,
    infos: []const TypeInfo,
    traits: []const TraitFn,

    pub fn check(comptime self: Self, comptime Type: type) ?[]const u8 {
        return switch (self) {
            .any => null,
            .infos => |list| checkInfoList(Type, list),
            .traits => |list| checkTraitList(Type, list),
        };
    }
};

fn checkInfoList(
    comptime Type: type,
    comptime exp_infos: []const TypeInfo,
) ?[]const u8 {
    const type_info = @typeInfo(Type);
    const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));

    for (exp_infos) |exp_info| {
        if (@as(TypeId, exp_info) == type_id) {
            return checkInfo(Type, exp_info);
        }
    }

    if (exp_infos.len == 0) {
        return null;
    } else if (exp_infos.len == 1) {
        return std.fmt.comptimePrint(
            "expected '{}', found '{}'",
            .{ @as(TypeId, exp_infos[0]), type_id },
        );
    }

    const id_list: [exp_infos.len]TypeId = 0;
    for (exp_infos, &id_list) |info, *id| {
        id.* = @as(TypeId, info);
    }
    return std.fmt.comptimePrint(
        "expected one of '{}', found '{}'",
        .{ id_list[0..], type_id },
    );
}

fn checkInfo(comptime Type: type, comptime exp_info: TypeInfo) ?[]const u8 {
    const type_info = @typeInfo(Type);
    const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));
    const type_name = getTypeFieldName(type_id);
    const spec_info = @field(type_info, type_name);

    const exp = @field(exp_info, type_name);
    const exp_fields = @typeInfo(@TypeOf(exp)).Struct.fields;

    inline for (exp_fields) |fld_info| {
        const maybe_exp_fld = @field(exp, fld_info.name);
        if (maybe_exp_fld) |exp_fld| {
            const act_fld = @field(spec_info, fld_info.name);
            if (exp_fld != act_fld) {
                return std.fmt.comptimePrint("bad value for '@typeInfo({}).{s}.{s}': " ++ "expected '{}', found '{}'", .{ Type, type_name, fld_info.name, exp_fld, act_fld });
            }
        }
    }

    return null;
}

fn checkTraitList(comptime Type: type, comptime list: []const TraitFn) ?[]const u8 {
    for (list) |Trait| {
        if (checkTrait(Type, Trait)) |reason| {
            return reason;
        }
    }

    return null;
}

fn checkTrait(comptime Type: type, comptime Trait: TraitFn) ?[]const u8 {
    const UWType = Unwrap(Type);
    const type_info = @typeInfo(UWType);
    const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));
    const type_name = getTypeFieldName(type_id);
    const spec_info = @field(type_info, type_name);

    if (!@hasField(@TypeOf(spec_info), "decls")) {
        return std.fmt.comptimePrint("type '{}' cannot implement traits: " ++ "'@typeInfo({}).{s}' missing field 'decls'", .{ UWType, UWType, type_name });
    }

    const TraitStruct = Trait(Type).Requires;
    const prelude = std.fmt.comptimePrint("'{}'", .{Type});

    inline for (@typeInfo(TraitStruct).Struct.decls) |decl| {
        const FieldType = @field(TraitStruct, decl.name);
        const DeclType = @TypeOf(FieldType);
        if (DeclType == type or DeclType == Constraint) {
            if (!@hasDecl(UWType, decl.name)) {
                return std.fmt.comptimePrint("{s}: missing decl '{}.{s}'", .{ prelude, UWType, decl.name });
            }
        }
    }
    inline for (@typeInfo(TraitStruct).Struct.decls) |decl| {
        const FieldType = @field(TraitStruct, decl.name);

        switch (@TypeOf(FieldType)) {
            Constraint => {
                const fld = @field(UWType, decl.name);
                if (FieldType.check(fld)) |reason| {
                    return std.fmt.comptimePrint("{s}: '{}.{s}' {s}", .{ prelude, UWType, decl.name, reason });
                }
            },
            type => {
                const fld = @field(UWType, decl.name);
                if (checkType(@TypeOf(fld), FieldType)) |reason| {
                    return std.fmt.comptimePrint("{s}: '@TypeOf({}.{s})' {s}", .{ prelude, UWType, decl.name, reason });
                }
            },
            else => return std.fmt.comptimePrint(
                "{s}: '@TypeOf({}.{s})' expected 'type' or 'Constraint'," ++ " found '{s}'",
                .{ prelude, TraitStruct, decl, @TypeOf(FieldType) },
            ),
        }
    }

    return null;
}

// ----------------
// Helper functions
// ----------------
//   To create your own helper functions:
//     - create a new file, e.g. "mytrait.zig"
//     - add the following line: `pub usingnamespace @import("trait");`
//     - define additional helpers as you please
//     - use `@import("mytrait.zig")` instead of `@import("trait")`

pub fn isNumber() Constraint {
    return hasOneOfTypeInfos(.{
        .{ .Int = .{} },
        .{ .Float = .{} },
    });
}

pub fn isContainer() Constraint {
    return hasOneOfTypeInfos(.{
        .{ .Struct = .{} },
        .{ .Union = .{} },
    });
}

pub fn isExternContainer() Constraint {
    return hasOneOfTypeInfos(.{
        .{ .Struct = .{ .layout = .Extern } },
        .{ .Union = .{ .layout = .Extern } },
    });
}

pub fn isPackedContainer() Constraint {
    return hasOneOfTypeInfos(.{
        .{ .Struct = .{ .layout = .Packed } },
        .{ .Union = .{ .layout = .Packed } },
    });
}

pub fn isTuple() Constraint {
    return hasTypeInfo(.{ .Struct = .{ .is_tuple = true } });
}

pub fn Unwrap(comptime Type: type) type {
    return switch (@typeInfo(Type)) {
        .Pointer => |info| if (info.size == .One) Unwrap(info.child) else Type,
        .Optional => |info| Unwrap(info.child),
        .ErrorUnion => |info| Unwrap(info.payload),
        else => Type,
    };
}

pub fn PtrChild(comptime Type: type) type {
    comptime where(Type, hasTypeInfo(.{ .Pointer = .{ .size = .One } }));
    return @typeInfo(Type).Pointer.child;
}

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
    @compileError(std.fmt.comptimePrint("type '{}' cannot coerce to a slice", .{Type}));
}

// *********************************
// v Some @Type madness lies below v
// *********************************

// ---------------
// Implementations
// ---------------

pub fn Impl(comptime Type: type, comptime traits: anytype) type {
    comptime {
        const constraint = implements(traits);
        if (constraint.check(Type)) |reason| {
            @compileError(reason);
        }
        const Trait = Join(null, constraint.traits);
        const require_decls = getNamespace(Trait(Type).Requires);
        const using_decls = getNamespace(Trait(Type).Using);
        const num_fields = require_decls.len + using_decls.len;
        var fields: [num_fields]std.builtin.Type.StructField = undefined;

        for (fields[0..require_decls.len], require_decls) |*fld, decl| {
            const trait_decl = @field(Trait(Type).Requires, decl.name);
            const type_decl = @field(Unwrap(Type), decl.name);
            fld.*.name = decl.name;
            fld.*.alignment = 0;
            fld.*.is_comptime = false;
            fld.*.type = switch (@TypeOf(trait_decl)) {
                Constraint => type,
                else => trait_decl,
            };
            fld.*.default_value = &type_decl;
        }
        for (fields[require_decls.len..], using_decls) |*fld, decl| {
            const trait_decl = @field(Trait(Type).Using, decl.name);
            fld.*.name = decl.name;
            fld.*.alignment = 0;
            fld.*.is_comptime = false;
            fld.*.type = @TypeOf(trait_decl);
            fld.*.default_value = &trait_decl;
        }
        return @Type(std.builtin.Type{ .Struct = .{
            .layout = .Auto,
            .backing_integer = null,
            .fields = &fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_tuple = false,
        } });
    }
}

fn getNamespace(comptime Type: type) []const std.builtin.Type.Declaration {
    return switch (@typeInfo(Type)) {
        inline else => |info| if (@hasField(@TypeOf(info), "decls")) info.decls else &[0]std.builtin.Type.Declaration{},
    };
}

fn Join(
    comptime MTrait: ?TraitFn,
    comptime traits: []const TraitFn,
) TraitFn {
    if (MTrait) |Trait| {
        if (traits.len == 0) {
            return Trait;
        }
        return Join(Union(Trait, traits[0]), traits[1..]);
    } else if (traits.len == 0) {
        return struct {
            fn E(comptime _: type) Interface {
                return .{};
            }
        }.E;
    }
    return Join(traits[0], traits[1..]);
}

pub fn Union(Trait1: TraitFn, Trait2: TraitFn) TraitFn {
    return struct {
        pub fn U(comptime Type: type) Interface {
            return .{
                .requires = struct {
                    pub usingnamespace Trait1(Type).Requires;
                    pub usingnamespace Trait2(Type).Requires;
                },
                .using = struct {
                    pub usingnamespace Trait1(Type).Using;
                    pub usingnamespace Trait2(Type).Using;
                },
            };
        }
    }.U;
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
                        const og_sflds = struct_info.fields;
                        var sflds: [og_sflds.len]std.builtin.Type.StructField = undefined;
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
                            sflds[i].default_value = @ptrCast(&@as(?fld.type, null));
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
