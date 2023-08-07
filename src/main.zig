const n = @import("net.zig");
const Runtime = @import("util/Runtime.zig");

pub const io_mode = .evented;
var runtime: Runtime = undefined;

fn work() !void {
    const server = n.init(Runtime.allocator);
    try await async n.serverLifecycle(server, Runtime.allocator);
}

pub fn main() !void {
    try Runtime.run(work, .{});
}
