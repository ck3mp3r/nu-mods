# Nu Mods

A collection of Nushell modules for extending shell functionality.

## About

This repository contains various Nushell modules that provide additional commands and utilities for the Nu shell environment.

## Installation

To make these modules discoverable by Nushell, you need to add this directory to your `NU_LIB_DIRS` environment variable or configure it in your `config.nu` file.

### Method 1: Environment Variable
Set the `NU_LIB_DIRS` environment variable to include this directory:

```bash
export NU_LIB_DIRS="/path/to/nu-mods"
```

### Method 2: Config File
Add this directory to your `config.nu` file:

```nu
const NU_LIB_DIRS = [
    "/path/to/nu-mods"
]
```

## Usage

Once the modules are in your library path, you can import them using the `use` command:

```nu
use module-name
```

For modules organized as directories, you can import the entire module or specific functions:

```nu
use module-directory
use module-directory/specific-file
use module-directory *
```

## Contributing

Feel free to contribute additional modules or improvements to existing ones.