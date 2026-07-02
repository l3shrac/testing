Add-Type @'
using System;
using System.Runtime.InteropServices;

namespace NtdllBypass {
    public class NtdllFunctions {
        [DllImport("ntdll.dll")]
        public static extern int ZwReadVirtualMemory(long Handle, long BaseAddress, IntPtr Buffer, int NumberOfBytesToRead, out int BytesRead);
    }
}
'@ -ErrorAction Stop

[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, uint processId);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int nSize, out int lpNumberOfBytesRead);

# Define the required access rights for memory read
const uint PROCESS_VM_READ = 0x0010;

function Read-Virtual {
    param(
        [IntPtr]$handle,
        [IntPtr]$address,
        [int]$bytes = 64
    )

    if (!$handle) {
        throw "Invalid handle"
    }

    $buffer = New-Object byte[] $bytes
    $BytesRead = 0

    try {
        $success = ReadProcessMemory($handle, $address, $buffer, $bytes, [ref]$BytesRead)

        if (!$success) {
            Write-Warning "Failed to read memory. Error code: $LASTEXITCODE"
            return ''
        }

        # Validate BytesRead before attempting to decode
        if ($BytesRead -le 0) {
            Write-Warning "No data read from memory address."
            return ''
        }

        try {
            return [System.Text.Encoding.UTF8].GetString($buffer, 0, $BytesRead)
        } catch {
            Write-Warning "Invalid UTF-8 data encountered. Bytes read: $BytesRead"
            return $buffer
        }
    } finally {
        Marshal.FreeHGlobal(Marshal.AllocHGlobal($bytes))
    }
}

# Example usage
try {
    # Specify the target process name
    $processName = "example"

    # Get the process handle with memory-read permissions
    $processId = (Get-Process -Name $processName -ErrorAction Stop).Id
    $handle = OpenProcess(PROCESS_VM_READ, $false, $processId)

    if (!$handle) {
        throw "Failed to open process. Error code: $LASTEXITCODE"
    }

    $results = 0..4 | ForEach-Object {
        $addr = IntPtr.Add($processHandle, 0x4A2 + $_ * 0x1C0)
        Read-Virtual -handle $addr -bytes 64
    }

    # Filter results where the string starts with "MSI\i" and handle null values
    $results | Where-Object { $_ -ne $null -and $_.StartsWith("MSI\i") }
} catch {
    Write-Error "An error occurred: $_"
} finally {
    if ($handle) {
        [Marshal]::FreeHGlobal($handle)
    }
}
