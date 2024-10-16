# mikrotik-configs

What do you find in this repository?

#### **Backups_Mikrotik_to_Mikrotik**
Descritpion: This directory contains a configuration to implement basic auto backup for Mikrotik.

This backup will send in mail.
The disvantatge is that when you implement this auto backup, it is necessary to apply this configuration for all Mikrotik.

#### **Backups_Centralized_with_Ubuntu**
Description: This directory contains a configuration to implement more complex auto backups for Mikrotik.

- In this repo, use an Ubuntu server to execute bash code to carry out all backups of Mikrotik.
The advantage of this code is that the process is centralized, and I don't need implementation of this for all Mikrotik; you only need implementation on the Ubuntu Server.
