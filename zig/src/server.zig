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

        var req = try http.Request.init(&buf);
        defer req.deinit();

        log.info("[client] => path = {s}", .{req.path});
        log.info("[client] => method = {s}", .{req.method.string()});
        var keyIter = req.headers.keyIterator();
        while (keyIter.next()) |k| {
            log.info("{s}: {s}", .{ k.*, req.headers.get(k.*).? });
        }

        var resp = http.Response.init();
        defer resp.deinit();

        resp.status = http.Status.Ok;

        try resp.headers.put("Content-Type", "application/json");
        try resp.headers.put("Host", "localhost");

        const rstr = try resp.response_string();
        _ = try conn.stream.write(rstr);
    }
};
