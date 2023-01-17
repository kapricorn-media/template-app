const std = @import("std");

const Sdk = @import("deps/ZigAndroidTemplate/Sdk.zig");

pub fn build(b: *std.build.Builder) !void {
    // Default-initialize SDK
    const sdk = Sdk.init(b, null, .{});
    const mode = b.standardReleaseOptions();
    const android_version = b.option(Sdk.AndroidVersion, "android", "Select the android version, default is 'android5'") orelse .android5;
    const aaudio = b.option(bool, "aaudio", "Compile with support for AAudio, default is 'false'") orelse false;
    const opensl = b.option(bool, "opensl", "Compile with support for OpenSL ES, default is 'true'") orelse true;

    // Provide some KeyStore structure so we can sign our app.
    // Recommendation: Don't hardcore your password here, everyone can read it.
    // At least not for your production keystore ;)
    const key_store = Sdk.KeyStore{
        .file = ".build_config/android.keystore",
        .alias = "default",
        .password = "ziguana",
    };

    var libraries = std.ArrayList([]const u8).init(b.allocator);
    try libraries.append("GLESv2");
    try libraries.append("EGL");
    try libraries.append("android");
    try libraries.append("log");

    if (aaudio) try libraries.append("aaudio");
    if (opensl) try libraries.append("OpenSLES");

    // This is a configuration for your application.
    // Android requires several configurations to be done, this is a typical config
    const config = Sdk.AppConfig{
        .target_version = android_version,

        // This is displayed to the user
        .display_name = "Template",

        // This is used internally for ... things?
        .app_name = "template",

        // This is required for the APK name. This identifies your app, android will associate
        // your signing key with this identifier and will prevent updates if the key changes.
        .package_name = "net.thredia.template",

        // This is a set of resources. It should at least contain a "mipmap/icon.png" resource that
        // will provide the application icon.
        .resources = &[_]Sdk.Resource{
            .{ .path = "mipmap/icon.png", .content = .{ .path = "icon.png" } },
        },

        .aaudio = aaudio,

        .opensl = opensl,

        // This is a list of android permissions. Check out the documentation to figure out which you need.
        .permissions = &[_][]const u8{
            "android.permission.SET_RELEASE_APP",
            // "android.permission.RECORD_AUDIO",
        },

        // This is a list of native android apis to link against.
        .libraries = libraries.items,
    };

    const app = sdk.createApp(
        "zig-out/template.apk",
        "src/main.zig",
        null,
        config,
        mode,
        .{
            .aarch64 = b.option(bool, "aarch64", "Enable the aarch64 build"),
            .arm = b.option(bool, "arm", "Enable the arm build"),
            .x86_64 = b.option(bool, "x86_64", "Enable the x86_64 build"),
            .x86 = b.option(bool, "x86", "Enable the x86 build"),
        }, // default targets
        key_store,
    );

    for (app.libraries) |exe| {
        // Provide the "android" package in each executable we build
        exe.addPackage(app.getAndroidPackage("android"));
    }

    // Make the app build when we invoke "zig build" or "zig build install"
    b.getInstallStep().dependOn(app.final_step);

    const keystore_step = b.step("keystore", "Initialize a fresh debug keystore");
    const push_step = b.step("push", "Push the app to a connected android device");
    const run_step = b.step("run", "Run the app on a connected android device");

    keystore_step.dependOn(sdk.initKeystore(key_store, .{}));
    push_step.dependOn(app.install());
    run_step.dependOn(app.run());
}
