function Get-DellDriverPack {
    #Web Scraper. Not very flexible 
    param(
        $Model,
        $OS,
        $Destination
    )

    $Model = "OptiPlex-7090"
    $OS = "Windows-10"

    $page1 = Invoke-WebRequest 'https://www.dell.com/support/kbdoc/en-us/000109785/dell-command-deploy-driver-packs-for-optiplex-models' -UseBasicParsing
    $link1 = ($page1.Links | where { $_.href -like "*$Model*Windows10*" -or $_.href -like "*OptiPlex-7090*Windows-10*" }).href

    $page2 = Invoke-WebRequest $link1 -UseBasicParsing
    $DownloadLink = ($page2.links | where { $_.outerhtml -like "*Download Now*" }).href
    
    $fileName = Split-path $DownloadLink -Leaf
    $OutPath = Join-Path $Destination $fileName

    Start-BitsTransfer -Source $DownloadLink -Destination $OutPath 
}

function Get-OptiplexDrivers {
    $OptiModels = @(
        "OptiPlex 7020",
        "OptiPlex 7050",
        "OptiPlex 3060",
        "OptiPlex 7070",
        "OptiPlex 9010",
        "OptiPlex 7010",
        "OptiPlex 7040",
        "OptiPlex 3020M",
        "OptiPlex 3050",
        "OptiPlex 3070",
        "OptiPlex 5080",
        "OptiPlex 7070 Ultra",
        "OptiPlex 7090"
    )

    # https://downloads.dell.com/FOLDER08204374M/1/7090-win10-A05-HHCF6.CAB
    $userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
    wget "https://dl.dell.com/catalog/DriverPackCatalog.cab" -o .\DriverPackCatalog.cab -UserAgent $userAgent
    Expand .\DriverPackCatalog.cab -F:* .\DriverPackCatalog.xml | out-null

    $xml = [xml](Get-content ".\DriverPackCatalog.xml")
    $selected = $xml.DriverPackManifest.DriverPackage | select-object -Property ReleaseID,
    @{Label = "Name"; Expression = { ($_.Name.Display.'#cdata-section') } },
    @{Label = "Platform"; Expression = { ($_.SupportedSystems.Brand.Model.Name.Trim() | Select-Object -unique ) } },
    @{Label = "OS"; Expression = { ($_.SupportedOperatingSystems.OperatingSystem | % { $_.Display.'#cdata-section'.Trim() } | Select-Object -Unique ) } },
    @{Label = 'Size'; Expression = { "$([math]::Round($_.size/1MB, 2))MB" } }, DateTime, DellVersion,
    @{Label = 'Path'; Expression = { "https://downloads.dell.com/$($_.path)" } },
    @{Label = "SupportedOperatingSystems"; Expression = { ($_.SupportedOperatingSystems) } } 
    $items = foreach ($item in $OptiModels ) {
        $selected | where { ($_.Platform -eq $item -and $_.OS -like "Windows 10*") -or ($_.Platform -eq ($item -split " ")[1] -and $_.OS -like "Windows 10*") }
    }
    $items
    #$items | ogv -PassThru
}

function Get-LatitudeDrivers {
    $LatModels = @(
        "Latitude 5510",
        "Latitude 5520",
        "Latitude 3510",
        "Latitude 5500"

    )

    # https://downloads.dell.com/FOLDER08204374M/1/7090-win10-A05-HHCF6.CAB
    $userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
    wget "https://dl.dell.com/catalog/DriverPackCatalog.cab" -o .\DriverPackCatalog.cab -UserAgent $userAgent
    Expand .\DriverPackCatalog.cab -F:* .\DriverPackCatalog.xml | Out-Null

    $xml = [xml](Get-content ".\DriverPackCatalog.xml")
    $selected = $xml.DriverPackManifest.DriverPackage | select-object -Property ReleaseID,
    @{Label = "Name"; Expression = { ($_.Name.Display.'#cdata-section') } },
    @{Label = "Platform"; Expression = { ($_.SupportedSystems.Brand.Model.Name.Trim() | Select-Object -unique ) } },
    @{Label = "OS"; Expression = { ($_.SupportedOperatingSystems.OperatingSystem | % { $_.Display.'#cdata-section'.Trim() } | Select-Object -Unique ) } },
    @{Label = 'Size'; Expression = { "$([math]::Round($_.size/1MB, 2))MB" } }, DateTime, DellVersion,
    @{Label = 'Path'; Expression = { "https://downloads.dell.com/$($_.path)" } },
    @{Label = "SupportedOperatingSystems"; Expression = { ($_.SupportedOperatingSystems) } } 
    $items = foreach ($item in $LatModels) {
        $selected | where { ($_.Platform -eq $item -and $_.OS -like "Windows 10*") -or ($_.Platform -eq ($item -split " ")[1] -and $_.OS -like "Windows 10*") }
    }
    $items
}

function Get-WinPEDrivers {
    $userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
    wget "https://dl.dell.com/catalog/DriverPackCatalog.cab" -o .\DriverPackCatalog.cab -UserAgent $userAgent
    Expand .\DriverPackCatalog.cab -F:* .\DriverPackCatalog.xml | Out-Null

    $xml = [xml](Get-content ".\DriverPackCatalog.xml")
    $selected = $xml.DriverPackManifest.DriverPackage | select-object -Property ReleaseID,
    @{Label = "Name"; Expression = { ($_.Name.Display.'#cdata-section') } },
    @{Label = "Platform"; Expression = { ($_.SupportedSystems.Brand.Model.Name.Trim() | Select-Object -unique ) } },
    @{Label = "OS"; Expression = { ($_.SupportedOperatingSystems.OperatingSystem | % { $_.Display.'#cdata-section'.Trim() } | Select-Object -Unique ) } },
    @{Label = 'Size'; Expression = { "$([math]::Round($_.size/1MB, 2))MB" } }, DateTime, DellVersion,
    @{Label = 'Path'; Expression = { "https://downloads.dell.com/$($_.path)" } },
    @{Label = "SupportedOperatingSystems"; Expression = { ($_.SupportedOperatingSystems) } } 
    $selected | where { $_.OS -like "Windows PE 10.0*" }
}

function Get-DellBIOS {
    $Models = @(
        "OptiPlex 7020",
        "OptiPlex 7050",
        "OptiPlex 3060",
        "OptiPlex 7070",
        "OptiPlex 9010",
        "OptiPlex 7010",
        "OptiPlex 7040",
        "OptiPlex 3020M",
        "OptiPlex 3050",
        "OptiPlex 3070",
        "OptiPlex 5080",
        "OptiPlex 7070 Ultra",
        "OptiPlex 7090",
        "Latitude 5510",
        "Latitude 5520",
        "Latitude 3510",
        "Latitude 5500"
    )
    $Set = [System.Collections.Generic.HashSet[object]]::new()
    $userAgent = [Microsoft.PowerShell.Commands.PSUserAgent]::Chrome
    wget "https://dl.dell.com/catalog/CatalogPC.cab" -o .\CatalogPC.cab -UserAgent $userAgent
    Expand .\CatalogPC.cab -F:* .\CatalogPC.xml | out-null

    $BIOSxml = [xml](Get-content ".\CatalogPC.xml")
    $Manifest = $BIOSxml.Manifest.SoftwareComponent | Select-Object -Property ReleaseID,
    @{Label = "Type"; Expression = { ($_.Category.display.'#cdata-section') } },
    @{Label = "Name"; Expression = { ($_.name.display.'#cdata-section') } },
    @{Label = "Supported Systems"; Expression = { ($_.SupportedSystems.brand.model.display.'#cdata-section' | Select-Object -Unique) } },
    @{Label = 'Size'; Expression = { "$([math]::Round($_.size/1MB, 2))MB" } }, releaseDate, dellVersion,
    @{Label = 'Path'; Expression = { "https://downloads.dell.com/$($_.path)" } }
    $Manifest = $Manifest | where { $_.Type -eq "BIOS" }
    
    $list = foreach ($item in $Models) {
        $manifest | where {
            ($item -split " ")[1..2] -join "-" -in $_.'Supported Systems' -and $_.name -like "*$(($item -split " ")[0])*"
        }
    }
    $list | % { $set.add($_) | out-null }
    $set
}
 

function New-BitsDownloadList {
    param(
        $InputObject,
        $Destination
    )

    $Downloads = [System.Collections.ArrayList]::new() #@()
    $InputObject | foreach {
        $Downloads.Add(
                [PSCustomObject] @{
                Source      = $_
                Destination = Join-Path $Destination (Split-Path $_ -Leaf)
            }
        ) | Out-Null
    }
    return $Downloads
}

function Start-Download {
    [CmdletBinding()]
    param(
        $List
    )
    Begin {
        $Global:CompletedJobs = $null
        $Global:FailedJobs = $null
        $Progressbar = New-ProgressBar
        $List | Start-BitsTransfer -Asynchronous -RetryInterval 60
    }
    
    Process {
        Write-host "Waiting for jobs to Start..."
        Start-Sleep -Seconds 3
        while ((Get-BitsTransfer | Where-Object { $_.JobState -eq "Transferring" }).Count -gt 0) {     
            $totalbytes = 0;    
            $bytestransferred = 0; 
            $timeTaken = 0;    
            foreach ($job in (Get-BitsTransfer | Where-Object { $_.JobState -eq "Transferring" } | Sort-Object CreationTime)) {         
                $totalbytes += $job.BytesTotal;         
                $bytestransferred += $job.bytestransferred     
                if ($timeTaken -eq 0) { 
                    #Get the time of the oldest transfer aka the one that started first
                    $timeTaken = ((Get-Date) - $job.CreationTime).TotalMinutes 
                }
            }    
            #TimeRemaining = (TotalFileSize - BytesDownloaded) * TimeElapsed/BytesDownloaded
            if ($totalbytes -gt 0) {        
                [int]$timeLeft = ($totalBytes - $bytestransferred) * ($timeTaken / $bytestransferred)
                [int]$pctComplete = $(($bytestransferred * 100) / $totalbytes);     
                Write-ProgressBar -ProgressBar $Progressbar `
                    -Activity "Downloading Files $timeLeft" `
                    -PercentComplete $pctComplete `
                    -Status ((Get-BitsTransfer | select @{n = 'File'; e = { Split-path $_.filelist.remotename -Leaf } },
                        @{n = 'Percent Complete'; e = { "$([math]::round(($_.Bytestransferred * 100) / $_.bytestotal))%" } }) | ft -HideTableHeaders | out-string) `
                    -SecondsRemaining "$timeLeft" `
                    -CurrentOperation "Time remaning"
                #Write-Progress -Status "Transferring $bytestransferred of $totalbytes ($pctComplete%). $timeLeft minutes remaining." -Activity "Dowloading files" -PercentComplete $pctComplete  
            }
        
        }
        
    }
    
    End {
        $Global:SuccessfullJobs = (Get-BitsTransfer | Where-Object { $_.jobstate -eq 'Transferred' })
        $Global:FailedJobs = (Get-BitsTransfer | Where-Object { $_.jobstate -eq 'TransientError' })
        Close-ProgressBar $Progressbar

        $SuccessfullJobs | Complete-BitsTransfer
        if ($SuccessfullJobs -and !$FailedJobs) {
            Write-Host "All Jobs Completed Successfully"
        }
        else {
            Write-Warning "Jobs Completed with errors"
        }
    }
}