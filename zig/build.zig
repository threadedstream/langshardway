const std = @import("std");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable(
        "web-server",
        "src/main.zig",
    );

    b.installArtifact(exe);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}