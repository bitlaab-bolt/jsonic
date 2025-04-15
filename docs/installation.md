# How to Install

Navigate to your Zig project directory. e.g., `cd my_awesome_project`

## Install the Nightly Version

Fetch **jsonic** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/jsonic/archive/refs/heads/main.zip
```

## Install the Release Version

Fetch **jsonic** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/jsonic/archive/refs/tags/v0.0.0.zip
```

Make sure to edit `v0.0.0` with the latest release version.

## Import Module

Now, import **jsonic** as external package module to your project by coping following code:

```zig title="build.zig"
const jsonic = b.dependency("jsonic", .{});
exe.root_module.addImport("jsonic", jsonic.module("jsonic"));
lib.root_module.addImport("jsonic", jsonic.module("jsonic"));
```
