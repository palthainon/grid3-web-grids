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
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    delegate bool EnumProc(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr data);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr window, int index);
    [DllImport("user32.dll")] static extern bool ScreenToClient(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern IntPtr ChildWindowFromPointEx(IntPtr parent, Point point, uint flags);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint count, Input[] inputs, int size);

    const int Move = 1, LeftDown = 2, LeftUp = 4, ExStyle = -20, ExTransparent = 0x20;
    const uint SkipInvisibleAndTransparent = 0x1 | 0x4;

    static string ProcessOf(IntPtr window)
    {
        uint pid;
        GetWindowThreadProcessId(window, out pid);
        try { return Process.GetProcessById((int)pid).ProcessName; } catch (ArgumentException) { return ""; }
    }

    // The process that gets a click at this point: the top window there that is not click-through
    // (WS_EX_TRANSPARENT overlays, such as a screen-control overlay, pass clicks on), then its deepest child.
    // A child from another process (Grid 3's web browser, msedgewebview2) counts as that process.
    static string Owner(Point point)
    {
        IntPtr top = IntPtr.Zero;
        EnumWindows((window, data) =>
        {
            Rect r;
            if (!IsWindowVisible(window) || (GetWindowLong(window, ExStyle) & ExTransparent) != 0 || !GetWindowRect(window, out r)) return true;
            if (point.X < r.Left || point.X >= r.Right || point.Y < r.Top || point.Y >= r.Bottom) return true;
            top = window;
            return false;
        }, IntPtr.Zero);
        if (top == IntPtr.Zero) return "";
        IntPtr deepest = top;
        while (true)
        {
            Point local = point;
            ScreenToClient(deepest, ref local);
            IntPtr child = ChildWindowFromPointEx(deepest, local, SkipInvisibleAndTransparent);
            if (child == IntPtr.Zero || child == deepest) break;
            deepest = child;
        }
        // Never click into a web page (it could press Send): the browser's render window is msedgewebview2.
        string atPoint = ProcessOf(WindowFromPoint(point));
        return atPoint == "msedgewebview2" ? atPoint : ProcessOf(deepest);
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
