Get-Content .env | Where-Object { $_ -match '^([^#][^=]+)=(.*)$' } | ForEach-Object { 
    [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process") 
}