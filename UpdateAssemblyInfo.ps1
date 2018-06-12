param
(
    # The root path of the solution.
    [String] $SolutionRoot = $null
)

# This GUID is unique and belongs to AssemblyInfo.csproj, it is stored in a .csproj file
$AssemblyInfoOrignalGUIDUpper = "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}"
# E.g.[assembly: AssemblyInformationalVersion(AssemblyInfo.ProductVersion)]
$ProductVersionPattern = "assembly: AssemblyInformationalVersion"

$script:CurrentPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Entry {
    trap {
        throw "Exception: $($_.Exception.Message)"
        exit
    }

    Set-Location $CurrentPath

    if (Test-Path .\AllProjectWithPath.txt) {
        Remove-Item .\AllProjectWithPath.txt -Force -Recurse
    }
    elseif (Test-Path .\UpateProductVersionLog.log) {
        Remove-Item .\UpateProductVersionLog.log -Force -Recurse
    }
    else {
        # Do Nothing.
    }

    # Get all project with full path under whole workspace.
    Get-ChildItem $SolutionRoot -Recurse *.csproj | ForEach-Object {$_.FullName} > AllProjectWithPath.txt

    for ($file = [IO.File]::OpenText("$CurrentPath\AllProjectWithPath.txt"); !($file.EndOfStream)) {
        trap {
            throw "Exception: $($_.Exception.Message)"
            exit
        }

        # Each line is a .csproj file with full path.
        $line = $file.ReadLine()
        $Content = Get-Content -Path $line

        if ($Content -like "*$AssemblyInfoOrignalGUIDUpper*") {
            # Cause the AssemblyInfo.cs could be loacted at different path.
            # Generally, AssemblyInfo.cs is located in a folder named "Properties", which has the same path as the .csproj file;
            # another case, AssemblyInfo.cs and .csproj file are in the same directory.
            $SingleAssemblyInfoPath = (Split-Path -Path $line) + "\Properties\AssemblyInfo.cs"
            $AssemblyInfoNotLocaInPropertiesFolder = (Split-Path -Path $line) + "\AssemblyInfo.cs"

            # So test two regular path, to find the AssemblyInfo.cs file.
            if (Test-Path $SingleAssemblyInfoPath) {
                if ((Get-Content $SingleAssemblyInfoPath).Contains($ProductVersionPattern)) {
                    "**$line**" >> UpateProductVersionLog.log
                    "Current project has referred the Product version from common AssemblyInfo.cs" >> UpateProductVersionLog.log
                    Write-Host "$line" -ForegroundColor Green
                }
                else {
                    "**$line**" >> UpateProductVersionLog.log
                    "Refers the Product version from common AssemblyInfo.cs to current project" >> UpateProductVersionLog.log
                    & "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\TF.exe" checkout $SingleAssemblyInfoPath | Out-Null
                    Add-Content -Path $SingleAssemblyInfoPath -Value "`r`n$ProductVersionPattern" | Out-Null
                }
            }
            elseif (Test-Path $AssemblyInfoNotLocaInPropertiesFolder) {
                if ((Get-Content $AssemblyInfoNotLocaInPropertiesFolder).Contains($ProductVersionPattern)) {
                    "**$line**" >> UpateProductVersionLog.log
                    "Current project has referred the Product version from common AssemblyInfo.cs" >> UpateProductVersionLog.log
                    Write-Host "$line" -ForegroundColor Green
                }
                else {
                    "**$line**" >> UpateProductVersionLog.log
                    "Refers the Product version from common AssemblyInfo.cs to current project" >> UpateProductVersionLog.log
                    & "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\TF.exe" checkout $AssemblyInfoNotLocaInPropertiesFolder | Out-Null
                    Add-Content -Path $AssemblyInfoNotLocaInPropertiesFolder -Value "`r`n$ProductVersionPattern" | Out-Null
                }
            }
            else {
                "**$line**" >> UpateProductVersionLog.log
                "Cannot find the AssemblyInfo.cs of current project" >> UpateProductVersionLog.log
                Write-Host "$line" -ForegroundColor Red
            }
        }
        else {
            "**$line**" >> UpateProductVersionLog.log
            "Current project does not refer the AssemblyInfo.csproj, so ignore it." >> UpateProductVersionLog.log
        }
    }

    $file.Close()
}

Entry