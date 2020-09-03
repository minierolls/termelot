# Contributing

Currently, this library is *vaporware*; none of its desired features are fully
implemented. However, if you are interested in contributing to turn this
project into reality *sooner*, then please take a look at the following.

## General Source Control Practices

### Forks/Pull Requests

When maintaining a fork intended for an eventual pull request, **do not run**
`git pull`. Instead, prefer a `rebase` workflow:

```
git fetch upstream --tags
git rebase upstream/master
```

Any `merge` commits should be squashed with an interactive rebase (or ammend).

### Tagging

All commits should be tagged in the subject within angle brackets (`<...>`).
Some example tags include:

- `doc`: Documentation, including comments, README, license, copyright notices,
  and more.
- `feat`: Feature, including new implementations, improved functionality,
  and more.
- `fix`: Fixes, implementation-only changes that do not change the publicly
  exposed functionality or interface.
- `scm`: Source control management, including changes to the build system or
  the repository.
- `break`: Breaking changes; not currently in use as the interface is changing
  frequently for now, but intended to signal a major/breaking API change.

Commits should be self-contained and single-responsibility if possible, with
accompanying summaries and descriptions in the commit message.

## Backend

The easiest way to contribute a backend implementation is to copy all
`unimplemented` files in the `src/backend` folder, and use those as a reference
for your implementation.

Some notes to consider:

- Don't worry about thread safety! The library implementation will guarantee
  thread-safe access to your backend functions.
- You don't have to buffer your `write` functions. The library implementation
  is responsible for buffering and batching content into a single `write` call.
