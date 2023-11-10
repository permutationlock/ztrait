const ztrait = @import("ztrait");
const where = ztrait.where;
const isPackedContainer = ztrait.isPackedContainer;
pub usingnamespace ztrait;

pub fn BackingInteger(comptime Type: type) type {
    comptime where(Type, isPackedContainer());

    return switch (@typeInfo(Type)) {
        inline .Struct, .Union => |info| info.backing_integer.?,
        else => unreachable,
    };
}

