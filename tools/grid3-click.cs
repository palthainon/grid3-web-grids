// grid3-click.exe: one left click at the cursor, only when the cursor is over a Grid 3 window.
// Grid 3 has uiAccess, so Windows drops clicks from normal processes. This exe runs elevated from a scheduled
// task (tools\install-grid3-click.ps1), so its click reaches Grid 3. Agents trigger it with tools\grid3-click.ps1.
// It writes grid3-click.log next to itself (in %ProgramData%\grid3-web-grids).
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

static class Grid3Click
{
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct MouseInput { public int Dx, Dy, Data, Flags, Time; public IntPtr Extra; }
    [StructLayout(LayoutKind.Sequential)] struct Input { public int Type; public MouseInput Mouse; }

    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint count, Input[] inputs, int size);

    const int LeftDown = 2, LeftUp = 4;

    static int Main()
    {
        string log = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "grid3-web-grids", "grid3-click.log");
        Directory.CreateDirectory(Path.GetDirectoryName(log));
        string stamp = DateTime.Now.ToString("s");
        SetProcessDPIAware();
        Point point;
        GetCursorPos(out point);
        uint pid;
        GetWindowThreadProcessId(WindowFromPoint(point), out pid);
        string owner = "";
        try { owner = Process.GetProcessById((int)pid).ProcessName; } catch (ArgumentException) { }
        if (owner != "Grid 3")
        {
            File.AppendAllText(log, stamp + " refused: cursor " + point.X + "," + point.Y + " is over '" + owner + "', not Grid 3\r\n");
            return 2;
        }
        var inputs = new Input[2];
        inputs[0].Mouse.Flags = LeftDown;
        inputs[1].Mouse.Flags = LeftUp;
        uint sent = SendInput(2, inputs, Marshal.SizeOf(typeof(Input)));
        File.AppendAllText(log, stamp + " clicked Grid 3 at " + point.X + "," + point.Y + " (sent " + sent + " of 2)\r\n");
        return sent == 2 ? 0 : 1;
    }
}
