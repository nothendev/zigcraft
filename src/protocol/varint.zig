const s = @import("std");

pub const VarI32 = VarInt(i32);
pub const VarI64 = VarInt(i64);

pub fn unsignedRightShift(comptime T: type, x: T, y: anytype) T {
    switch (@typeInfo(T)) {
        .Int => |int| {
            return @as(T, @bitCast(@as(@Type(.{ .Int = .{
                .bits = int.bits,
                .signedness = .unsigned,
            } }), @bitCast(x)) >> y));
        },
        else => @compileError("non int"),
    }
}

fn VarInt(comptime T: type) type {
    switch (T) {
        i32, i64 => {},
        else => @compileError("varint supports only i32 & i64"),
    }

    return packed struct {
        value: T,
        len: usize,

        const Self = @This();
        pub const max_length: comptime_int = if (T == i32) 5 else 6;
        pub const zero: Self = .{ .value = 0, .len = 1 };

        pub fn init(value: T) Self {
            return .{ .value = value, .len = _calculateLength(value) };
        }

        const segment_bits: T = 0x7F;
        const continue_bit: T = 0x80;

        pub fn serialize(self: Self, allocator: s.mem.Allocator) ![]u8 {
            var value = self.value;
            var result = try allocator.alloc(u8, self.len);

            var i: usize = 0;
            while (i <= self.len) : (i += 1) {
                if ((value & ~segment_bits) == 0) {
                    result[i] = @intCast(value);
                    break;
                }

                result[i] = @intCast((value & segment_bits) | continue_bit);

                value = unsignedRightShift(T, value, 7);
            }

            return result;
        }

        pub fn deserialize(buffer: []const u8) !Self {
            var value: T = 0;
            var position: (if (T == i32) u5 else u6) = 0;
            var len: usize = 0;
            for (buffer) |current_byte| {
                len += 1;
                value |= s.math.shl(T, current_byte & @as(u8, @intCast(segment_bits)), position);
                if ((current_byte & @as(u8, @intCast(continue_bit))) == 0) break;
                position += 7;

                if (position >= (if (T == i32) 32 else 64)) return error.VarIntTooBig;
            }
            return Self{ .value = value, .len = len };
        }

        pub fn calculateLength(self: *const Self) usize {
            return _calculateLength(self.value);
        }

        pub fn _calculateLength(_value: T) usize {
            var value = _value;
            var result: usize = 0;

            while (true) {
                if ((value & ~segment_bits) == 0) {
                    result += 1;
                    break;
                }

                result += 1;

                value = unsignedRightShift(T, value, 7);
            }

            return result;
        }
    };
}
