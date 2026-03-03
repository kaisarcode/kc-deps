# deps

`deps` is the external dependency workspace for the KaisarCode ecosystem.

It exists to fetch, build, cross-compile, and store third-party runtime
libraries outside application repositories.

It is not an app repository and it does not contain `kaisarcode/` sources.

## Layout

- `bin/`: executable project scripts
- `lib/`: compiled dependency outputs using the same naming logic used in
  `kc-apps/lib`
- `log/`: build and publish logs
- `src/`: upstream source trees kept outside app repositories
- `tmp/`: temporary build worktrees

## Install

- `./install-dev.sh`: installs compiled artifacts from `lib/` plus global
  build toolchains under `/usr/local/share/kaisarcode/toolchains`
- `./install.sh`: installs only compiled artifacts from `lib/`

Global toolchain root:

- `/usr/local/share/kaisarcode/toolchains`
- `ndk/android-ndk-r27c`
- `rust/`

## Rule

Applications should consume the compiled outputs produced here.

They should not embed third-party source trees as part of their normal
runtime model.

`src/` is a local fetch area. It is not committed to the repository.
It is only a local build cache.

Compiled outputs in `lib/` are the distributable artifacts and should be
stored through Git LFS.

Application installers should download only the artifacts they need for the
current architecture, install them globally, and avoid duplicating
dependencies that are already present on the target system.
