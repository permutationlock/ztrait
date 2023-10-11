const std = @import("std");
const meta = std.meta;
const maxInt = std.math.maxInt;

pub const TraitFn = fn (type) type;

// build our own version of the TypeId enum for clean error messages
pub const TypeId = @Type(
    std.builtin.Type{
        .Enum = .{
            .tag_type = @typeInfo(std.builtin.TypeId).Enum.tag_type,
            .fields = @typeInfo(std.builtin.TypeId).Enum.fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,
        }, 
    }
);

// Construct a new union type TypeInfo based on std.builtin.Type such that
// each field std.buitlin.Type has a corresponding field in TypeInfo of type
// struct containing an optional version of all subfields other than 'fields'
// and 'decls'.
// The idea is to create a type that can be used to optionally constrain
// metadata for a generic type of a given TypeId
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
                        var og_sflds  = struct_info.fields;
                        var sflds: [og_sflds.len]std.builtin.Type.StructField
                            = undefined;
                        var i: usize = 0;
                        inline for (og_sflds) |fld| {
                            if (std.mem.eql(u8, fld.name, "fields")
                                or std.mem.eql(u8, fld.name, "decls")
                            ) {
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
                }});
            } else {
                ufld.*.type = struct {};
            }
            ufld.*.name = og_ufld.name;
            ufld.*.alignment = og_ufld.alignment;
        }
        break :init &uflds;
    },
    .decls = &[0]std.builtin.Type.Declaration{},
}});

fn getTypeFieldName(comptime id: TypeId) []const u8 {
    comptime {
        return @typeInfo(TypeInfo).Union.fields[@intFromEnum(id)].name;
    }
}

pub fn Returns(comptime ReturnType: type, comptime _: anytype) type {
    return ReturnType;
}

pub fn where(comptime T: anytype) Where(T) {
    switch (@typeInfo(@TypeOf(T))) {
        .Type => return .{ .Type = T },
        inline else => return .{ .value = T },
    }
}

fn Where(comptime T: type) type {
    switch (@typeInfo(@TypeOf(T))) {
        .Type => return struct {
            const Self = @This();

            Type: type,

            pub fn child(comptime self: Self) Self {
                const type_info = @typeInfo(self.Type);
                const type_id: TypeId = @enumFromInt(@intFromEnum(type_info)); 
                const type_name = getTypeFieldName(type_id);
                const spec_info = @field(type_info, type_name);
                if (!@hasField(@TypeOf(spec_info), "child")) {
                    return std.fmt.comptimePrint(
                        "'@typeInfo({}).{s}' has no field 'child'",
                        .{ T, type_name }
                    );
                }

                return .{ .Type = spec_info.child };
            }

            pub fn hasTypeId(comptime self: Self, comptime id: TypeId) Self {
                any().hasTypeId(id).assert(self.Type);
                return self;
            }

            pub fn hasTypeInfo(comptime self: Self, comptime info: TypeInfo) Self {
                any().hasTypeInfo(info).assert(self.Type);
                return self;
            }

            pub fn implements(comptime self: Self, comptime trait: TraitFn) Self {
                any().implements(trait).assert(self.Type);
                return self;
            }

            pub fn implementsAll(
                comptime self: Self, comptime traits: anytype
            ) Self {
                any().implementsAll(traits).assert(self.Type);
                return self;
            }
        },
        else => return struct {
            const Self = @This();

            value: T,

            pub fn is(comptime self: Self, comptime expected: T) void {
                if (self.value != expected) {
                    @compileError(std.fmt.comptimePrint(
                        "expected '{any}', found '{any}'",
                        .{ expected, self.value }
                    ));
                }
            }
        },
    }
}

pub fn any() Constraint { return .{}; }

pub fn hasTypeId(comptime id: TypeId) Constraint {
    return any().hasTypeId(id);
}

pub fn hasTypeInfo(comptime info: TypeInfo) Constraint {
    return any().hasTypeInfo(info);
}

pub fn implements(comptime trait: TraitFn) Constraint {
    return any().implements(trait);
}

pub fn implementsAll(comptime traits: anytype) Constraint {
    return any().implementsAll(traits);
}

pub fn hasChild(comptime constraint: Constraint) Constraint {
    return any().hasChild(constraint);
}

pub const Constraint = struct {
    const Self = @This();

    child: ?*const Constraint = null,
    info: ?TypeInfo = null,
    traits: []const *const TraitFn = &[0]*const TraitFn{},

    pub fn hasTypeId(comptime self: Self, comptime id: TypeId) Self {
        return .{
            .child = self.child,
            .info = @unionInit(TypeInfo, getTypeFieldName(id), .{}),
            .traits = self.traits
        };
    }

    pub fn hasTypeInfo(comptime self: Self, comptime info: TypeInfo) Self {
        return .{ .child = self.child, .info = info, .traits = self.traits };
    }

    pub fn hasChild(comptime self: Self, comptime sub_contract: Self) Self {
        comptime {
            const child_contract = sub_contract;
            var contract = self;
            contract.child = &child_contract;
            return contract;
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
            var contract = self;
            contract.traits = &traitArray;
            return contract;
        }
    }

    pub fn check(comptime self: Self, comptime Type: type) ?[]const u8 {
        const type_info = @typeInfo(Type);
        const type_id: TypeId = @enumFromInt(@intFromEnum(type_info)); 
        const type_name = getTypeFieldName(type_id);
        const spec_info = @field(type_info, type_name);
        if (self.info) |exp_info| {
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
                            "unexpected value for '@typeInfo({}).{s}.{s}': "
                                ++ "expected '{}', found '{}'",
                            .{
                                Type,
                                type_name,
                                fld_info.name,
                                exp_fld,
                                act_fld
                            }
                        );
                    }
                }
            }
        }
        if (self.traits.len > 0) {
            if (!@hasField(@TypeOf(spec_info), "decls")) {
                return std.fmt.comptimePrint(
                    "'@typeInfo({}).{s}' has no field 'decls'",
                    .{ Type, type_name }
                );
            }
        }
        inline for (self.traits) |trait| {
            const Interface = trait.*(Type);
            const prelude = std.fmt.comptimePrint(
                "trait '{}' failed",
                .{ Interface }
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

        if (self.child) |child_contract| {
            if (@hasField(@TypeOf(spec_info), "child")) {
                if (child_contract.*.check(spec_info.child)) |reason| {
                    return reason;
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
