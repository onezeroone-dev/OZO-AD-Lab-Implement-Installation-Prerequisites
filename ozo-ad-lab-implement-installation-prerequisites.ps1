#Requires -Modules @{ModuleName="OZO";ModuleVersion="1.5.1"},@{ModuleName="OZOLogger";ModuleVersion="1.1.0"} -RunAsAdministrator

<#PSScriptInfo
    .VERSION 0.1.0
    .GUID 63ebd3a1-0d72-4090-9226-10db30d2e82f
    .AUTHOR Andy Lievertz <alievertz@onezeroone.dev>
    .COMPANYNAME One Zero One
    .COPYRIGHT This script is released under the terms of the GNU General Public License ("GPL") version 2.0.
    .TAGS
    .LICENSEURI https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/LICENSE
    .PROJECTURI https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites
    .ICONURI
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS
    .EXTERNALSCRIPTDEPENDENCIES
    .RELEASENOTES https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/CHANGELOG.md
    .PRIVATEDATA
#>

<# 
    .SYNOPSIS
    See description.
    .DESCRIPTION 
    Implements the installation prerequisites for the One Zero One AD Lab.
    .EXAMPLE
    ozo-ad-lab-implement-installation-prerequisites
    .LINK
    https://github.com/onezeroone-dev/OZO-AD-Lab-Implement-Installation-Prerequisites/blob/main/README.md
#>

Class ADLIP {
    # PROPERTIES: Strings
    [String]  $currentUser       = $null
    [String]  $downloadsDir      = $null
    [String]  $featureName       = $null
    [String]  $localGroup        = $null
    # PROPERTIES: PSCustomObjects
    [PSCustomObject] $ozoLogger = @()
    # METHODS
    # Constructor method
    ADLIP() {
        # Set properties
        $this.currentUser  = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
        $this.downloadsDir = (Join-Path -Path $Env:USERPROFILE -ChildPath "Downloads")
        $this.featureName  = "Microsoft-Hyper-V-All"
        $this.localGroup   = "Hyper-V Administrators"
        # Create a logger object
        $this.ozoLogger = (New-OZOLogger)
        # Declare ourselves to the world
        $this.ozoLogger.Write("Process starting.","Information")
        # Call ValidateEnvironment to determine if we can proceed
        If ($this.ValidateEnvironment() -eq $true) {
            # Environment validates; report
            $this.ozoLogger.Write("Environment validates.","Information")
            # Call ProcessPrerequisites to ...process the prerequisites
            $this.ProcessPrerequisites()
        } Else {
            # Environment did not validate
            $this.ozoLogger.Write("The environment did not validate.","Error")
        }
        # Bid adieu to the world
        $this.ozoLogger.Write("Process complete.","Information")
    }
    # Process prerequisites method
    Hidden [Void] ProcessPrerequisites() {
        # Environment validates; install Hyper-V features
        $this.ozoLogger.Write("Installing Hyper-V features.","Information")
        If ($this.InstallHyperV() -eq $true) {
            # Hyper-V features are installed; determine if a reboot is not required
            $this.ozoLogger.Write("Determining if a restart is required.","Information")
            If ($this.RestartRequired() -eq $false) {
                # Restart is not required; add the local user to the Hyper-V Administrators group
                $this.ozoLogger.Write("Adding user to the local Hyper-V Administrators group.","Information")
                If ($this.ManageLocalHyperVAdministratorsGroup() -eq $true) {
                    # Local user is added to the local Hyper-V Administrators group; create the VM switches
                    $this.ozoLogger.Write("Creating the Hyper-V VMSwitches.","Information")
                    If ($this.CreateVMSwitches() -eq $true) {
                        # VM switches are created; report all prerequisites satisfied
                        $this.ozoLogger.Write("All prerequisites are satisfied. Please see https://onezeroone.dev/active-directory-lab-customize-the-windows-installer-isos for the next steps.","Information")
                    } Else {
                        # VMSwitch creation error
                        $this.ozoLogger.Write("Error creating the VM switches. Please manually create these switches then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information.","Error")
                    }
                } Else {
                    # Error adding user to local Hyper-V Administrators group
                    $this.ozoLogger.Write(("Failure adding user " + $this.currentUser + " to the " + $this.localGroup + " group. Please manually add this user to this group then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                }
            } Else {
                # Restart is required
                $this.ozoLogger.Write("Please restart to complete the feature installation and then run this script again to continue.","Warning")
                # Get restart decision
                If ((Get-OZOYesNo) -eq "y") {
                    # User elects to restart
                    Restart-Computer
                }
            }
        } Else {
            # Error installing Hyper-V Feature
            $this.ozoLogger.Write(("Error installing the " + $this.featureName + " feature. Please manually install this feature and then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
        }
    }
    # Environment validation method
    Hidden [Boolean] ValidateEnvironment() {
        # Control variable
        [Boolean] $Return = $true
        # Determine if this a user-interactive session
        If ((Get-OZOUserInteractive) -eq $false) {
            # Session is not user-interactive
            $this.ozoLogger.Write("Please run this script in a user-interactive session.","Error")
            $Return = $false
        }
        # Return
        return $Return
    }
    # Install Hyper-V method
    Hidden [Boolean] InstallHyperV() {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the feature is present
        If ([Boolean](Get-WindowsOptionalFeature -Online -FeatureName $this.featureName) -eq $false) {
            # Feature is not present; try to install it
            Try {
                Enable-WindowsOptionalFeature -Online -FeatureName $this.featureName -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # Reboot required method
    Hidden [Boolean] RestartRequired() {
        # Control variable
        [Boolean] $Return = $false
        # Determine if feature is present
        If ((Get-WindowsOptionalFeature -Online -FeatureName $this.featureName).RestartRequired -eq "Required") {
            # Restart is required
            $this.Return = $true   
        }
        # Return
        return $Return
    }
    # Manage local Hyper-V Administrators group membership
    Hidden [Boolean] ManageLocalHyperVAdministratorsGroup() {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the current user is a member of the local Hyper-V Administrators group
        If ((Get-LocalGroupMember -Name $this.localGroup).Name -NotContains $this.currentUser) {
            # User is not in the local group; try to add them
            Try {
                Add-LocalGroupMember -Group "Hyper-V Administrators" -Member $this.currentUser
                # Success
            } Catch {
                # Failure
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # Create VM switches method
    Hidden [Boolean] CreateVMSwitches() {
        # Control variable
        [Boolean] $Return          = $true
        [String]  $externalAdapter = $null
        # Determine if the private switch already exists
        If ([Boolean](Get-VMSwitch -Name "AD Lab Private") -eq $false) {
            # Private switch does not exist; try to create it
            Try {
                New-VMSwitch -Name "AD Lab Private" -SwitchType Private -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $Return = $false
            }
        }
        # Determine if the external switch already exists
        If ([Boolean](Get-VMSwitch -Name "AD Lab External") -eq $false) {
            # External switch does not exist; call Get-NetAdapter to display available network connections
            Write-Host (Get-NetAdapter)
            # Prompt the user for the name of the external network connection until they correctly identify an adapter
            Do {
                $externalAdapter = (Read-Host "Above is the output of the Get-NetAdapter command. Type the Name of the network adapter that corresponds with your external network (Internet) connection")
            } Until ((Get-NetAdapter).Name -Contains $externalAdapter)
            # Try to create the external switch
            Try {
                New-VMSwitch -Name "AD Lab External" -NetAdapterName $externalAdapter -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $Return = $false
            }
        }
        # Return
        return $Return
    }
}

Function Get-OZOYesNo {
    # Prompt the user to restart and return the lowercase of the first letter of their response
    [String]$response = $null
    Do {
        $response = (Read-Host "(Y/N)")[0].ToLower()
    } Until ($response -eq "y" -Or $response -eq "n")
    # Return response
    return $response
}

# MAIN
[ADLIP]::new() | Out-Null
