// grid3-click.exe: moves the pointer to a screen point and left-clicks, only when that point is over Grid 3.
// Grid 3 has uiAccess, so Windows drops clicks from normal processes. This exe runs elevated from a scheduled
// task (tools\install-grid3-click.ps1), so its input reaches Grid 3 even when an elevated window has focus.
// The point comes from %ProgramData%\grid3-web-grids\grid3-click-request.txt ("x y", physical pixels), written by
// tools\grid3-click.ps1. No request file: it clicks where the pointer is. It logs to grid3-click.log there.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

static class Grid3Click
{
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct MouseInput { public int Dx, Dy, Data, Flags, Time; public IntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public int Type; public MouseInput Mouse; }

    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint count, Input[] inputs, int size);

    const int Move = 1, LeftDown = 2, LeftUp = 4;

    static string Owner(Point point)
    {
        uint pid;
        GetWindowThreadProcessId(WindowFromPoint(point), out pid);
        try { return Process.GetProcessById((int)pid).ProcessName; } catch (ArgumentException) { return ""; }
    }

    static uint Send(params int[] flags)
    {
        var inputs = new Input[flags.Length];
        for (int i = 0; i < flags.Length; i++) inputs[i].Mouse.Flags = flags[i];
        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(Input)));
    }

    static int Main()
    {
        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "grid3-web-grids");
        string log = Path.Combine(dir, "grid3-click.log"), request = Path.Combine(dir, "grid3-click-request.txt");
        Directory.CreateDirectory(dir);
        string stamp = DateTime.Now.ToString("s");
        SetProcessDpiAwarenessContext(new IntPtr(-4)); // per-monitor v2: physical pixels on every monitor
        Point point;
        GetCursorPos(out point);
        if (File.Exists(request))
        {
            string text = File.ReadAllText(request).Trim();
            File.Delete(request);
            string[] parts = text.Split(' ');
            int x, y;
            if (parts.Length != 2 || !int.TryParse(parts[0], out x) || !int.TryParse(parts[1], out y))
            {
                File.AppendAllText(log, stamp + " refused: bad request '" + text + "'\r\n");
                return 2;
            }
            point.X = x; point.Y = y;
        }
        string owner = Owner(point);
        if (owner != "Grid 3")
        {
            File.AppendAllText(log, stamp + " refused: " + point.X + "," + point.Y + " is over '" + owner + "', not Grid 3\r\n");
            return 2;
        }
        // A real mouse move lets Grid 3 see the pointer arrive and highlight the cell before the click.
        SetCursorPos(point.X, point.Y);
        Send(Move);
        Thread.Sleep(400);
        uint sent = Send(LeftDown, LeftUp);
        File.AppendAllText(log, stamp + " clicked Grid 3 at " + point.X + "," + point.Y + " (sent " + sent + " of 2)\r\n");
        return sent == 2 ? 0 : 1;
    }
}
