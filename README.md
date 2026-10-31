# InteropDotNet #

This fork adds .NET 10 support while retaining .NET Framework 2.0 support from
the [original project](https://github.com/AndreyAkinshin/InteropDotNet).

The library allows you to work with native libraries. Standard approach with the `DllImport` attribute may be inconvenient if you want to build AnyCPU assembly with MS.NET/Mono support. The `InteropRuntimeImplementer` class can generate implementation of interface with target signatures of native methods.

For example, let's create a native library (`NativeLib`) with the function `int sum(int a, int b) { return a + b; }` and build it in four configuration (Windows/Unix, x86/x64):

	x86/NativeLib.dll
	x86/libNativeLib.so
	x64/NativeLib.dll
	x64/libNativeLib.so

Now we can write the following code:

	public interface INative
	{
	    [RuntimeDllImport("NativeLib", CallingConvention = CallingConvention.Cdecl, EntryPoint = "sum")]
	    int Sum(int a, int b);
	}
	
	class Program
	{
	    static void Main()
	    {
	        var native = InteropRuntimeImplementer.CreateInstance<INative>();
	        Console.WriteLine("2 + 3 = " + native.Sum(2, 3));
	    }
	}

In the program, we declared interface `INative` with signatures of the target native methods. Each signature should be marked with the `RuntimeDllImport` attribute with name of a native library and other options. The instance of `InteropRuntimeImplementer` helped us to create instance of the `INative` interface on the fly. The implementation of the `sum` method call corresponding native method from library that correspond to current architecture and OS. The `InteropRuntimeImplementer` generates the following code:

    namespace InteropRuntimeImplementer.NativeInstance
    {
      [UnmanagedFunctionPointer(CallingConvention.Cdecl, BestFitMapping = false, CharSet = (CharSet) 0, SetLastError = false, ThrowOnUnmappableChar = false)]
      [StructLayout(LayoutKind.Auto, CharSet = CharSet.Auto)]
      public delegate int SumDelegate(int a, int b);

      public class NativeImplementation : INative
      {
        private SumDelegate SumField;

        public NativeImplementation(LibraryLoader loader)
        {
          IntPtr dllHandle = loader.LoadLibrary("NativeLib", (string) null);
          this.SumField = (SumDelegate) Marshal.GetDelegateForFunctionPointer(loader.GetProcAddress(dllHandle, "sum"), typeof (SumDelegate));
        }

        public int Sum(int a, int b)
        {
          return this.SumField(a, b);
        }
      }
    } 


As a result, we received a single .NET cross-platform AnyCPU-program with calls of native methods because of the `LibraryLoader` class loaded handles for specific user environment.

## Building and running

The library and managed sample target both .NET Framework 2.0 (`net20`) and
.NET 10 (`net10.0`). Install the .NET 10 SDK, then run:

```sh
dotnet build InteropDotNet.sln -c Release
dotnet run --project Sample/ManagedApplication -c Release -f net10.0
dotnet pack InteropDotNet/InteropDotNet.csproj -c Release
```

The SDK restores .NET Framework reference assemblies from NuGet when needed.
The package includes separate assemblies for both frameworks.

On .NET 10, native libraries are loaded using the runtime's `NativeLibrary` API.
Place them in a directory named after the process architecture (`x86`, `x64`,
`arm`, or `arm64`) beside the managed assembly or in the application or working
directory. Library names use `.dll` on Windows, `lib*.so` on Linux, and
`lib*.dylib` on macOS. Supply native binaries for your OS and architecture; the
bundled sample binaries are for Windows and Linux on x86/x64.
Runtime interface generation requires dynamic code and is not supported by Native AOT.

### Native interop smoke tests

The smoke tests check generated calls, library caching, missing libraries and
exports, unloading, and reloading on .NET 10. Run the full verification with
PowerShell 7:

```powershell
./eng/verify.ps1
```

The script builds both frameworks, compiles a fresh native fixture for the
current architecture, runs the smoke tests and sample, and verifies the NuGet
package contents. Install Visual C++ build tools on Windows or a C compiler
available as `cc` on Linux/macOS. GitHub Actions runs this script on all three
operating systems. The .NET Framework 2.0 target is built but requires its
legacy runtime to execute.

The bundled Windows DLL may require an older Visual C++ runtime. The verification
script rebuilds it without a C runtime dependency and places the fresh binary in
the sample output directory, so the sample can then run with `--no-build`.

## NuGet

The [upstream NuGet package](https://www.nuget.org/packages/InteropDotNet/) predates
this fork's .NET 10 support. Build from source or use `dotnet pack` to create a
local package containing both targets. This change does not publish a package.
