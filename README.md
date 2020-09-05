# Termelot

> Cross-platform cell-based terminal library.

**WARNING**: This library is currently *vaporware*! Many features are not yet
fully implemented.

See more on implementation progress in the project board!
https://github.com/minierolls/termelot/projects/1

## Design

**Termelot** is intended to be easy to work with for both library users and
backend implementors!

All definitions and functionality are accessible with a single import of
`termelot.zig`. Handling events is as easy as registering a few callbacks!

If you find a platform where **Termelot** does not yet run, the minimal
backend interface is quick to implement. Additionally, there are no worries
of synchronization/thread-safe use, as the library implementation handles
these problems before calling backend functionality!
