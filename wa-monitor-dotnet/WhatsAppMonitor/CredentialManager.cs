using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text;

namespace WhatsAppMonitor;

/// <summary>
/// Reads plain-text passwords from the Windows Credential Manager (Generic credentials).
/// </summary>
[SupportedOSPlatform("windows")]
internal static class CredentialManager
{
    // ── Win32 types ─────────────────────────────────────────────────────────

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL
    {
        public uint Flags;
        public uint Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string? Comment;
        public long LastWritten;          // FILETIME (two DWORDs = 8 bytes)
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        [MarshalAs(UnmanagedType.LPWStr)] public string? TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string? UserName;
    }

    private const uint CRED_TYPE_GENERIC = 1;

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(
        string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);

    // ── public API ─────────────────────────────────────────────────────────

    /// <summary>
    /// Reads the credential blob for <paramref name="target"/> and returns it as a
    /// UTF-16 string (the encoding used by the Windows Credential Manager UI and
    /// <c>cmdkey /add</c>).
    /// Returns <c>null</c> when the credential does not exist or cannot be read.
    /// </summary>
    public static string? Read(string target)
    {
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out var ptr))
            return null;

        try
        {
            var cred = Marshal.PtrToStructure<CREDENTIAL>(ptr);
            if (cred.CredentialBlobSize == 0 || cred.CredentialBlob == IntPtr.Zero)
                return null;

            var blobBytes = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, blobBytes, 0, (int)cred.CredentialBlobSize);
            return Encoding.Unicode.GetString(blobBytes);
        }
        finally
        {
            CredFree(ptr);
        }
    }
}
