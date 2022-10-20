
$Bios = Get-DellBIOS
$files = New-BitsDownloadList $OptiDrivers -Destination 'D:\Dell BIOS\'


$workers = foreach ($f in $files) { 

    $wc = New-Object System.Net.WebClient

    Write-Output $wc.DownloadFileTaskAsync($f.Source, $f.Destination)

}


$result = Start-BitsTransfer -Source $Files.Source -Destination $Files.Destination -TransferType Download -Asynchronous
$downloadsFinished = $false;
While ($downloadsFinished -ne $true) {
    sleep 1
    $jobstate = $result.JobState;
    if ($jobstate.ToString() -eq 'Transferred') { $downloadsFinished = $true }
    $percentComplete = ($result.BytesTransferred / $result.BytesTotal) * 100
    Write-Progress -Activity ('Downloading' + $result.FilesTotal + ' files') -PercentComplete $percentComplete 
}

$Drivers = New-BitsDownloadList (Get-OptiplexDirvers) -Destination 'D:\Dell BIOS\OptiPlex Drivers'
$Bios = New-BitsDownloadList (Get-DellBIOS) -Destination 'D:\Dell BIOS'


function Format-RandomCase {
    <#
.SYNOPSIS
    Formats a string character by character randomly into upper or lower case.
.DESCRIPTION
    Formats a string character by character randomly into upper or lower case.
.PARAMETER String
    A [string[]] that you want formatted randomly into upper or lower case
.PARAMETER IncludeInput
    Switch that will display input parameters in the output
.EXAMPLE
    Format-RandomCase -String 'HELLO WORLD IT IS ME!'
    Example return
    HelLo worlD It is me!
.EXAMPLE
    Format-RandomCase -String HELLO, WORLD, IT, IS, ME -IncludeInput
    Example return
    Original Return
    -------- ------
    HELLO    hELLo
    WORLD    wORLd
    IT       It
    IS       is
    ME       ME
.OUTPUTS
[string[]]
#>

    # todo Change += to System.Collections.Arraylist

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    param (
        [parameter(ValueFromPipeline)]
        [string[]] $String,

        [switch] $IncludeInput
    )

    begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"
    }

    process {
        foreach ($CurrentString in $String) {
            $CharArray = [char[]] $CurrentString
            $CharArray | ForEach-Object -Begin { $ReturnVal = '' } -Process {
                $Random = 0, 1 | Get-Random
                if ($Random -eq 0) {
                    $ReturnVal += ([string] $_).ToLower()
                }
                else {
                    $ReturnVal += ([string] $_).ToUpper()
                }
            }
            if ($IncludeInput) {
                New-Object -TypeName psobject -Property ([ordered] @{
                        Original = $CurrentString
                        Return   = $ReturnVal
                    })
            }
            else {
                Write-Output -InputObject $ReturnVal
            }
        }
    }

    end {
        Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }

}



function Invoke-Async{
    param(
    #The data group to process, such as server names.
    [parameter(Mandatory=$true,ValueFromPipeLine=$true)]
    [object[]]$Set,
    #The parameter name that the set belongs to, such as Computername.
    [parameter(Mandatory=$true)]
    [string] $SetParam,
    #The Cmdlet for Function you'd like to process with.
    [parameter(Mandatory=$true, ParameterSetName='cmdlet')]
    [string]$Cmdlet,
    #The ScriptBlock you'd like to process with
    [parameter(Mandatory=$true, ParameterSetName='ScriptBlock')]
    [scriptblock]$ScriptBlock,
    #any aditional parameters to be forwarded to the cmdlet/function/scriptblock
    [hashtable]$Params,
    #number of jobs to spin up, default being 10.
    [int]$ThreadCount=10,
    #return performance data
    [switch]$Measure
    )
    Begin
    {
    
        $Threads = @()
        $Length = $JobsLeft = $Set.Length
    
        $Count = 0
        if($Length -lt $ThreadCount){$ThreadCount=$Length}
        $timer = @(1..$ThreadCount  | ForEach-Object{$null})
        $Jobs = @(1..$ThreadCount  | ForEach-Object{$null})
    
        If($PSCmdlet.ParameterSetName -eq 'cmdlet')
        {
            $CmdType = (Get-Command $Cmdlet).CommandType
            if($CmdType -eq 'Alias')
            {
                $CmdType = (Get-Command (Get-Command $Cmdlet).ResolvedCommandName).CommandType
            }
    
            If($CmdType -eq 'Function')
            {
                $ScriptBlock = (Get-Item Function:\$Cmdlet).ScriptBlock
                1..$ThreadCount | ForEach-Object{ $Threads += [powershell]::Create().AddScript($ScriptBlock)}
            }
            ElseIf($CmdType -eq "Cmdlet")
            {
                1..$ThreadCount  | ForEach-Object{ $Threads += [powershell]::Create().AddCommand($Cmdlet)}
            }
        }
        Else
        {
            1..$ThreadCount | ForEach-Object{ $Threads += [powershell]::Create().AddScript($ScriptBlock)}
        }
    
        If($Params){$Threads | ForEach-Object{$_.AddParameters($Params) | Out-Null}}
    
    }
    Process
    {
        while($JobsLeft)
        {
            for($idx = 0; $idx -le ($ThreadCount-1) ; $idx++)
            {
                $SetParamObj = $Threads[$idx].Commands.Commands[0].Parameters| Where-Object {$_.Name -eq $SetParam}
    
                If($Jobs[$idx].IsCompleted) #job ran ok, clear it out
                {
                    $result = $null
                    if($threads[$idx].InvocationStateInfo.State -eq "Failed")
                    {
                        $result  = $Threads[$idx].InvocationStateInfo.Reason
                        Write-Error "Set Item: $($SetParamObj.Value) Exception: $result"
                    }
                    else
                    {
                        $result = $Threads[$idx].EndInvoke($Jobs[$idx])
                    }
                    $ts = (New-TimeSpan -Start $timer[$idx] -End (Get-Date))
                    if($Measure)
                    {
                        new-object psobject -Property @{
                            TimeSpan = $ts
                            Output = $result
                            SetItem = $SetParamObj.Value}
                    }
                    else
                    {
                        $result
    
                        if ($result.Orphaned -eq $true)
                        {
                            $script:totalAzureADOrphanedKeys += 1
                        }
                    }
                    $Jobs[$idx] = $null
                    $JobsLeft-- #one less left
                    write-verbose "Completed: $($SetParamObj.Value) in $ts"
                    Update-GetAzureADWHfBKeysProgress
                    write-progress -Activity "Processing Batch" -Status "$JobsLeft jobs left" -PercentComplete (($length-$jobsleft)/$length*100) -Id 2 -ParentId 1
                }
                If(($Count -lt $Length) -and ($Jobs[$idx] -eq $null)) #add job if there is more to process
                {
                    write-verbose "starting: $($Set[$Count])"
                    $timer[$idx] = get-date
                    $Threads[$idx].Commands.Commands[0].Parameters.Remove($SetParamObj) | Out-Null #check for success?
                    $Threads[$idx].AddParameter($SetParam,$Set[$Count]) | Out-Null
                    $Jobs[$idx] = $Threads[$idx].BeginInvoke()
                    $Count++
                }
            }
    
        }
    }
    End
    {
        $Threads | ForEach-Object{$_.runspace.close();$_.Dispose()}
    }
    }

$pc = 0
$t = 300
$ProgressBar = New-ProgressBar
while ($pc -lt $t) {
    $pc++
    sleep -Milliseconds 2
    Write-ProgressBar -ProgressBar $Progressbar `
    -Activity "Prettyin up Powershell $pc" `
    -PercentComplete $pc `
    -Status "Prettyin" `
    -SecondsRemaining ($pc / $t * 100) `
    -CurrentOperation "Progressifyin"
}
if ($pc -eq $t) {Close-ProgressBar $ProgressBar}

while (1) {
    Add-Type -AssemblyName System.Windows.Forms
    $X = [System.Windows.Forms.Cursor]::Position.X
    $Y = [System.Windows.Forms.Cursor]::Position.Y
    Write-host "X: $X | Y: $Y`r" -NoNewline
    Set-Window -X $x -Y $y -ProcessName $prox.id
    }



    function Show-WaitDialog {
        <#
            .SYNOPSIS
                Shows a wait Dialog
            
            .DESCRIPTION
                Shows a wait dialog as foreground window.
                Must be closed manually!
            
            .PARAMETER Title
                Dialog Title
            
            .PARAMETER Message
                Dialog Message
            
            .PARAMETER CloseMe
                Closes the Dialog
            
            .EXAMPLE
                PS C:\> Show-Wait -Title "Mytitle" -Message "Please wait for the fucntion to finish..."
            
            .NOTES
                0.0.1	20.02.2017	CER	Description
        #>
            
            [CmdletBinding()]
            param
            (
            [string]$Title = "Working...",
            [Parameter(ValueFromRemainingArguments = $true)][string]$Message = "Please Wait...",
            [switch]$CloseMe
            )
            
$strSB = @'
param($Title,$Message)
# Benötigte Assemblies laden
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms.VisualStyles')

# Progress Form erstellen
$ProgressForm = New-Object System.Windows.Forms.Form
$ProgressForm.Text = $Title
$ProgressForm.Width = 350
$ProgressForm.Height = 200
$ProgressForm.MaximizeBox = $False
$ProgressForm.MinimizeBox = $False
$ProgressForm.ControlBox = $False
$ProgressForm.ShowIcon = $False
$ProgressForm.StartPosition = 1
$ProgressForm.Visible = $False
$ProgressForm.FormBorderStyle = 'FixedDialog'
#$ProgressForm.WindowState = "Normal"

# Textfeld erzeugen
$InText = New-Object System.Windows.Forms.Label
$InText.Text = $Message
$InText.Location = '18,26'
$InText.Size = New-Object System.Drawing.Size(330, 38)

# Progressbar erzeugen
$progressBar1 = New-Object System.Windows.Forms.ProgressBar
$ProgressBar1.Name = 'LoadingBar'
$ProgressBar1.Style = 'Marquee'
$ProgressBar1.Location = '17,101'
$ProgressBar1.Size = '300,18'
$ProgressBar1.MarqueeAnimationSpeed = 40

# Textfeld in die Form einfügen
$ProgressForm.Controls.Add($InText)

# Progressbar in die Form einfügen
$ProgressForm.Controls.Add($ProgressBar1)

# Speichern der Form in die Hashtable
$sharedData.Form = $ProgressForm

$ProgressForm.TopMost = $true
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run($ProgressForm)
$ProgressForm.TopMost = $true
#[System.Windows.Forms.Application]::DoEvents()
    
'@
            $objSB = [Scriptblock]::Create($strSB)
            if (-not $closeMe.Ispresent) {
                # Hashtable für Datenaustausch zwischen den Threads
                $script:sharedData = [HashTable]::Synchronized(@{
                })
                $Script:sharedData.Form = $Null
                # Runspace für die Progress Form mit der Hashtable zum synchronisieren vorbereiten
                $newRunspace = [RunSpaceFactory]::CreateRunspace()
                $newRunspace.ApartmentState = 'STA'
                $newRunspace.ThreadOptions = 'ReuseThread'
                $null = $newRunspace.Open()
                $newRunspace.SessionStateProxy.setVariable('sharedData', $sharedData)
                # Thread für die Progress Form (eine eigene asynchrone Powershell)
                # mit dem vorbereiteten Runspace starten und die Function 'ShowProgressForm' als Script übergeben
                $script:PS = [PowerShell]::Create()
                $PS.Runspace = $newRunspace
                #$Scriptcall = $PS.AddScript($Function:ShowProgressForm)
                $Scriptcall = $PS.AddScript($objSB)
                $null = $Scriptcall.AddParameter("Title", $Title);
                $null = $Scriptcall.AddParameter("Message", $Message);
                # Thread (Runspace) für die Progress Form asynchron starten
                $Script:AsyncResult = $PS.BeginInvoke()
            } else {
                #Write-Host "closing..."
                # Progress Form befindet sich in der Synchronized Hashtable
                # über die Hashtable kann die Form im einem anderen Thread angesprochen werden 
                If ($sharedData.Form) {
                    $sharedData.Form.close()
                }
                # Thread (Runspace) für die Progress Form asynchron beenden
                $PS.Endinvoke($AsyncResult)
                # Thread (Runspace) für die Progress Form zerstören
                $PS.dispose()
                try {
                    $newRunspace.CloseAsync()
                    $newRunspace.Close()
                } catch {}
                
            }
        }

        $output=dialog {
            TabControl -name Top {
                TabItem Fred  {
                    listbox -contents $bios.Source
                }
                TabItem Barney {
                    listbox -contents (dir c:\temp | select -first 10) -name Barney2
                }
                TabItem Wilma {
                    listbox -contents (dir c:\temp | select -first 10) -name Wilma2
                }
                TabItem Betty {
                    listbox -contents (dir c:\temp | select -first 10) -name Betty2
                }
            }
        }


        while ((Get-BitsTransfer | Where-Object { $_.JobState -eq "Transferring" }).Count -gt 0) {

            Write-ProgressBar -ProgressBar $Progressbar `
                    -Activity "Downloading Files $timeLeft" `
                    -PercentComplete $pctComplete `
                    -Status ((Get-BitsTransfer | select @{n = 'File'; e = { Split-path $_.filelist.remotename -Leaf } },
                        @{n = 'Percent Complete'; e = { "$([math]::round(($_.Bytestransferred * 100) / $_.bytestotal))%" } }) | ft -HideTableHeaders | out-string) `
                    -SecondsRemaining "$timeLeft" `
                    -CurrentOperation "Time remaning"
        }

        While($bytestransferred -lt $totalbytes) {
            $bytestransferred++
            $percent = $([math]::round(($_.bytestransferred * 100) / $totalbytes))
            $barmax = 40
            $barPercent = $([math]::round(($_.bytestransferred * $barmax) / $_.totalbytes))
            $bar = ""
            0..$barPercent | % {$bar += "▀"}
            write-host "$bar`r" -NoNewline
        }

        $bytestransferred = 0
        $totalbytes = 4564

        While($bytestransferred -lt $totalbytes) {
            $bytestransferred++
            $percent = $([math]::round(($bytestransferred * 100) / $totalbytes))
            $barmax = 40
            $barPercent = $([math]::round(($bytestransferred * $barmax) / $totalbytes))
            $bar = ""
            0..$barPercent | % {$bar += "▀"}
            write-host "$bar`r" -NoNewline
        }
        
        function Show-Bar {
            param(
                $transferred,
                $Total
            )
            $barmax = 30
            $barPercent = $([math]::round(($transferred * $barmax) / $Total))
            $bar = ""
            0..$barPercent | % {$bar += "▀"}
            return $bar
            }
        
        while(1) {
            cls
           Write-host "$(((Get-BitsTransfer | select @{n = 'File'; e = { Split-path $_.filelist.remotename -Leaf } },
                        @{n = 'Percent Complete'; e = {
                            "$([math]::round(($_.Bytestransferred * 100) / $_.bytestotal))%: $(Show-bar -transferred $_.Bytestransferred -Total $_.bytestotal)"
                            
                        } }),
                        @{n = 'Progress';e={(Show-bar -transferred $_.Bytestransferred -Total $_.bytestotal)}} |
                        ft -HideTableHeaders | out-string))`r" -NoNewline
                    }