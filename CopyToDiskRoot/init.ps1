#!/usr/bin/env  pwsh

Write-Host "[        INIT] Initializing Linux" -ForegroundColor Yellow

using namespace "System"
using namespace "System.Diagnostics"
using namespace "System.IO"



Write-Host "[        INIT] Running PowerShell"
# Start-Process "pwsh" -Wait -PassThru -ArgumentList ""
Start-Process "setsid" -Wait -PassThru -ArgumentList "cttyhack pwsh"
