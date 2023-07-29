const h = @import("./helpers.zig");
const s = @import("std");

pub const State = enum { status, login, disconnected };

pub const ProtocolError = error{
    VarIntTooBig,
};

const segment_bits: i32 = 0x7F;
const continue_bit: i32 = 0x80;

fn varintDeserializeInner(comptime T: type, byte: u8, current: struct { value: T, position: u32 }, max_position: u32) !struct { value: T, position: u32, do_continue: ?void } {
    if (current.position + 7 >= max_position) return ProtocolError.VarIntTooBig;
    return .{
        .value = @as(T, current.value | (byte & @intCast(u8, segment_bits))),
        .position = current.position + 7,
        .do_continue = if ((byte & continue_bit) == 0) null else {},
    };
}

fn varintDeserialize(comptime T: type, slc: []const u8) !T {
    var data = .{ .value = @as(T, 0), .position = 0 };
    for (slc) |item| {
        const next = try varintDeserializeInner(T, item, data, if (T == i32) 32 else 64);
        data = .{ .value = next.value, .position = next.position };
        if (next.do_continue) {} else break;
    }
}

pub const VarI32 = makeVarInt(i32);
pub const VarI64 = makeVarInt(i64);

pub fn unsignedRightShift(comptime T: type, x: T, y: anytype) T {
    switch (@typeInfo(T)) {
        .Int => |int| {
            return @bitCast(T, @bitCast(@Type(.{ .Int = .{
                .bits = int.bits,
                .signedness = .unsigned,
            } }), x) >> y);
        },
        else => @compileError("non int"),
    }
}

fn makeVarInt(comptime T: type) type {
    switch (T) {
        i32, i64 => {},
        else => @compileError("varint supports only i32 & i64"),
    }

    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn serialize(self: Self, allocator: s.mem.Allocator) !s.ArrayList(u8) {
            var value = self.value;
            var result = s.ArrayList(u8).init(allocator);

            while (true) {
                if (value & (~(@intCast(T, segment_bits))) == 0) {
                    try result.append(@intCast(u8, value));
                    break;
                }

                try result.append(@intCast(u8, (value & @intCast(T, segment_bits)) | @intCast(T, continue_bit)));

                value = unsignedRightShift(T, value, 7);
            }

            return result;
        }

        pub fn deserialize(buffer: []const u8) !Self {
            return .{
                .value = try varintDeserialize(T, buffer),
            };
        }
    };
}
