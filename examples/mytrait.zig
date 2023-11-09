const trait = @import("trait");
const where = trait.where;
const isPackedContainer = trait.isPackedContainer;
pub usingnamespace trait;

pub fn BackingInteger(comptime Type: type) type {
    comptime where(Type, isPackedContainer());

    return switch (@typeInfo(Type)) {
        inline .Struct, .Union => |info| info.backing_integer.?,
        else => unreachable,
    };
}

