# LinuxCNC for NixOS

This flake provides a `linuxcnc` package and module for NixOS, currently targeting development version LinuxCNC 2.9-pre-f77537cd4d

## Current Status

LinuxCNC can be run in a variety of configurations, and includes a wide array binaries and libraries. While this package attempts to build everything, full functionality is not guaranteed. Be aware this is an unsupported packaging of an in development branch of LinuxCNC, **proceed with appropriate caution.**

* Real-time with `PREEMPT_RT` is supported, tested on `x86_64` and `aarch64`. No attempt has been made to support RTAI or Xenomai.
* The main binaries build successfully, however many required further patching to run. Some binaries installed may still have runtime issues that require further patching. 
  * `linuxcnc`, `latency-test`, `latency-histogram`, `latency-plot`, `pncconf` (and related utilities, eg `halscope` etc) have been tested on `x86_64` and `aarch64` (Raspberry Pi 4 4GB), with a Mesa 7i76e.
  * **Only the AXIS GUI works at the moment.**
* External Mesa firmware binaries are not provided. If your card does not support internal firmware, download firmware binaries from Mesa and direct pcconf to them with `HM2_FIRMWARE_DIR`, eg `HM2_FIRMWARE_DIR=/my/hm2/dir pncconf`.
* LinuxCNC requires several binaries be `setuid root`, however NixOS forbids `setuid` binaries in the Nix store, instead wrappers must be created in the system configuration. The included module will do this automatically, enable it with `packages.linuxcnc.enable = true;`
* `readline5` was recently dropped from nixpkgs, this flake repackages it (with upstream patches) to build without GPL3 restrictions/warnings, meaning this package should be redistributable.

## To-do

* Fix other GUIs and various quirks
* Package other related tools
* Add method to declaratively provide machine configurations (Currently possible with home-manager)
* Generate SD card images for ARM devices
* Build cache

## Usage

Add the overlay `linuxcnc-nix.overlay` and module `linuxcnc-nix.nixosModules.linuxcnc` to your configuration and set `packages.linuxcnc.enable = true;`. Ensure you are using a real-time kernel (eg `boot.kernelPackages = pkgs.linuxPackages_rt_5_10;`)

## Raspberry PI 4 Example Config

Here is a minimal config for a Raspberry Pi 4 4GB using [linux_rpi4_rt-nix](https://github.com/mattywillo/linux_rpi4_rt-nix). This works well enough to configure and jog a machine with a 2ms servo thread, but has not been tested thoroughly. Further tweaks for stability and latency may be required.

``` nix
{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    linuxcnc-nix.url = "github:mattywillo/linuxcnc-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    rpi4_rt.url = "github:mattywillo/linux_rpi4_rt-nix";
  };
  outputs = { self, nixpkgs, nixos-hardware, rpi4_rt, linuxcnc-nix }: {
    nixosConfigurations.linuxcnc = nixpkgs.lib.nixosSystem {
      modules = [ 
        { nixpkgs.overlays = [ rpi4_rt.overlay linuxcnc-nix.overlay ]; }
        linuxcnc-nix.nixosModules.linuxcnc
        ({pkgs, lib, ...}: { 
          imports = [
            ./hardware-configuration.nix
            nixos-hardware.nixosModules.raspberry-pi-4
          ];
         
          networking.hostName = "linuxcnc";
          time.timeZone = "Australia/Perth";
          system.stateVersion = "22.05";

          # Enable the real-time kernel and RPi bootloader
          boot.kernelPackages = pkgs.linux_rpi4_rt.linuxPackages;
          boot.loader.grub.enable = false;
          boot.loader.grub.device = "nodev";
          boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;
          boot.loader.raspberryPi.enable = true;
          boot.loader.raspberryPi.version = 4;

          # config.txt and cmdline.txt options
          boot.loader.raspberryPi.firmwareConfig = ''
            arm_freq=2000
            force_turbo=1

            [HDMI:0]
            hdmi_group=1
            hdmi_mode=16
          '';
          boot.kernelParams = [
            "processor.max_cstate=1"
            "elevator=deadline"
            "isolcpus=1,2,3"
            "idle=poll"
          ];
         
          # timesyncd has known issues with LinuxCNC/PREEMPT_RT, use ntpd instead
          services.timesyncd.enable = false;
          services.ntp.enable = true;
         
          # Setupd a static interface for a Mesa card
          networking.interfaces.eth0.ipv4.addresses = [{
            address = "192.168.1.1";
            prefixLength  = 24;
          }];

          # Enable a basic interface
          services.xserver = {
            enable = true;
            displayManager.lightdm.enable = true;
            desktopManager.xfce.enable = true;
          };
         
          # Create a normal user account
          users.users.cnc = {
            isNormalUser = true;
            home = "/home/cnc";
            extraGroups = [ "wheel" ];
          };
        }) 
      ];
    };
  };
}
```
