#if NET10_0_OR_GREATER
using System;
using System.Runtime.InteropServices;

namespace InteropDotNet
{
    internal class NativeLibraryLoaderLogic : ILibraryLoaderLogic
    {
        public IntPtr LoadLibrary(string fileName)
        {
            IntPtr handle;
            return NativeLibrary.TryLoad(fileName, out handle) ? handle : IntPtr.Zero;
        }

        public bool FreeLibrary(IntPtr libraryHandle)
        {
            NativeLibrary.Free(libraryHandle);
            return true;
        }

        public IntPtr GetProcAddress(IntPtr libraryHandle, string functionName)
        {
            return NativeLibrary.GetExport(libraryHandle, functionName);
        }

        public string FixUpLibraryName(string fileName)
        {
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                return new WindowsLibraryLoaderLogic().FixUpLibraryName(fileName);
            if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
            {
                if (string.IsNullOrEmpty(fileName))
                    return fileName;
                if (!fileName.EndsWith(".dylib", StringComparison.OrdinalIgnoreCase))
                    fileName += ".dylib";
                if (!fileName.StartsWith("lib", StringComparison.OrdinalIgnoreCase))
                    fileName = "lib" + fileName;
                return fileName;
            }
            return new UnixLibraryLoaderLogic().FixUpLibraryName(fileName);
        }
    }
}
#endif
