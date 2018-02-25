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

Install Elixir (assuming debian)
```
wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
sudo dpkg -i erlang-solutions_1.0_all.deb
sudo apt update
sudo apt install esl-erlang
sudo apt install elixir
```

Clone the repo, then compile the application.
```
mix local.hex --force
mix local.rebar --force
mix deps.get
mix deps.compile
```
Update ```config.exs``` with the correct database settings. I'm using Postgres,
but others should work fine, too.

Configure logging to your taste. I recommend ConEmu.

Update ```wtf_config.json``` with appropriate settings. Includes and excludes are simple 
globs.

Then, you can run it with:
```
mix run run.exs
```

For a distributed node, use:
```
elixir --erl "-name ndxr" -S mix run run.exs
elixir --sname ndxr -S mix run run.exs
```
