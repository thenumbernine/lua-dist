Ok so my typical model is `$dir/` then `distinfo` in the dir and that says where to install files, and asserts that the install dir is named the same as the distinfo dir.

But what about external projects, i.e. luarocks/rockspecs, that don't have a distinfo file?

That's where this comes in.

It will work similar to the extra `.distinfo` files for external projects that are stashed in my github.io's `lua/` folder.
