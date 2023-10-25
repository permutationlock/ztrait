const trait = @import("trait");
pub usingnamespace trait;

pub fn isU32PackedStruct() trait.Constraint {
    return trait.hasTypeInfo(.{
        .Struct = .{
            .layout = .Packed,
            .backing_integer = u32,
        }
    });
}
