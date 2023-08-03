const s = @import("std");
const ev = s.event;
const packets = @import("protocol/packets.zig");
const chan = @import("util/chan.zig");
const Runtime = @import("util/Runtime.zig");

pub const ServerInner = struct { players: s.AutoArrayHashMap(s.net.Address, NetPlayer), stream: s.net.StreamServer };
pub const Server = ev.RwLocked(ServerInner);
pub const NetPlayer = struct { conn: ev.Locked(s.net.StreamServer.Connection), packets: Packets };
pub const Packets = struct { clientbound: chan.Channel(packets.PacketClientbound).SendHalf, serverbound: chan.Channel(packets.PacketServerbound).RecvHalf };

pub fn serverLifecycle(server_lock: *Server, allocator: s.mem.Allocator) !void {
    var server_raii = await async server_lock.acquireWrite();
    errdefer server_raii.release();
    try server_raii.value.stream.listen();
    while (server_raii.value.stream.accept()) |conn| {
        const clientbound = try chan.Channel(packets.PacketClientbound).init(allocator);
        const serverbound = try chan.Channel(packets.PacketServerbound).init(allocator);
        const net = NetPlayer{ .conn = conn, .packets = Packets{ .clientbound = .{ .parent = clientbound.inner }, .serverbound = .{ .parent = serverbound.inner } } };
        async netLifecycle(&net, .{ .parent = clientbound.inner }, .{ .parent = serverbound.inner });
        try server_raii.value.players.put(conn.address, net);
    } else |err| {
        return err;
    }
}

fn netLifecycle(rt: *Runtime, net: *NetPlayer, clientbound: chan.Channel(packets.PacketClientbound).RecvHalf, serverbound: chan.Channel(packets.PacketServerbound).SendHalf) !void {
    rt.spawn(handleClientbound, .{ &net.conn, clientbound });
    rt.spawn(handleServerbound, .{ &net.conn, serverbound });
}

fn handleClientbound(socket: *ev.Locked(s.net.StreamServer.Connection), channel: chan.Channel(packets.PacketClientbound).RecvHalf) !void {
    // TODO no op as there are no clientbound packets right now
    _ = socket;
    while (await channel.recv()) |packet| {
        _ = packet;
    }
}

fn handleServerbound(socket: *ev.Locked(s.net.StreamServer.Connection), channel: chan.Channel(packets.PacketServerbound).SendHalf, allocator: s.mem.Allocator) !void {
    const lock = socket.acquire();
    defer lock.release();
    const unlocked: *s.net.StreamServer.Connection = lock.value;
    const stream: *s.net.Stream = &unlocked.stream;
    const reader = s.io.bufferedReaderSize(packets.SerializedPacket.max_size, stream.reader());
    var dest: []u8 = undefined;
    while (true) {
        if (try reader.read(dest) == 0) continue;
        const packet = try packets.SerializedPacket.Uncompressed.zcDeserialize(&dest, allocator);
        await async channel.send(try packet.toPacketUnion(packets.PacketServerbound, allocator));
    }
}
