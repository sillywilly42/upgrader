# macOS Upgrader

![macOS Upgrader 1.0](http://sillywilly42.github.io/images/welcome.png)

If you manage the Mac infrastructure in a corporate environment you may
encounter the challenges presented by annual OS updates. In order to address
some of these, we use the tool presented here which addresses the follwing
issues:

* providing a local mirror in each office of the download package.
* checking environment-specific requirements before upgrading.
* enabling users to upgrade without having to enable the App Store.

# Stages

The app is formed of stages which flow from one to the next.

## Welcome screen

Comes complete with easter egg - I'd recommend you replace The Fonz with a photo
of someone called Daryll - you can do anything on your last day at MegaCorp.

## Pre-upgrade Checks

![macOS Upgrader 1.0](http://sillywilly42.github.io/images/checks.png)

For example, you may want to prevent users with incompatible third-party
software from upgrading.

## Downloading

![macOS Upgrader 1.0](http://sillywilly42.github.io/images/download.png)

This is very geared towards our environment where we have an externally
accessible server which we can fall back on if there's no local office mirror.
It would probably be best to re-write Download.m to fit your environment.

Out of the box you can set some defaults in the code, and/or override them with
a plist in /Library/Preferences. We identify which office our Macs are in by
netblock, so, as it's written, you define a dictionary of netblocks -> office
identifier, and another dictionary of office identifier -> download server.

## Installing

This is done using Apple's poorly documented startosinstall command.
