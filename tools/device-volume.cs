// device-volume.exe: change the volume of one named playback device, without a window.
// Grid 3's own device volume cells (ComputerControl.DeviceVolume) change only the Windows default device.
// Usage: device-volume.exe "<part of the device name>" <+10 | -10 | mute | list>
// The name match ignores case and repeated spaces ("USB AUDIO CODEC" matches "USB AUDIO  CODEC").
// Build with the C# compiler that ships with Windows: tools\install-device-volume.ps1
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

static class DeviceVolume
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }

    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    }

    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceCollection
    {
        int GetCount(out int count);
        int Item(int index, out IMMDevice device);
    }

    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object endpoint);
        int OpenPropertyStore(int access, out IPropertyStore store);
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore
    {
        int GetCount(out int count);
        int GetAt(int index, out PropertyKey key);
        int GetValue(ref PropertyKey key, out PropVariant value);
    }

    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume
    {
        int RegisterControlChangeNotify(IntPtr notify);
        int UnregisterControlChangeNotify(IntPtr notify);
        int GetChannelCount(out int count);
        int SetMasterVolumeLevel(float levelDb, ref Guid context);
        int SetMasterVolumeLevelScalar(float level, ref Guid context);
        int GetMasterVolumeLevel(out float levelDb);
        int GetMasterVolumeLevelScalar(out float level);
        int SetChannelVolumeLevel(int channel, float levelDb, ref Guid context);
        int SetChannelVolumeLevelScalar(int channel, float level, ref Guid context);
        int GetChannelVolumeLevel(int channel, out float levelDb);
        int GetChannelVolumeLevelScalar(int channel, out float level);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }

    [StructLayout(LayoutKind.Sequential)] struct PropertyKey { public Guid fmtid; public int pid; }
    [StructLayout(LayoutKind.Sequential)] struct PropVariant { public short vt; short r1, r2, r3; public IntPtr p; IntPtr p2; }

    const int RenderFlow = 0, ActiveState = 1, ClsCtxAll = 23;

    static string Normalize(string text) { return Regex.Replace(text, @"\s+", " ").Trim(); }

    static string FriendlyName(IMMDevice device)
    {
        IPropertyStore store;
        Marshal.ThrowExceptionForHR(device.OpenPropertyStore(0, out store));
        var key = new PropertyKey { fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), pid = 14 };
        PropVariant value;
        Marshal.ThrowExceptionForHR(store.GetValue(ref key, out value));
        return value.vt == 31 ? Marshal.PtrToStringUni(value.p) : "";
    }

    static int Main(string[] args)
    {
        string log = Path.Combine(Path.GetDirectoryName(typeof(DeviceVolume).Assembly.Location), "device-volume.log");
        try
        {
            if (args.Length != 2) throw new ArgumentException("Usage: device-volume.exe \"<device name>\" <+10|-10|mute|list>");
            string want = Normalize(args[0]).ToLowerInvariant();
            var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
            IMMDeviceCollection devices;
            Marshal.ThrowExceptionForHR(enumerator.EnumAudioEndpoints(RenderFlow, ActiveState, out devices));
            int count;
            devices.GetCount(out count);
            string seen = "";
            for (int i = 0; i < count; i++)
            {
                IMMDevice device;
                devices.Item(i, out device);
                string name = FriendlyName(device);
                seen += (seen.Length > 0 ? "; " : "") + name;
                if (args[1] == "list" || !Normalize(name).ToLowerInvariant().Contains(want)) continue;
                var iid = typeof(IAudioEndpointVolume).GUID;
                object endpoint;
                Marshal.ThrowExceptionForHR(device.Activate(ref iid, ClsCtxAll, IntPtr.Zero, out endpoint));
                var volume = (IAudioEndpointVolume)endpoint;
                var context = Guid.Empty;
                if (args[1] == "mute")
                {
                    bool muted;
                    volume.GetMute(out muted);
                    volume.SetMute(!muted, ref context);
                    File.AppendAllText(log, DateTime.Now.ToString("s") + " " + name + " mute " + !muted + "\r\n");
                    return 0;
                }
                float level;
                volume.GetMasterVolumeLevelScalar(out level);
                // Same 10-point steps as Grid 3's own device volume cells. A step up also unmutes.
                float next = Math.Max(0f, Math.Min(1f, (float)Math.Round(level * 100 + int.Parse(args[1])) / 100f));
                volume.SetMasterVolumeLevelScalar(next, ref context);
                if (next > level) volume.SetMute(false, ref context);
                File.AppendAllText(log, DateTime.Now.ToString("s") + " " + name + " " + Math.Round(level * 100) + " -> " + Math.Round(next * 100) + "\r\n");
                return 0;
            }
            File.AppendAllText(log, DateTime.Now.ToString("s") + (args[1] == "list" ? " devices: " : " no device matches '" + args[0] + "'. Devices: ") + seen + "\r\n");
            return args[1] == "list" ? 0 : 2;
        }
        catch (Exception e)
        {
            File.AppendAllText(log, DateTime.Now.ToString("s") + " error: " + e.Message + "\r\n");
            return 1;
        }
    }
}
