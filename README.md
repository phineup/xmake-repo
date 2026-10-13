# xmake-repo

Public [xmake](https://xmake.io) package repository maintained by Phineup.

## Use

In your project's `xmake.lua`:

```lua
add_repositories("phineup https://github.com/phineup/xmake-repo.git master")
add_requires("dummy")

target("app")
    set_kind("binary")
    add_files("src/*.c")
    add_packages("dummy")
```

Or globally:

```bash
xmake repo --add phineup https://github.com/phineup/xmake-repo.git master
xmake repo -u
```

**Always pass `master`.** Without a branch, xmake clones the default branch, which is
`development` and contains unreleased package changes. `master` is the stable snapshot;
you can also pin a release tag: `add_repositories("phineup <url> v1.0.0")`.

## Packages

| package | description | configs |
|---|---|---|
| `ratelimitd` | C++17 client SDK for the [ratelimitd](https://github.com/phineup/ratelimitd) rate limiting sidecar | `headeronly` (default `false`), `shared`, `debug`, `vs_runtime` |

```lua
add_requires("ratelimitd")                                  -- compiled static library
-- add_requires("ratelimitd", {configs = {shared = true}})      -- shared library
-- add_requires("ratelimitd", {configs = {headeronly = true}})  -- header-only (libcurl is still linked)

set_languages("c++17")
target("app")
    set_kind("binary")
    add_files("src/*.cpp")
    add_packages("ratelimitd")
```

## Layout

```
packages/
└── <first letter>/<package name>/xmake.lua
scripts/test.sh            # build + test one package: scripts/test.sh dummy
```

## Add a package

1. Create `packages/<first letter>/<name>/xmake.lua` (see `packages/d/dummy`).
2. Get the archive hash with `xmake l hash.sha256 <file>` and add it via `add_versions`.
3. Run `scripts/test.sh <name>`.
4. Open a PR against `development` (see [CONTRIBUTING.md](CONTRIBUTING.md)).

Private packages do not belong here: keep them in a separate private repository and add both with `add_repositories`.

## Contributing

PRs target `development`; commits must be signed off (`git commit -s`). Details in [CONTRIBUTING.md](CONTRIBUTING.md).
Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
