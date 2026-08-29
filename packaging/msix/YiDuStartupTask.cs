using System;
using System.Diagnostics;
using System.IO;
using Windows.ApplicationModel;

internal static class YiDuStartupTask
{
    private const string TaskId = "YiDuStartup";
    private const int Disabled = 10;
    private const int DisabledByUser = 11;
    private const int DisabledByPolicy = 12;
    private const int Unavailable = 20;
    private const int Failed = 21;

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length == 0)
            return LaunchYiDu();
        if (args[0] == "--self-test")
            return File.Exists(Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "YiDu.exe"))) ? 0 : Failed;

        try
        {
            StartupTask task = null;
            foreach (StartupTask candidate in StartupTask.GetForCurrentPackageAsync().AsTask().GetAwaiter().GetResult())
            {
                if (candidate.TaskId == TaskId)
                {
                    task = candidate;
                    break;
                }
            }
            if (task == null)
                return Unavailable;
            if (args[0] == "--enable")
            {
                if (task.State != StartupTaskState.Enabled)
                    task.RequestEnableAsync().AsTask().GetAwaiter().GetResult();
                return StateExitCode(task.State);
            }
            if (args[0] == "--disable")
            {
                if (task.State == StartupTaskState.Enabled)
                    task.Disable();
                return StateExitCode(task.State);
            }
            if (args[0] == "--status")
                return StateExitCode(task.State);
            return Failed;
        }
        catch
        {
            return Unavailable;
        }
    }

    private static int StateExitCode(StartupTaskState state)
    {
        switch (state)
        {
            case StartupTaskState.Enabled:
                return 0;
            case StartupTaskState.Disabled:
                return Disabled;
            case StartupTaskState.DisabledByUser:
                return DisabledByUser;
            case StartupTaskState.DisabledByPolicy:
                return DisabledByPolicy;
            default:
                return Failed;
        }
    }

    private static int LaunchYiDu()
    {
        try
        {
            string executable = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "YiDu.exe"));
            Process.Start(new ProcessStartInfo(executable, "--startup") { UseShellExecute = false });
            return 0;
        }
        catch
        {
            return Failed;
        }
    }
}
