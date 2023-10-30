const trait = @import("trait");
const where = trait.where;
const hasTypeInfo = trait.hasTypeInfo;
pub usingnamespace trait;

pub fn BackingInteger(comptime Type: type) type {
    comptime where(Type, hasTypeInfo(.{ .Struct = .{ .layout = .Packed } }));

    return @typeInfo(Type).Struct.backing_integer.?;
}

