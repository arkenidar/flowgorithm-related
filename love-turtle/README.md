Love2D Turtle (LOGO) demo

This folder contains a minimal Love2D-compatible turtle graphics library and a demo that uses the same API as your original `turtle` module.

Files:

- `turtle.lua` - minimal LOGO-like API (move, turn, jump, wait, pndn, pnup, pncl, pnsz, wipe, save)
- `main.lua` - Love2D entrypoint that runs `demo.lua` in a coroutine
- `demo.lua` - example adapted from your original script

How to run:

1. Install Love2D (https://love2d.org/)
2. From the `love-turtle` folder, run: love .

Controls:

- Click or press any key to resume when `wait()` is called with no arguments.

Window and scaling:

- The window is resizable. The turtle content auto-scales to fit within the window (with padding) both when shrinking and enlarging.

Notes and limitations:

- This is a small demo implementation and doesn't replicate all features of the original `turtle` (wx-based) module.
- The code uses coroutines so `demo.lua` runs linearly and `wait(seconds)` yields until the time passes or until user input when called without arguments.

If you'd like: I can add more LOGO primitives (circle, fill, text), multi-turtle support, or an exporter for higher-resolution PNGs.
