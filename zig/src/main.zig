const server = @import("server.zig");
const http = @import("http.zig");

const Server = server.Server;

pub fn main() !void {
    var s = try Server.init([4]u8{ 127, 0, 0, 1 }, 8080);

    try s.serve();
}
