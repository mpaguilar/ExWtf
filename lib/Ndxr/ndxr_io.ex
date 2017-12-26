defmodule ExWtf.NdxrIO do
  require Logger
  use Timex
  @block_size 256 * 1024

  def convert_filespecs(catalog) do
    excs = for {:ok, reg} <-
                 Enum.map(catalog.exclude, &(:glob.compile(&1)))
      do
      reg
    end
    incs = for {:ok, reg} <-
                 Enum.map(catalog.include, &(:glob.compile(&1)))
      do
      reg
    end

    {incs, excs}
  end

  @doc ~S"""
  incs and excs are arrays of compiled globs
  """
  def filter_path(path, incs, excs) do
    with false <- Enum.any?(excs, fn (e) -> :glob.matches(path, e) end),
         true <- Enum.any?(incs, fn (i) -> :glob.matches(path, i) end)
      do
      true
    else
      _ -> false
    end
  end

  @doc ~S"""
  if it gets an error, it ignores it
  """
  def get_fstats(paths) do
    Enum.map(
      paths,
      fn (p) ->
        case File.stat(p) do
          {:ok, fstat} -> %{path: p, fstat: fstat}
          val ->
            Logger.warn("Ignoring path #{inspect(p)}. #{inspect(val)}")
            nil
        end
      end
    )
    # ignore paths that give an error
    |> Enum.filter(&(&1 != nil))
  end


  @doc ~S"""
  returns filtered {dirs, files} in path
  """
  def get_paths(catalog, path) do
    # get everything in the base path
    paths = Path.wildcard("#{catalog.path}/#{path}/*")

    {incs, excs} = convert_filespecs(catalog)
    okpaths = Enum.filter(paths, &(filter_path(&1, incs, excs)))

    get_fstats(okpaths)
    |> Enum.split_with(&(&1.fstat.type == :directory))
  end

  @doc ~S"""
  curpath is a directory relative to the catalog path.
  Usually called as a task
  """
  def walk_path(%Ndxr.Catalog{} = catalog, curdir) do
    curdir = case curdir do
      "" -> "."
      cdir -> cdir
    end
    Logger.debug("Walking path: (#{catalog.path}) #{inspect(curdir)}")
    File.exists?("#{catalog.path}/#{curdir}")

    # split the directory and file names
    {dirs, files} = get_paths(catalog, curdir)
    {:ok, newdir} = build_directory(catalog, curdir, files, dirs)

    Logger.debug("newdir: #{inspect(newdir)}")

    # notify about our new directory

    Registry.dispatch(
      CatalogNotify,
      "add_directory",
      fn (entries) ->
        for {_, {mod, fun}} <- entries
          do
          apply(mod, fun, [catalog, newdir])
        end
      end
    )

    Enum.each(
      newdir.subdirs,
      fn (dir) ->
        {:ok, _} = walk_path(catalog, "#{dir}")
      end)

    # {:ok, [newdir] ++ [newdirs]}
    {:ok, nil}
  end

  def get_mimetype(ndxrfile, filename) do
    %Ndxr.File{ndxrfile | mimetype: :mimerl.filename(filename)}
  end

  @doc ~S"""
  Takes the catalog, the current path, the File.Stat for
  all of the files, and the subdir File.Stats and converts
  them into a %Ndxr.Directory with %Ndxr.Files
  """
  def build_directory(catalog, path, filestats, subdirstats) do

    newfilestats = Enum.map(filestats, &(convert_file_fstat(catalog, &1)))
                   |> Enum.map(&(qcksum_file(catalog, &1)))
                   |> Enum.map(&(get_mimetype(&1, &1.name)))

    subdirs = Enum.map(subdirstats, &(&1.path))
              |> Enum.map(&(strip_catpath(catalog, &1)))

    Logger.debug("build_directory subdirs: #{inspect(subdirs)}")

    {
      :ok,
      %Ndxr.Directory{
        relpath: strip_catpath(catalog, path),
        name: Path.basename(path),
        files: newfilestats,
        subdirs: subdirs,
        qcksum: cksum_directory(newfilestats)
      }
    }
  end

  defp convert_dtime(ctime) do
    Timex.format!(Timex.to_datetime(ctime, "Etc/UTC"), "{ISO:Extended:Z}")
  end

  def strip_catpath(catalog, path) do
    cpath = case catalog.path do
      "" -> ""
      _ -> String.replace(catalog.path, "\\", "/")
           |> String.replace_leading("./", "")
    end

    case {path, cpath} do
      {p, ""} -> p
      {"", p} -> p
      {p, _} -> String.replace_leading(p, cpath, "")
    end
    |> String.replace_leading("/", "")

  end

  def convert_file_fstat(catalog, stat) do
    fstat = stat.fstat

    %Ndxr.File{
      name: Path.basename(stat.path),
      relpath: strip_catpath(catalog, stat.path),
      size: fstat.size,
      modified: convert_dtime(fstat.mtime),
      created: convert_dtime(fstat.ctime)
    }
  end

  defp cksum(bytes, salt \\ false) do

    hash = :crypto.hash_init(:sha256)
    hash = case salt do
      s when is_number(s) ->
        :crypto.hash_update(hash, salt)
      _ -> hash
    end

    hash = :crypto.hash_update(hash, bytes)
    hash = :crypto.hash_final(hash)

    hash
    |> Base.encode16
    |> String.downcase
  end

  @doc ~S"""

  If salt?, then use the file size for the salt
  """
  def qcksum_file(
        %Ndxr.Catalog{} = catalog,
        %Ndxr.File{} = file,
        salt? \\ false
      )
    do

    bytes_to_read = Enum.min([file.size, @block_size])
    path = "#{catalog.path}/#{file.relpath}"

    {:ok, qhash} = case File.open(path) do
      {:ok, f} ->
        bytes = IO.binread(f, bytes_to_read)
        ret = case salt? do
          true -> cksum(bytes, file.size)
          false -> cksum(bytes)
        end

        File.close(f)
        {:ok, ret}

      {:error, err} ->
        msg = :file.format_error(err)
        Logger.error("qcksum: #{catalog.path}/#{file.relpath}: #{msg}")
        {:ok, "error calculating"}

      error ->
        Logger.error("Some other error: #{inspect(error)}")
        {:ok, "error calculating"}
    end

    %Ndxr.File{file | qcksum: qhash}

  end

  defp cksum_directory(file_entry_list) do
    hash = :crypto.hash_init(:sha256)
    hash = Enum.reduce(
      file_entry_list,
      hash,
      fn (fentry, hash) -> :crypto.hash_update(hash, fentry.qcksum) end
    )
    hash = :crypto.hash_final(hash)

    hash
    |> Base.encode16
    |> String.downcase
  end
end
