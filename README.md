
<br />
<p align="center">
  <img src="./logo/laub.png" height="300" />
</p>
<br />

# [WIP]
Laub is a lua based project utility designed to simplify the process of managing projects.
It provides a flexible and powerful framework for automating tasks such as compiling, packaging, and testing.

## Why Laub
Difference to [xmake](https://xmake.io) for example is the configuration approach instead of defining
your targets in a list kind of manner. The goal is to make it more [cmake](https://cmake.org) like.
It is also not meant as a generator more like an interface which than can be combined with a
generator to create [ninja](https://ninja-build.org) files for example.
It so manages the overview of a project, but not the details like building or linking.
Leaving the freedom for a custom implementation, making it possible to combine what ever you want.
So technically it is just fancy glue to combine multiple toolchains and languages and manage them from a central point.
