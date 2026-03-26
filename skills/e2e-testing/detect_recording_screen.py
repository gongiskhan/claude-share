#!/usr/bin/env python3
"""
Detect which macOS screen the browser window is on and output the
corresponding ffmpeg AVFoundation device index.

Usage:
    python3 detect_recording_screen.py
    # Outputs a single integer: the ffmpeg -i device index for the correct screen.

How it works:
1. Finds the browser window position via osascript (tries Chromium, Chrome, etc.)
2. Gets active display bounds via Quartz (same top-left coordinate system as osascript)
3. Matches the window position to a display index
4. Maps that display index to an ffmpeg AVFoundation device index
"""

import subprocess
import sys
import re


def get_ffmpeg_screen_devices():
    """Parse ffmpeg AVFoundation device list to build screen_index -> device_index map."""
    result = subprocess.run(
        ["ffmpeg", "-f", "avfoundation", "-list_devices", "true", "-i", ""],
        capture_output=True, text=True,
    )
    output = result.stderr + result.stdout
    devices = {}
    for line in output.split("\n"):
        match = re.search(r"\[(\d+)\] Capture screen (\d+)", line)
        if match:
            device_idx = int(match.group(1))
            screen_idx = int(match.group(2))
            devices[screen_idx] = device_idx
    return devices


def get_browser_window_position():
    """Get (x, y) of the browser window using osascript. Tries several browser names."""
    browser_names = ["Chrome for Testing", "Chromium", "Google Chrome", "Chrome"]
    for name in browser_names:
        result = subprocess.run(
            [
                "osascript", "-e",
                f'tell application "System Events" to get position of first window of '
                f'(first process whose name contains "{name}")',
            ],
            capture_output=True, text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            parts = [int(x.strip()) for x in result.stdout.strip().split(",")]
            return parts[0], parts[1]
    return None, None


def get_display_for_position(win_x, win_y):
    """Return the display index (matching AVFoundation order) that contains (win_x, win_y).

    Tries multiple strategies:
    1. Quartz CGDisplay (most accurate, same coordinate system as osascript)
    2. AppKit NSScreen (Cocoa, needs coordinate conversion)
    3. JXA NSScreen via osascript (no Python framework needed)
    4. system_profiler display widths (assumes left-to-right arrangement)
    """
    # Strategy 1: Quartz
    try:
        from Quartz import CGGetActiveDisplayList, CGDisplayBounds

        err, display_ids, count = CGGetActiveDisplayList(16, None, None)
        if err != 0:
            raise ImportError("CGGetActiveDisplayList failed")

        for i, did in enumerate(display_ids):
            bounds = CGDisplayBounds(did)
            bx, by = bounds.origin.x, bounds.origin.y
            bw, bh = bounds.size.width, bounds.size.height
            if bx <= win_x < bx + bw and by <= win_y < by + bh:
                return i

    except ImportError:
        pass

    # Strategy 2: AppKit NSScreen
    try:
        from AppKit import NSScreen

        screens = NSScreen.screens()
        if screens:
            main_h = screens[0].frame().size.height
            cocoa_y = main_h - win_y
            for i, screen in enumerate(screens):
                f = screen.frame()
                if (f.origin.x <= win_x < f.origin.x + f.size.width
                        and f.origin.y <= cocoa_y < f.origin.y + f.size.height):
                    return i
    except ImportError:
        pass

    # Strategy 3: JXA osascript to get NSScreen frames (no Python frameworks needed)
    try:
        result = subprocess.run(
            [
                "osascript", "-l", "JavaScript", "-e",
                """
                ObjC.import('AppKit');
                var screens = $.NSScreen.screens;
                var result = [];
                for (var i = 0; i < screens.count; i++) {
                    var f = screens.objectAtIndex(i).frame;
                    result.push({x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height});
                }
                JSON.stringify(result);
                """,
            ],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            import json
            screens = json.loads(result.stdout.strip())
            if screens:
                main_h = screens[0]["h"]
                cocoa_y = main_h - win_y
                for i, s in enumerate(screens):
                    if (s["x"] <= win_x < s["x"] + s["w"]
                            and s["y"] <= cocoa_y < s["y"] + s["h"]):
                        print(f"JXA: screen {i} matches (cocoa_y={cocoa_y})", file=sys.stderr)
                        return i
    except Exception:
        pass

    # Strategy 4: system_profiler display widths, assume left-to-right layout
    try:
        result = subprocess.run(
            ["system_profiler", "SPDisplaysDataType"],
            capture_output=True, text=True, timeout=10,
        )
        widths = []
        for line in result.stdout.split("\n"):
            m = re.search(r"UI Looks like:\s*(\d+)\s*x\s*(\d+)", line)
            if m:
                widths.append(int(m.group(1)))

        if widths:
            cumulative_x = 0
            for i, w in enumerate(widths):
                if cumulative_x <= win_x < cumulative_x + w:
                    print(f"system_profiler fallback: screen {i} (x={cumulative_x}..{cumulative_x + w})",
                          file=sys.stderr)
                    return i
                cumulative_x += w
    except Exception:
        pass

    return 0  # final fallback: main display


def main():
    win_x, win_y = get_browser_window_position()

    devices = get_ffmpeg_screen_devices()

    if win_x is None:
        print(
            "WARNING: Could not find browser window. Using first available screen.",
            file=sys.stderr,
        )
        # Return the lowest-numbered screen device
        if devices:
            print(devices[min(devices.keys())])
        else:
            print(2)  # last-resort default
        return

    screen_idx = get_display_for_position(win_x, win_y)
    print(f"Browser window at ({win_x}, {win_y}) -> screen {screen_idx}", file=sys.stderr)

    if screen_idx in devices:
        print(devices[screen_idx])
    else:
        # Screen index not in device map -- try fallback
        print(
            f"WARNING: screen {screen_idx} not found in ffmpeg devices {devices}. "
            f"Falling back to screen 0.",
            file=sys.stderr,
        )
        print(devices.get(0, 2))


if __name__ == "__main__":
    main()
