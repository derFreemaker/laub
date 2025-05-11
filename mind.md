# Ideas and Decisions
This file contains some decisions and ideas that were considered.
That might explain way something is the way it is.

## Table of Contents
- [Performance](#performance)
- [Tools](#tools)
- [Plugin system](#plugin-system)
- [Dependencies](#dependencies)
- [Commands](#commands)
  - [Arguments](#arguments)
- [Interfaces for Tools](#interfaces-for-tools)
    - [Generators](#generators)
    - [Runner](#runner)
- [Caching](#caching)

## Performance
We obviously want this tool to be as fast as possible.
But since we are using lua for ease of use and want to enable to run custom function on specific steps.
[We cannot just generate some cache files.](#caching)

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
We want commands like 'laub init' or 'laub build' to be fully customizable,
being able to add commands and flags to fit what the project needs.
Also keeping a standard like init, build, package or deploy.
Best is to make a Step system which you can add steps to and create relative steps,
meaning a step can a have step before it and after.

### Arguments
Since commands can have arguments or flags we need a way to parse them out.
This will also require a solid interface for creating them as well.

## Interfaces for Tools
An interface will be called 'leaf' to match the naming origin of Laub.

### Generators
In order to generate files for other build systems an interface is needed.
This will need an extensive data set of for the generator.
Also link targets which are built somewhere else will need to be an external file for the build system.

### Runner
A leaf which runs a tool over a shell or creates a process.

## Caching
Since caching the lua state is impossible without many restrictions.
I decided the best option is to get a cache file path from a function.
Other idea was to have a server process which runs in the background.
The process could though just hang unnecessary around consuming resources in idle.
Plus this would need extra logic to reload when a configuration file got changed.
