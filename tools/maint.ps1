# Sends commands to the local blakserv's maintenance port and prints the replies.
# Commands end with CR, not LF (blakserv/maintenance.c).
#
#   powershell -File tools\maint.ps1 "show status" ["who" ...]
#   $env:MAINT_PORT = 9998   # another server; the default is Shards' 9999
#
# Careful with "save game", "reload system" and "shutdown" against a server you care about.
param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Commands)

$port = if ($env:MAINT_PORT) { [int]$env:MAINT_PORT } else { 9999 }
$client = New-Object System.Net.Sockets.TcpClient
try {
    $client.Connect('127.0.0.1', $port)
} catch {
    Write-Error "maintenance port ${port}: $($_.Exception.Message)"
    exit 1
}
$stream = $client.GetStream()
$latin1 = [System.Text.Encoding]::GetEncoding(28591)

function Read-Available([int]$waitMs) {
    Start-Sleep -Milliseconds $waitMs
    $sb = New-Object System.Text.StringBuilder
    $buf = New-Object byte[] 65536
    while ($stream.DataAvailable) {
        $n = $stream.Read($buf, 0, $buf.Length)
        [void]$sb.Append($latin1.GetString($buf, 0, $n))
        Start-Sleep -Milliseconds 50
    }
    return $sb.ToString().Replace("`r", '')
}

[void](Read-Available 300)   # banner
foreach ($cmd in $Commands) {
    $bytes = $latin1.GetBytes($cmd + "`r")
    $stream.Write($bytes, 0, $bytes.Length)
    Write-Output "> $cmd"
    Write-Output (Read-Available 700)
}
$client.Close()
