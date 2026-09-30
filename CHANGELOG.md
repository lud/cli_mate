# Changelog

All notable changes to this project will be documented in this file.

## [0.11.0] - 2026-09-30

### 🚀 Features

- Added :deprecated param to options (_lud_)
- Added validation of all library options (_lud_)
- [**breaking**] Rework option inheritance across sub-commands (_lud_)

### 🐛 Bug Fixes

- Reject options combining keep: true with type: :count (_lud_)

### ⚙️ Miscellaneous Tasks

- Limit justfile verbosity on mix.deps (_lud_)

## [0.10.2] - 2026-06-02

### 📚 Documentation

- Enable ex_doc markdown formatter (_lud_)

## [0.10.1] - 2026-05-29

### ⚙️ Miscellaneous Tasks

- Fixed Compilation warnings for Elixir 1.20 (_lud_)

## [0.10.0] - 2026-04-14

### 🚀 Features

- Added support for subcommands (_lud_)

### 📚 Documentation

- Added subcommands documentation (_lud_)

## [0.9.0] - 2025-11-27

### 🚀 Features

- Enable support for module-based commands (_lud_)
- Added cast capability to Option (_lud_)

## [0.8.4] - 2025-09-16

### 🚀 Features

- Added support for repeatable arguments (_lud_)
- Compress output of --help (_lud_)

## [0.8.3] - 2025-09-13

### 🚀 Features

- Simplified output of the plaintext usage block (_lud_)

## [0.8.2] - 2025-09-12

### 🚀 Features

- Added code path support for global mix archives (_lud_)

### ⚙️ Miscellaneous Tasks

- Credo (_lud_)

## [0.8.1] - 2025-05-06

### 🐛 Bug Fixes

- Fixed moduledoc spacing and trimming (_lud_)

## [0.8.0] - 2025-05-06

### 🚀 Features

- [**breaking**] Move all CLI modules under the CliMate.CLI namespace (_lud_)
- Added the cli.embed command to copy the library in another application (_lud_)
- Display arguments in usage block (_lud_)

### 🐛 Bug Fixes

- Correctly output argument type error (_lud_)
- Fixed moduledoc option type for cli.embed (_lud_)

### 📚 Documentation

- Describe migration to 0.8 in README.md (_lud_)
- Moved basic usage to guides (_lud_)

### 🧪 Testing

- Ensure nil defaults are correctly printed in usage (_lud_)

### ⚙️ Miscellaneous Tasks

- Update Elixir Github workflow (#18) (_Ludovic Dem_)
- Configure Git Cliff (_lud_)

## [0.7.1] - 2025-03-24

### 🐛 Bug Fixes

- Fixed indentation in moduledoc format for multiline option docs (_lud_)

### ⚙️ Miscellaneous Tasks

- Cleanup debug output (_lud_)

## [0.7.0] - 2025-03-24

### 🚀 Features

- [**breaking**] Remove embeddable capability (_lud_)

### 📚 Documentation

- Writing more documentation for options (_lud_)

### 🧪 Testing

- Remove output from tests (_lud_)

### ⚙️ Miscellaneous Tasks

- Removed demo code (_lud_)
- Update dependabot config (_lud_)
- Update dependabot config (#3) (_Ludovic Dem_)
- Setup dialyzer for CI (_lud_)
- Update CI config (#5) (_Ludovic Dem_)
- Deprecation message for embeedding (_lud_)
- Configuration for credo (_lud_)
- Update dependabot config (#12) (_Ludovic Dem_)

## [0.6.0] - 2024-11-08

### 🚀 Features

- Improved usage formatting with types and dynamic defaults (_lud_)
- Allow customization of default value doc in usage blocks (_lud_)

### 🧪 Testing

- Reorder tests (_lud_)

## [0.5.0] - 2024-06-26

### 🚀 Features

- Added doc_arg spec option to command options (_lud_)

## [0.4.1] - 2024-06-15

### ⚙️ Miscellaneous Tasks

- Do not show default value for --help (_lud_)

## [0.4.0] - 2024-06-15

### 🚀 Features

- Format boolean defaults in --help (_lud_)
- Preserve options order in help doc (_lud_)
- Allow arguments to specify type of string, integer or float (_lud_)

## [0.3.2] - 2024-06-14

### 📚 Documentation

- Document the ProcessShell module (_lud_)

## [0.3.1] - 2024-03-11

### ⚙️ Miscellaneous Tasks

- Update README.md version on release (_lud_)

## [0.3.0] - 2024-03-11

### 🚀 Features

- [**breaking**] Boolean options do not default to false anymore (_lud_)

### 🧪 Testing

- Added tests for the --help option (_lud_)

## [0.2.1] - 2023-12-30

### ⚙️ Miscellaneous Tasks

- Added changelog (_lud-wj_)

## [0.2.0] - 2023-12-30

### 🚀 Features

- Allow functions to define option defaults (_lud-wj_)

## [0.1.1] - 2022-12-11

