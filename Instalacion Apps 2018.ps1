Function ImportNavModules {
    Import-Module C:\"Program Files (x86)"\"Microsoft Dynamics NAV"\110\"RoleTailored Client"\"Microsoft.Dynamics.Nav.Model.Tools.dll"
    Import-Module C:\"Program Files (x86)"\"Microsoft Dynamics NAV"\110\"RoleTailored Client"\"Microsoft.Dynamics.Nav.Apps.Tools.dll"
    Import-Module C:\"Program Files (x86)"\"Microsoft Dynamics NAV"\110\"RoleTailored Client"\"Microsoft.Dynamics.Nav.Apps.Management.dll"
    Import-Module C:\"Program Files (x86)"\"Microsoft Dynamics NAV"\110\"RoleTailored Client"\"Microsoft.Dynamics.Nav.Management.dll"
}

Function ErrorMessage($MessageNo) {
    switch ($MessageNo) {
        0 { 
            Write-Host "Cancelado" 
            Break "Cancelado"
        }
        1 { 
            Write-Host "La instancia es obligatoria" 
            Break "Cancelado"
        }
        2 {
            Write-Host "La versión antigua es obligatoria" 
            Break "Cancelado"
        }
        3 { 
            Write-Host "El nombre de extensión es obligatorio" 
            Break "Cancelado"
        }
        4 {
            Write-Host "Acción en desarrollo"
            Break "Cancelado"
        }        
        99 { 
            Write-Host "Completado correctamente"
            Read-Host "Presiona Intro para continuar..."
        }
    }     
}

Function Get-FileName($initialDirectory) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "APP (*.app)| *.app"
    $OpenFileDialog.ShowDialog() | Out-Null
    if ($OpenFileDialog.FileName -eq "") { ErrorMessage(0) }
    else { return $OpenFileDialog.FileName }
}

Function Get-Extension {   
    $extensions = Get-NAVAppTableModification -ServerInstance $ServerInstance
    
    for ($x = 0; $x -le $extensions.LongLength - 1; $x++) {
        $texto = $x.ToString().PadLeft(2, ' ') + ' -- ' + $extensions[$x].Name.ToString().PadRight(35, ' ') + ' Publicador: ' + $extensions[$x].Publisher.ToString().PadRight(35, ' ') + ' Version: ' + $extensions[$x].Version.Major.ToString() + '.' + $extensions[$x].Version.Minor.ToString() + '.' + $extensions[$x].Version.Build.ToString() + '.' + $extensions[$x].Version.Revision.ToString()         
        Write-Host $texto
    }
        
    $x = Read-Host "Que extensión?"
    if (!$extensions[$x]) { ErrorMessage(3) }


    return $extensions[$x]
}

Function Get-NavServices {   
    $services = Get-Service -Name "MicrosoftDyn*"
    
    for ($y = 0; $y -le $services.LongLength - 1; $y++) {
        $texto = $y.ToString().PadLeft(2, ' ') + ' -- ' + $services[$y].ServiceName.Substring($services[$y].ServiceName.LastIndexOf('$') + 1).PadRight(20, ' ') + ' -- ' + $services[$y].Status.ToString()

        Write-Host $texto
    }
        
    $y = Read-Host "Que servicio?"
    if (!$services[$y]) { ErrorMessage(1) }

    return $services[$y].ServiceName.Substring($services[$y].ServiceName.LastIndexOf('$') + 1)
}

Function CheckAdminRights {
    ###Run as Admin #########################################################################
    # Get the ID and security principal of the current user account
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
    $myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

    # Get the security principal for the administrator role
    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

    # Check to see if we are currently running as an administrator
    if ($myWindowsPrincipal.IsInRole($adminRole)) {
        # We are running as an administrator, so change the title and background colour to indicate this
        $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
        #$Host.UI.RawUI.BackgroundColor = "DarkBlue";
        Clear-Host;
    }
    else {
        # We are not running as an administrator, so relaunch as administrator

        # Create a new process object that starts PowerShell
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

        # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
        $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

        # Indicate that the process should be elevated
        $newProcess.Verb = "runas";

        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess);

        # Exit from the current, unelevated, process
        Exit;
    }
}

###Code #################################################################################
CheckAdminRights
ImportNavModules
$Title = "Hola!"
$Info = "Que deseas hacer?"
 
$options = [System.Management.Automation.Host.ChoiceDescription[]] @("&Instalar", "&Actualizar", "&Forzar Act.", "&Recreate", "&Despublicar", "R&einstalar")
[int]$defaultchoice = 1
$opt = $host.UI.PromptForChoice($Title , $Info , $Options, $defaultchoice)

$ServerInstance = Get-NavServices

switch ($opt) {
    0 {
        #Instalar
        $ExtensionPath = Get-FileName
        $ExtensionName = $ExtensionPath.SubString($ExtensionPath.IndexOfAny("_", $ExtensionPath.LastIndexOf("\")) + 1, $ExtensionPath.LastIndexOf("_") - 1 - $ExtensionPath.IndexOfAny("_", $ExtensionPath.LastIndexOf("\")))

        Write-Host "Instalando..."

        Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification -ErrorAction Inquire
        Sync-NAVTenant -ServerInstance $ServerInstance -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Force -ErrorAction Inquire
        Install-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Force -ErrorAction Inquire
    }

    1 {
        #Actualizar
        $Extension = Get-Extension
        $ExtensionName = $Extension.Name.ToString()
        $OldExtensionVersion = $Extension.Version.ToString()

        $ExtensionPath = Get-FileName
        $NewExtensionVersion = $ExtensionPath.SubString($ExtensionPath.LastIndexOf("_") + 1, $ExtensionPath.LastIndexOf(".") - 1 - $ExtensionPath.LastIndexOf("_"))

        Write-Host "Actualizando..."
        
        Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification -ErrorAction Inquire
        Sync-NAVTenant -ServerInstance $ServerInstance -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -ErrorAction Inquire
    }

    2 {
        #Forzar Actualizar
        $Extension = Get-Extension
        $ExtensionName = $Extension.Name.ToString()
        $OldExtensionVersion = $Extension.Version.ToString()

        $ExtensionPath = Get-FileName
        $NewExtensionVersion = $ExtensionPath.SubString($ExtensionPath.LastIndexOf("_") + 1, $ExtensionPath.LastIndexOf(".") - 1 - $ExtensionPath.LastIndexOf("_"))

        Write-Host "Actualizando..."
        
        Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification -ErrorAction Inquire
        Sync-NAVTenant -ServerInstance $ServerInstance -Force -ErrorAction Inquire
        Uninstall-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Mode ForceSync -Force -ErrorAction Inquire
        Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -ErrorAction Inquire
    }

    3 {
        #Recreate
        $Extension = Get-Extension
        $ExtensionName = $Extension.Name.ToString()
        $OldExtensionVersion = $Extension.Version.ToString()

        $ExtensionPath = Get-FileName
        $NewExtensionVersion = $ExtensionPath.SubString($ExtensionPath.LastIndexOf("_") + 1, $ExtensionPath.LastIndexOf(".") - 1 - $ExtensionPath.LastIndexOf("_"))
        
        Write-Host "Actualizando..."

        Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification -ErrorAction Inquire
        Sync-NAVTenant -ServerInstance $ServerInstance -Force -ErrorAction Inquire
        Uninstall-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Mode Clean -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Install-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -ErrorAction Inquire
    }

    4 {
        #Despublicar
        $Extension = Get-Extension
        $ExtensionName = $Extension.Name.ToString()
        $ExtensionVersion = $Extension.Version.ToString()

        Write-Host "Despublicando..."
        
        Uninstall-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $ExtensionVersion -Force -ErrorAction Inquire
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $ExtensionVersion -ErrorAction Inquire
    }
    
    5 {
        #Reinstalar
        ErrorMessage(4)
        $Extension = Get-Extension
        $ExtensionName = $Extension.Name.ToString()
        $OldExtensionVersion = $Extension.Version.ToString()

        $ExtensionPath = Get-FileName
        $NewExtensionVersion = $ExtensionPath.SubString($ExtensionPath.LastIndexOf("_") + 1, $ExtensionPath.LastIndexOf(".") - 1 - $ExtensionPath.LastIndexOf("_"))

        Write-Host "Actualizando..."
        
        Publish-NAVApp -ServerInstance $ServerInstance -Path $ExtensionPath -SkipVerification -ErrorAction Inquire
        Sync-NAVTenant -ServerInstance $ServerInstance -Force -ErrorAction Inquire
        Uninstall-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -Force -ErrorAction Inquire
        Sync-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Mode Development -Force -ErrorAction Inquire
        Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Name $ExtensionName -Version $NewExtensionVersion -Force -ErrorAction Inquire
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $ExtensionName -Version $OldExtensionVersion -ErrorAction Inquire
    }
}

ErrorMessage(99)