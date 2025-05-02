# Ideas and Decisions
This file contains some decisions and ideas that were considered.
That might explain way something is the way it is.

## Table of Contents
- [Tools](mind#Tools)
- [Plugin system](<mind#Plugin system>)
- [Dependencies](mind#Dependencies)
- [Commands](mind#Commands)
  - [Arguments](mind#Arguments)
- [Interfaces for Tools](<mind#Interfaces for Tools>)
    - [Generators](mind#Generators)
    - [Runner](mind#Runner)

## Tools
The main thing of this utility is to manage tools,
through lua we can if provided run tools directly by loading them as a lua module.
This is probably preferred since it would likely save a little bit of time spinning up a shell.
But for most cases especially in the beginning we will use the shell.
Providing a solid implementation for that is key.
We will need something that is cross-platform
or be able to create a child process with the wanted arguments directly.

## Plugin system
We will need a way to add plugins best thing is probably to copy cmake in the approach.
By being able to specify a location of a git repo or some kind of archive.
That way we don't need to develop a plugin repo.

## Dependencies
Target tree is probably the best way to approach this issue.
Since we want to make it easy to link libraries which may use different build systems.
We need to create your own dependency resolver and look which has to be done before one another.

Integrating that with the steps system is going to be hell.
We could make a difference for the 'build' command and make it so that you can add steps to a target.

## Commands
Commands like 'laub init' or 'laub build' we want full customize ability,
being able to add commands and flags to what the project needs.
Also keeping a standard like init, build, package or deploy.
Best is to make a Step system which you can add steps to and create relative steps,
meaning a step can a have step before it and after.

### Arguments
Since commands can have arguments or flags we need a way to parse them out.
This will also require a solid interface for creating them as well.

## Interfaces for Tools
An interface will be called 'leaf' to match the the naming origin of Laub.

### Generators
In order to generate files for other build systems an interface is needed.
This will need an extensive data set of what the generator should tell its build system and what is expected to happen.
Also link targets which are built somewhere else will need to an external file for the build system.

### Runner
A leaf which runs a tool over a shell will.

