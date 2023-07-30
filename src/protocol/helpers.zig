pub const PacketType = enum {
    /// Client -> Server
    serverbound,
    /// Server -> Client
    clientbound,
};

pub fn Packet(comptime T: type, kind: PacketType) type {
    const info = @typeInfo(T);
    const reference = struct {
        const packet_kind: PacketType = kind;
    };
    const reference_info = @typeInfo(reference);
    if (reference_info != .Struct) unreachable;
    if (info != .Struct) unreachable;
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = info.Struct.fields,
            .decls = reference_info.Struct.decls ++ info.Struct.decls,
            .is_tuple = false,
        },
    });
}
