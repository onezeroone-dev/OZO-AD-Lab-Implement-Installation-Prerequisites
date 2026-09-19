#Requires -Modules @{ModuleName="OZO"; ModuleVersion="1.7.0"},OZOLogger -RunAsAdministrator

<#PSScriptInfo
    .VERSION 1.0.0
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

#PARAMETERS
[CmdletBinding()] Param(
    [Parameter(Mandatory=$false)][String] $FeatureName = "Microsoft-Hyper-V-All",
    [Parameter(Mandatory=$false)][String] $LocalGroup = "Hyper-V Administrators"
)

# CLASSES
Class Main {
    # PROPERTIES: PSCustomObjects
    [PSCustomObject] $ozoLogger = @()
    # METHODS: Constructor method
    Main($FeatureName,$LocalGroup) {
        # Create a logger object
        $this.ozoLogger = (New-OZOLogger)
        # Declare ourselves to the world
        $this.ozoLogger.Write("Process starting.","Information")
        # Call ValidateEnvironment to determine if we can proceed
        If ($this.ValidateEnvironment() -eq $true) {
            # Determine if the Hyper-V features are not installed
            If ($this.InstallHyperV($FeatureName) -eq $false) {
                # Hyper-V features are not installed
                $this.prerequisiteSatisfied = $false
            } Else {
                # Hyper-V features are installed; determine if a restart is required
                If ($this.RestartRequired($FeatureName) -eq $true) {
                    # Restart is required
                    $this.prerequisiteSatisfied = $false
                }
            }
            # Determine if the user not is added to the local Hyper-V Administrators group
            If ($this.ManageLocalHyperVAdministratorsGroup(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name),$LocalGroup) -eq $false) { $this.prerequisiteSatisfied = $false }
            # Determine if the VM switches are not created
            If ($this.CreateVMSwitches() -eq $false) { $this.prerequisiteSatisfied = $false }
            # Determine if all prerequisites were met
            If ($this.prerequisiteSatisfied -eq $true) {
                # All prerequisites are satisfied
                $this.ozoLogger.Write("All prerequisites are satisfied. Please see https://onezeroone.dev/active-directory-lab-part-iii-create-the-virtual-machines for the next steps.","Information")
            }
        } Else {
            # Environment did not validate
            $this.ozoLogger.Write("The environment did not validate.","Error")
        }
    }
    # METHODS: Environment validation method
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
    # METHODS: Install Hyper-V method
    Hidden [Boolean] InstallHyperV($FeatureName) {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the feature is present
        If ([Boolean](Get-WindowsOptionalFeature -Online -FeatureName $FeatureName) -eq $false) {
            # Report
            $this.ozoLogger.Write(("Installing " + $FeatureName + " feature."),"Information")
            # Feature is not present; try to install it
            Try {
                Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $this.ozoLogger.Write(("Error installing the " + $FeatureName + " feature. Please manually install this feature and then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # METHODS: Reboot required method
    Hidden [Boolean] RestartRequired($FeatureName) {
        # Control variable
        [Boolean] $Return = $false
        # Report
        $this.ozoLogger.Write("Determining if a restart is required.","Information")
        # Determine if feature is present
        If ((Get-WindowsOptionalFeature -Online -FeatureName $FeatureName).RestartRequired -eq "Required") {
            # Restart is required
            $this.ozoLogger.Write(("Please restart to complete the " + $FeatureName + " feature installation and then run this script again to continue."),"Warning")
            $Return = $true
            # Get restart decision
            If ((Get-OZOYesNo) -eq "y") {
                # User elects to restart
                Restart-Computer
            }
        }
        # Return
        return $Return
    }
    # METHODS: Manage local Hyper-V Administrators group membership
    Hidden [Boolean] ManageLocalHyperVAdministratorsGroup($CurrentUser,$LocalGroup) {
        # Control variable
        [Boolean] $Return = $true
        # Determine if the current user is a member of the local Hyper-V Administrators group
        If ((Get-LocalGroupMember -Name $LocalGroup).Name -NotContains $CurrentUser) {
            # Report
            $this.ozoLogger.Write(("Adding user to the local " + $LocalGroup + " group."),"Information")
            # User is not in the local group; try to add them
            Try {
                Add-LocalGroupMember -Group $LocalGroup -Member $CurrentUser -ErrorAction Stop
                # Success
            } Catch {
                # Failure
                $this.ozoLogger.Write(("Failure adding user " + $CurrentUser + " to the " + $LocalGroup + " group. Please manually add this user to this group then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information."),"Error")
                $Return = $false
            }
        }
        # Return
        return $Return
    }
    # METHODS: Create VM switches method
    Hidden [Boolean] CreateVMSwitches() {
        # Control variable
        [Boolean] $Return = $true
        # Local variables
        [String]  $externalAdapter = $null
        # Determine if the Get-VMSwitch cmdlet is available
        If ([Boolean](Get-Command -Name Get-VMSwitch -ErrorAction SilentlyContinue) -eq $true) {
            # Get-VMSwitch cmdlet is available; determine if the private switch already exists
            If ([Boolean](Get-VMSwitch -Name "OZO AD Lab Private") -eq $false) {
                # Report
                $this.ozoLogger.Write("Creating the Hyper-V OZO AD Lab Private VMSwitch.","Information")
                # Private switch does not exist; try to create it
                Try {
                    New-VMSwitch -Name "OZO AD Lab Private" -SwitchType Private -ErrorAction Stop
                    # Success
                } Catch {
                    # Failure
                    $this.ozoLogger.Write("Error creating the VM switches. You may need to log out and back in to refresh your group membership. If that does not help, please manually create these switches. Then run this script again to continue. See https://onezeroone.dev/active-directory-lab-part-ii-customization-prerequisites/ for more information.","Error")
                    $Return = $false
                }
            }
            # Determine if the external switch already exists
            If ([Boolean](Get-VMSwitch -Name "OZO AD Lab External") -eq $false) {
                # Report
                $this.ozoLogger.Write("Creating the Hyper-V OZO AD Lab External VMSwitch.","Information")
                # External switch does not exist; call Get-NetAdapter to display available network connections
                Get-NetAdapter | Out-Host
                # Prompt the user for the name of the external network connection until they correctly identify an adapter
                Do {
                    $externalAdapter = (Read-Host "Above is the output of the Get-NetAdapter command. Type the Name of the network adapter that corresponds with your external network (Internet) connection")
                } Until ((Get-NetAdapter).Name -Contains $externalAdapter)
                # Try to create the external switch
                Try {
                    New-VMSwitch -Name "OZO AD Lab External" -NetAdapterName $externalAdapter -ErrorAction Stop
                    # Success
                } Catch {
                    # Failure
                    $Return = $false
                }
            }
        } Else {
            # Get-VMSwitch cmdlet is not available
            $Return = $false
        }
        # Return
        return $Return
    }
}

# MAIN
[Main]::new($FeatureName,$LocalGroup) | Out-Null
