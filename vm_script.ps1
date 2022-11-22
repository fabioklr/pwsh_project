# Check whether PowerShell 7.3 is installed by searching the registry. If so, the script will exit
$psLink = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.0/PowerShell-7.3.0-win-x64.msi'
Invoke-WebRequest $psLink -OutFile 'C:\Users\fabioklr\Downloads\PowerShell-7.3.0-win-x64.msi'
Invoke-Item "C:\Users\fabioklr\Downloads\PowerShell-7.3.0-win-x64.msi"
read-host “Press ENTER to continue...”
Start-Process -filePath "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PowerShell\PowerShell 7 (x64).lnk"

# Set system-wide dark mode.
$path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-ItemProperty -Path $path -Name SystemUsesLightTheme -Value 0
Set-ItemProperty -Path $path -Name AppsUseLightTheme -Value 0

# Install Firefox.
$link = 'https://download.mozilla.org/?product=firefox-stub&os=win&lang=en-US'
$fileLocation = 'C:\Users\fabioklr\Downloads'
$installer = '\Firefox Installer.exe'
$installedApplication = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Firefox.lnk'
$installed = (Test-Path $installedApplication)

if($installed) 
{
	Write-Host 'Firefox is already installed.'
} 
else 
{
    Write-Host 'Downloading the Firefox installer...'
    if (-not (Test-Path $fileLocation)) 
    {
        New-Item -ItemType 'directory' -Path $fileLocation
    }
    Invoke-WebRequest $link -OutFile $fileLocation$installer
    Invoke-Item -Path ($fileLocation + $installer)
}'p'