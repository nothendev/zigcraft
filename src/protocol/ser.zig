const base = @import("./base.zig");
const vi = @import("./varint.zig");
const s = @import("std");
const b = s.builtin;

fn arrayList(fal: []const u8, allocator: s.mem.Allocator) !s.ArrayList(u8) {
    var al = s.ArrayList(u8).init(allocator);
    try al.appendSlice(fal);
    return al;
}

pub fn toArrayList(thimg: anytype, allocator: s.mem.Allocator) !s.ArrayList(u8) {
    return switch (@TypeOf(thimg)) {
        s.ArrayList(u8) => thimg,
        []u8 => s.ArrayList(u8).fromOwnedSlice(allocator, thimg),
        []const u8 => try arrayList(thimg, allocator),
        else => @compileError("unsupported type: " ++ @typeName(@TypeOf(thimg))),
    };
}

pub fn serialize(comptime T: type, real: T, allocator: s.mem.Allocator) !s.ArrayList(u8) {
    return try toArrayList(switch (@typeInfo(T)) {
        .Bool => &[_]u8{if (@as(bool, real)) 0x1 else 0x0},
        .Int, .Float => s.mem.asBytes(&real),
        else => switch (T) {
            (vi.VarI32) => vi.VarI32.serialize(@as(vi.VarI32, real), allocator),
            (vi.VarI64) => vi.VarI64.serialize(@as(vi.VarI64, real), allocator),
            else => {
                if (@hasDecl(T, "zcSerialize")) {
                    return try real.zcSerialize(allocator);
                } else @compileError("unsupported type!");
            },
        },
    }, allocator);
}

pub const DeserializeError = error{InvalidData};

pub fn deserialize(comptime T: type, data: []const u8, allocator: s.mem.Allocator) !T {
    var bytes = data;
    return switch (@typeInfo(T)) {
        .Bool => switch (bytes[0]) {
            0x0 => false,
            0x1 => true,
            else => DeserializeError.InvalidData,
        },
        .Int, .Float => s.mem.bytesAsValue(T, data[0..@sizeOf(T)]).*,
        else => switch (T) {
            vi.VarI32, vi.VarI64 => |varint| {
                return try varint.deserialize(bytes);
            },
            else => {
                if (@hasDecl(T, "zcDeserialize")) return try T.zcDeserialize(bytes, allocator) else @compileError("unsupported type!");
            },
        },
    };
}
