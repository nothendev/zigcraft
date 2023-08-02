const s = @import("std");
const p = @import("./protocol.zig");
const Handshake = @import("./protocol/packets/Handshake.zig");
const expect = s.testing.expect;

pub const io_mode = .evented;

pub fn main() !void {}

// void testSerialize<T>(T thing, byte[] result);
fn testSerialize(comptime T: type, thing: T, result: []const u8) !void {
    s.debug.print("\ntesting (de)serialization of {s};\nreceived: {any};\nresult should be {s}\n", .{ @typeName(T), thing, s.fmt.fmtSliceHexLower(result) });
    var serialized = try p.serialize(T, thing, s.testing.allocator);
    defer serialized.deinit();
    try s.testing.expectEqualSlices(u8, result, serialized.items);
    s.debug.print("\nserialized: {s}\n", .{s.fmt.fmtSliceHexLower(serialized.items)});
    var deserialized = try p.deserialize(T, result, s.testing.allocator);
    try s.testing.expectEqualDeep(thing, deserialized);
    s.debug.print("yehoo\n", .{});
    defer if (@typeInfo(T) == .Struct) {
        if (@hasDecl(T, "deinit"))
            deserialized.deinit()
        else if (@hasDecl(T, "deinitialize")) deserialized.deinitialize(s.testing.allocator);
    };
}

test "types serialize correctly" {
    const handshake = Handshake{ .protocol_version = p.VarI32.init(763), .next_state = Handshake.NextState.login };
    var handshake_serialized = try p.SerializedPacket.Uncompressed.fromPacket(Handshake, handshake, s.testing.allocator);
    defer handshake_serialized.deinitialize(s.testing.allocator);
    try testSerialize(bool, true, &[_]u8{0x1});
    try testSerialize(u8, 0x17, &[_]u8{0x17});
    try testSerialize(p.VarI32, p.VarI32.init(2097151), &[_]u8{ 0xff, 0xff, 0x7f });
    try testSerialize(p.VarI32, p.VarI32.init(-2147483648), &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x08 });
    try testSerialize(p.VarI32, p.VarI32.init(763), &[_]u8{ 0xfb, 0x05 });
    try testSerialize(p.VarI64, p.VarI64.init(127), &[_]u8{0x7f});
    try testSerialize(p.VarI64, p.VarI64.init(128), &[_]u8{ 0x80, 0x01 });
    try testSerialize(p.VarI64, p.VarI64.init(-9223372036854775808), &[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01 });
    try testSerialize(Handshake, handshake, &[_]u8{ 0xfb, 0x05, 0x02 });
    try testSerialize(p.SerializedPacket.Uncompressed, handshake_serialized, &[_]u8{ 0x04, 0x00, 0xfb, 0x05, 0x02 });
}
