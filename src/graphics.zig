const rl = @import("raylib");

pub fn showTestWindow() void {
    const screen_width = 1000;
    const screen_height = 700;

    rl.initWindow(
        screen_width,
        screen_height,
        "CMPS3111 Project 2 - Graphics Test",
    );

    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        rl.drawText(
            "CMPS3111 Project 2",
            350,
            250,
            30,
            rl.Color.black,
        );

        rl.drawText(
            "Raylib graphics test - SUCCESS!",
            300,
            310,
            24,
            rl.Color.dark_green,
        );

        rl.drawRectangleLines(
            250,
            200,
            500,
            200,
            rl.Color.black,
        );
    }
}
