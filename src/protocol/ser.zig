const base = @import("./base.zig");
const s = @import("std");
const b = s.builtin;

fn arrayList(fal: []const u8, allocator: s.mem.Allocator) !s.ArrayList(u8) {
    var al = s.ArrayList(u8).init(allocator);
    try al.appendSlice(fal);
    return al;
}

pub fn serialize(comptime T: type, real: T, allocator: s.mem.Allocator) !s.ArrayList(u8) {
    return switch (@typeInfo(T)) {
        .Bool => arrayList(&[_]u8{if (@as(bool, real)) 0x1 else 0x0}, allocator),
        .Int, .Float => arrayList(s.mem.asBytes(&real), allocator),
        else => switch (T) {
            (base.VarI32) => base.VarI32.serialize(@as(base.VarI32, real), allocator),
            (base.VarI64) => base.VarI64.serialize(@as(base.VarI64, real), allocator),
            else => {
                if (@hasDecl(T, "zcSerialize")) {
                    return try real.zcSerialize(real, allocator);
                } else @compileError("unsupported type!");
            },
        },
    };
}

pub const DeserializeError = error{InvalidData};

pub fn deserialize(comptime T: type, data: []const u8, allocator: s.mem.Allocator) !T {
    return switch (@typeInfo(T)) {
        .Bool => switch (data[0]) {
            0x0 => false,
            0x1 => true,
            else => DeserializeError.InvalidData,
        },
        .Int, .Float => s.mem.bytesToValue(T, data),
        else => switch (T) {
            base.VarI32, base.VarI64 => |varint| {
                return try varint.deserialize(data);
            },
            else => {
                if (@hasDecl(T, "zcDeserialize")) return try T.zcDeserialize(data, allocator) else @compileError("unsupported type!");
            },
        },
    };
}
