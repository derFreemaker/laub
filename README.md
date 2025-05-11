<br>
<div align="center">
  <img src="./logo_edit.png" alt="Laub Logo" style="height:auto; width:50%;"/>
</div>

![](https://img.shields.io/badge/-Work%20in%20Progress-f00?style=for-the-badge)

Laub is a project utility designed to simplify the process of managing projects.
It provides a flexible and powerful framework for automating tasks such as compiling, packaging, and testing.
It does NOT replace existing tools.
It is meant as a project manager which tells other tools what to do.

## Configuration Language
Lua is used to configure your project this was chosen for its ease and simplicity.
Lua also provides the direct calling of "unmanaged" functions like c or zig.
Giving you the option to write more performance orientated code in a compiled language,
keeping the overhead smaller this tool introduces.
Or just interact with other tools directly instead over the command line.

## Name Origin
The Laub project utility tool derives its name from the German word "Laub" for a stack of leaves or foliage.
This name reflects the tool's purpose: managing the many different tools and components (leaves) that make up a modern software project.

## Disclaimer
This Project is very ambitious and therefore will need time to evolve.

**This project is still in it's designing phase.**

A reflection of decisions which were made can be found [here](mind.md).

## Dependencies
(managed through zig)

- [zlua](https://github.com/natecraddock/ziglua)
- [yazap](https://github.com/prajwalch/yazap)
