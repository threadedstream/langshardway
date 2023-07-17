const std = @import("std");
const http = @import("http.zig");

const log = std.log;

const client_msg = "Hello";
const server_msg = "HTTP/1.1 200 OK\r\n\r\n<h1>Goodbye</h1>";

pub const Server = struct {
    stream_server: std.net.StreamServer,
    running: bool,

    pub fn init(address: [4]u8, port: u16) !Server {
        const ipv4_address = std.net.Address.initIp4(address, port);

        var server = std.net.StreamServer.init(.{ .reuse_address = true });
        try server.listen(ipv4_address);

        log.info("started listening on port {d}", .{port});

        return Server{ .stream_server = server, .running = false };
    }

    pub fn deinit(self: *Server) void {
        self.stream_server.deinit();
    }

    pub fn serve(self: *Server) !void {
        self.running = true;
        while (self.running) {
            try self.accept();
        }
    }

    pub fn stop(self: *Server) void {
        self.running = false;
    }

    fn accept(self: *Server) !void {
        const conn = try self.stream_server.accept();
        defer conn.stream.close();

        var buf: [1024]u8 = undefined;
        _ = try conn.stream.read(buf[0..]);
        
        log.info("[client] => {s}", .{buf});

        _ = try conn.stream.write(server_msg);
    }
};