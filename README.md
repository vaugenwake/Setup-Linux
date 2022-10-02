# Linux Setup Tool

This tools is a CLI built to help with setting up a new linux machine to be ready for PHP development.

It will install and verify packages and tools to be installed on your system as well as assist in configuring some basic system settings.

![example of the verify command](/verify.png "Verify Command")

## What is included:

**Packages:**
* git
* curl
* wget
* net-tools
* nano
* vim
* tmux
* xclip

**Tools:**
* PHP
* Composer
* Docker, docker-compose
* Nodejs & NPM

**System Configuration:**
* Git setup
* SSH Key
* Docker user permissions

## Usage:
To use this tool follow the commands below:

Download
`curl -o ./setup.sh https://raw.githubusercontent.com/vaugenwake/Setup-Linux/main/setup.sh && chmod +x setup.sh`

Execute
`./setup.sh [command]`

Commands

|Command | Description |
| --- | --- |
| version | Version number |
| help | Display help menu |
| verify | Check system health |
| install | Install/Reinstall a new system |
