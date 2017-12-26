# ExWtf

"Where's That File?", written in Elixir.

Scans and stores file metadata to a database. It takes the name, path, a few file attributes, 
and a naive checksum and stores it in a Postgres table.

The work is divided into "catalogs", and then further into directories.

A catalog is a directory, and all it's subdirectories. Each catalog gets it's own worker.

The catalogs are configured via json. The specific file is specified in config.exs.

This is the latest version. I have similar scripts, written in several languages,
which do the same thing, and more. I use the data to help keep track of what is on removable disks. This version is pretty bland, 
with no special bells and whistles.

There is no reporting, or anything like that. If you want to use the collected data, then
feel free to dive into the tables. They aren't complicated.

Written to teach myself Elixir.

An example of usage can be found in ```qrun.exs```

Running this in debug mode will create huge log files in the .\log directory.

## Installation

Clone the repo.
```
mix deps.get
mix deps.compile
iex -S mix
```

Configure logging to your taste. I recommend ConEmu.

Update config.exs with the correct database settings. I'm using Postgres,
but others should work fine, too.

Update wtf_config.json to include desired directories. Includes and excludes are simple 
globs. By default, it will scan the current directory, only.

Within iex:
```
import_file("qrun.exs")
CliMain.load()
```