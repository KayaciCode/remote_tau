Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CredReader {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }
    [DllImport("Advapi32.dll", SetLastError = true, EntryPoint = "CredReadW", CharSet = CharSet.Unicode)]
    public static extern bool CredRead(string target, uint type, int reservedFlag, out IntPtr credentialPtr);
    public static string GetPass(string target) {
        IntPtr ptr;
        if (CredRead(target, 1, 0, out ptr)) {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            byte[] bytes = new byte[cred.CredentialBlobSize];
            Marshal.Copy(cred.CredentialBlob, bytes, 0, (int)cred.CredentialBlobSize);
            return Encoding.UTF8.GetString(bytes).TrimEnd('\0');
        }
        return "";
    }
}
'@

$tok = [CredReader]::GetPass('GitHub - https://api.github.com/KayaciCode')
if (-not $tok) {
    $tok = [CredReader]::GetPass('git:https://github.com')
}

if ($tok) {
    Write-Host "Token successfully retrieved! Pushing to GitHub..."
    git remote set-url origin "https://${tok}@github.com/KayaciCode/remote_tau.git"
    git push origin main
    Write-Host "GIT PUSH COMPLETED!"
} else {
    Write-Host "Token not found in Credential Manager."
}
