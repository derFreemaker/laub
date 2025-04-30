# Laub [WIP]
Lua based build utility.

## Why
Laub is a lua based project utility designed to simplify the process of managing projects.
It provides a flexible and powerful framework for automating tasks such as compiling, packaging, and testing.

Difference to [xmake](https://xmake.io) for example is the configuration approach instead of defining
your targets in a list kind of manner. The goal is to make it more [cmake](https://cmake.org) like.
It is also not meant as an generator more like a interface which than can be combined with a
generator to create [ninja](https://ninja-build.org) files for example.
It so manages the overview of an project, but not the details like building or linking.
Leaving the freedom for a custom implementation, making it possible to combine what ever you want.
