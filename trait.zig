const std = @import("std");

// ------------------
// Core Functionality
// ------------------

pub const TraitFn = fn (type) type;

pub fn is(comptime enforced_type: type) Constraint {
    return .{ .enforced_type = enforced_type };
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

pub fn hasOneOfTypeInfo(comptime infos: anytype) Constraint {
    return isAny().hasOneOfTypeInfo(infos);
}

pub fn implements(comptime trait: TraitFn) Constraint {
    return isAny().implements(trait);
}

pub fn implementsAll(comptime traits: anytype) Constraint {
    return isAny().implementsAll(traits);
}

pub fn hasChild(comptime constraint: Constraint) Constraint {
    return isAny().hasChild(constraint);
}

pub const Constraint = struct {
    const Self = @This();

    enforced_type: ?type = null,
    or_constraint: ?*const Constraint = null,
    child_constraint: ?*const Constraint = null,
    infos: []TypeInfo = &[0]TypeInfo{},
    traits: []const *const TraitFn = &[0]*const TraitFn{},

    pub fn hasTypeId(comptime self: Self, comptime id: TypeId) Self {
        return self.hasTypeInfo(
            @unionInit(TypeInfo, getTypeFieldName(id), .{})
        );
    }

    pub fn hasTypeInfo(comptime self: Self, comptime info: TypeInfo) Self {
        return self.hasOneOfTypeInfo(.{info});
    }

    pub fn hasOneOfTypeInfo(comptime self: Self, comptime infos: anytype) Self {
        comptime {
            const fields = @typeInfo(@TypeOf(infos)).Struct.fields;
            var infoArray: [self.infos.len + fields.len]TypeInfo = undefined;
            inline for (fields, infoArray[0..fields.len]) |fld, *info| {
                info.* = @field(infos, fld.name);
            }
            inline for (self.infos, infoArray[fields.len..]) |i, *info| {
                info.* = i;
            }
            var constraint = self;
            constraint.infos = &infoArray;
            return constraint;
        }
    }

    pub fn hasChild(comptime self: Self, comptime sub_constraint: Self) Self {
        comptime {
            const child_constraint = sub_constraint;
            var constraint = self;
            constraint.child_constraint = &child_constraint;
            return constraint;
        }
    }

    pub fn orElse(comptime self: Self, comptime sub_constraint: Self) Self {
        comptime {
            const or_constraint = sub_constraint;
            var constraint = self;
            constraint.or_constraint = &or_constraint;
            return constraint;
        }
    }

    pub fn implements(comptime self: Self, comptime trait: TraitFn) Self {
        return self.implementsAll(.{trait});
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
            var constraint = self;
            constraint.traits = &traitArray;
            return constraint;
        }
    }

    pub fn check(comptime self: Self, comptime Type: type) ?[]const u8 {
        if (self.enforced_type) |ET| {
            if (Type != ET) {
                return std.fmt.comptimePrint(
                    "expected '{}', found '{}'",
                    .{ ET, Type }
                );
            } else {
                return null;
            }
        }
        if (self.or_constraint) |constraint| {
            if (constraint.check(Type) == null) {
                return null;
            }
        }

        const type_info = @typeInfo(Type);
        const type_id: TypeId = @enumFromInt(@intFromEnum(type_info));
        const type_name = getTypeFieldName(type_id);
        const spec_info = @field(type_info, type_name);

        // verify type info
        var tid_match: bool = false;
        var tinfo_err: ?[]const u8 = null;
        for (self.infos) |exp_info| {
            const exp_id: TypeId = exp_info;
            if (exp_id != type_id) {
                continue;
            }
            tid_match = true;
            tinfo_err = null;
            const exp = @field(exp_info, type_name);
            const exp_fields = @typeInfo(@TypeOf(exp)).Struct.fields;
            inline for (exp_fields) |fld_info| {
                const maybe_exp_fld = @field(exp, fld_info.name);
                if (maybe_exp_fld) |exp_fld| {
                    const act_fld = @field(spec_info, fld_info.name);
                    if (exp_fld != act_fld) {
                        tinfo_err = std.fmt.comptimePrint(
                            "bad value for '@typeInfo({}).{s}.{s}': "
                                ++ "expected '{}', found '{}'",
                                .{
                                    Type,
                                    type_name,
                                    fld_info.name,
                                    exp_fld,
                                    act_fld
                                });
                        break;
                    }
                }
            }
        }
        if (!tid_match) {
            if (self.infos.len == 1) {
                return std.fmt.comptimePrint(
                    "expected '{}', found '{}'",
                    .{ @as(TypeId, self.infos[0]), type_id }
                );
            } else if (self.infos.len > 1) {
                const tids: [self.infos.len]TypeId = undefined;
                for (self.infos, &tids) |info, *tid| {
                    tid.* = @as(TypeId, info);
                }
                return std.fmt.comptimePrint(
                    "expected one of '{any}', found '{}'",
                    .{ tids, type_id }
                );
            }
        } else if (tinfo_err) |err| {
            return err;
        }

        // verify traits
        if (self.traits.len > 0) {
            if (!@hasField(@TypeOf(spec_info), "decls")) {
                return std.fmt.comptimePrint(
                    "type '{}' cannot implement traits: "
                        ++ "'@typeInfo({}).{s}' missing field 'decls'",
                    .{ Type, Type, type_name });
            }
        }
        inline for (self.traits) |trait| {
            const Interface = trait.*(Type);
            const prelude = std.fmt.comptimePrint(
                "trait '{}' failed",
                .{Interface}
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
                        "{s}: decl '{s}': expected '{}', found '{}'",
                        .{ prelude, decl.name, FieldType, @TypeOf(fld) }
                    );
                }
            }
        }

        // verify constraints on child type
        if (self.child_constraint) |constraint| {
            if (@hasField(@TypeOf(spec_info), "child")) {
                if (constraint.*.check(spec_info.child)) |reason| {
                    return std.fmt.comptimePrint(
                        "'{}' child: {s}",
                        .{ Type, reason }
                    );
                }
            } else {
                return std.fmt.comptimePrint(
                    "'@typeInfo({}).{s}' has no field 'child'",
                    .{ Type, type_name }
                );
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

pub fn isContainer() Constraint {
    return isAny().hasOneOfTypeInfo(.{
        .{ .Struct = .{} },
        .{ .Union = .{} },
    });
}

pub fn isContainerExtern() Constraint {
    return isContainerInternal(.Extern);
}

pub fn isContainerPacked() Constraint {
    return isContainerInternal(.Packed);
}

fn isContainerInternal(
    comptime layout: std.builtin.Type.ContainerLayout
) Constraint {
    return isAny().hasOneOfTypeInfo(.{
        .{ .Struct = .{ .layout = layout } },
        .{ .Union = .{ .layout = layout } },
    });
}

pub fn isMutPointerTo(comptime constraint: Constraint) Constraint {
    return isAny().hasTypeInfo(.{
        .Pointer = .{ .size = .One, .is_const = false },
    }).hasChild(constraint);
}

pub fn isConstPointer(comptime constraint: Constraint) Constraint {
    return isAny().hasTypeInfo(.{
        .{ .Pointer = .{ .size = .One } },
    }).hasChild(constraint);
}

pub fn coercesToMutSliceOf(comptime child_constraint: Constraint) Constraint {
    return coercesToSliceInternal(child_constraint, false);
}

pub fn coercesToConstSliceOf(comptime child_constraint: Constraint) Constraint {
    return coercesToSliceInternal(child_constraint, true);
}

fn coercesToSliceInternal(
    comptime child_constraint: Constraint,
    comptime is_const: bool
) Constraint {
    return isAny().hasTypeInfo(.{
        .Pointer = .{
            .size = .One,
            .is_const = if (is_const) true else null,
        }
    }).hasChild(
        hasTypeId(.Array).hasChild(child_constraint)
    ).orElse(
        isAny().hasTypeInfo(.{ .Pointer = .{ .size = .Slice } })
            .hasChild(child_constraint)
    );
}


// ------------
// Where syntax
// ------------
// The names were inspired by "where syntax" from Rust.
//
// E.g:
//
//    pub fn sumIntSlice(count_ptr: anytype, list: anytype) Returns(void, .{
//        where(@TypeOf(count_ptr), isMutPointer().hasChild(hasTypeId(.Int))),
//        where(@TypeOf(list), coercesToConstSliceOf(
//            is(@typeInfo(@TypeOf(count_ptr).Pointer.child))
//        ))
//    }) {
//        for (list) |elem| {
//            count_ptr.* += elem;
//        }
//    }
//
// Is equivalent to:
//
//    pub fn sumIntSlice(count_ptr: anytype, list: anytype) void {
//        comptime isMutPointer().hasChild(hasTypeId(.Int)))
//            .assert(@TypeOf(count_ptr))
//        comptime coercesToConstSliceOf(
//            is(@typeInfo(@TypeOf(count_ptr).Pointer.child))
//        )).assert(@TypeOf(list));
//
//        for (list) |elem| {
//            count_ptr.* += elem;
//        }
//    }

pub fn Returns(comptime ReturnType: type, comptime _: anytype) type {
    return ReturnType;
}

pub fn where(comptime T: anytype, comptime constraint: Constraint) void {
    constraint.assert(T);
}
