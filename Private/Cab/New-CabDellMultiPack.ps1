function New-CabDellMultiPack {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$ExpandedDriverPath,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$PublishPath,

        [ValidateSet('Bluetooth','Camera','Display','HDC','HIDClass','Keyboard','Media','Monitor','Mouse','Net','SCSIAdapter','SmartCardReader','System','USBDevice')]
        [string]$DriverClass,

        [switch]$MakePnp,
        [switch]$SelectPnp
    )

    #======================================================================================
    #   Validate Admin Rights
    #======================================================================================
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    If (!( $isAdmin )) {
        Write-Host "Checking User Account Control settings ..." -ForegroundColor Green
        if ((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System).EnableLUA -eq 0) {
            #UAC Disabled
            Write-Host '========================================================================================' -ForegroundColor DarkGray
            Write-Host "User Account Control is Disabled ... " -ForegroundColor Green
            Write-Host "You will need to correct your UAC Settings ..." -ForegroundColor Green
            Write-Host "Try running this script in an Elevated PowerShell session ... Exiting" -ForegroundColor Green
            Write-Host '========================================================================================' -ForegroundColor DarkGray
            Start-Sleep -s 10
            Exit 0
        } else {
            #UAC Enabled
            Write-Host "UAC is Enabled" -ForegroundColor Green
            Start-Sleep -s 3
            if ($Silent) {
                Write-Host "-- Restarting as Administrator (Silent)" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
                Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Silent" -Verb RunAs -Wait
            } elseif($Restart) {
                Write-Host "-- Restarting as Administrator (Restart)" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
                Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Restart" -Verb RunAs -Wait
            } else {
                Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Start-Sleep -Seconds 1
                Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -Wait
            }
            Exit 0
        }
    } else {
        #Write-Host '========================================================================================' -ForegroundColor DarkGray
        #Write-Host "-- Running with Elevated Permissions ..." -ForegroundColor Cyan ; Start-Sleep -Seconds 1
        #Write-Host '========================================================================================' -ForegroundColor DarkGray
    }
    #===================================================================================================
    #   Test-ExpandedDriverPath
    #===================================================================================================
    Test-ExpandedDriverPath $ExpandedDriverPath
    #===================================================================================================
    #   Test-PublishPath
    #===================================================================================================
    #Test-PublishPath $PublishPath
    #===================================================================================================
    #   Get-DirectoryName
    #===================================================================================================
    $DirectoryName = Get-DirectoryName $ExpandedDriverPath
    #===================================================================================================
    #   Get-ParentDirectoryFullName
    #===================================================================================================
    #$ParentDirectoryFullName = Get-ParentDirectoryFullName $ExpandedDriverPath
    #===================================================================================================
    #   New-OSDDriverCabFile
    #===================================================================================================
    $OSDDriverCabFile = "$PublishPath\$DirectoryName.cab"
    if (Test-Path "$OSDDriverCabFile") {
        #Write-Verbose "Build: $OSDDriverCabFile ... exists!" -Verbose
    } else {
        #===================================================================================================
        #   MakePnp
        #===================================================================================================
        if ($MakePnp.IsPresent) {
            if ($DriverClass) {
                Write-Verbose "ExpandedDriverPath: $ExpandedDriverPath $DriverClass" -Verbose
                if ($SelectPnp.IsPresent) {
                    Save-OSDDriverPnp -ExpandedDriverPath $ExpandedDriverPath -OSDPnpClass $DriverClass -GridView
                } else {
                    Save-OSDDriverPnp -ExpandedDriverPath $ExpandedDriverPath -OSDPnpClass $DriverClass
                }
                
            } else {
                Write-Verbose "ExpandedDriverPath: $ExpandedDriverPath" -Verbose
                if ($SelectPnp.IsPresent) {
                    Save-OSDDriverPnp -ExpandedDriverPath $ExpandedDriverPath -GridView
                } else {
                    Save-OSDDriverPnp -ExpandedDriverPath $ExpandedDriverPath
                }
            }
        }
        #Write-Warning "Build: $OSDDriverCabFile ... This may take a while"
        New-MultiPackCabFile -ExpandedDriverPath "$ExpandedDriverPath" -PublishPath $PublishPath
    }
}