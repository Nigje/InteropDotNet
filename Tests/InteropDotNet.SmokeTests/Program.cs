using System;
using System.Runtime.InteropServices;
using InteropDotNet;

public interface INative
{
    [RuntimeDllImport("NativeLib", CallingConvention = CallingConvention.Cdecl, EntryPoint = "sum")]
    int Sum(int a, int b);
}

internal static class Program
{
    private static void Main()
    {
        var native = InteropRuntimeImplementer.CreateInstance<INative>();
        Check(native.Sum(2, 3) == 5, "Native addition failed.");
        Check(native.Sum(-9, 4) == -5, "Native addition with negative arguments failed.");

        var loader = LibraryLoader.Instance;
        Check(loader.IsLibraryLoaded("NativeLib"), "Loaded library was not cached.");
        var handle = loader.LoadLibrary("NativeLib");
        Check(handle == loader.LoadLibrary("NativeLib"), "Repeated loads returned different handles.");
        Expect<EntryPointNotFoundException>(() => loader.GetProcAddress(handle, "missing_export"));
        Expect<DllNotFoundException>(() => loader.LoadLibrary("InteropDotNet_MissingLibrary"));

        // No generated delegates may be called after the library is freed.
        Check(loader.FreeLibrary("NativeLib"), "FreeLibrary failed.");
        Check(!loader.IsLibraryLoaded("NativeLib"), "Freed library remained cached.");
        Check(!loader.FreeLibrary("NativeLib"), "Freeing an unloaded library should return false.");

        native = InteropRuntimeImplementer.CreateInstance<INative>();
        Check(native.Sum(10, 20) == 30, "Native call after reloading failed.");
        Check(loader.FreeLibrary("NativeLib"), "Final cleanup failed.");
        Console.WriteLine("All .NET 10 native interop smoke tests passed.");
    }

    private static void Check(bool condition, string message)
    {
        if (!condition)
            throw new Exception(message);
    }

    private static void Expect<T>(Action action) where T : Exception
    {
        try
        {
            action();
        }
        catch (T)
        {
            return;
        }
        throw new Exception("Expected " + typeof(T).Name);
    }
}
