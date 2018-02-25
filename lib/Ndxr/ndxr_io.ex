defmodule ExWtf.NdxrIO do
  require Logger
  use Timex
  import ExWtf.PathHelper
  @block_size 256 * 1024

  @doc ~S"""
  Recursively descends the directory tree.
  relpath is a directory relative to the catalog path.
  """
  def walk_path(caller_pid, %Ndxr.Catalog{} = catalog, relpath) do
    relpath = clean_path(normalize_relpath(relpath))
    fullpath = full_path(catalog, relpath)
    Logger.info("Walking path: (#{catalog.name}) #{catalog.path} - #{inspect(relpath)}")


    # The directory may have been renamed or deleted since we started
    if File.exists?("#{fullpath}") do
      # split the directory and file names, filter incs and excs
      {dirs, files} = get_paths(catalog, fullpath)

      # create the Ndxr.Directory struct for this directory and it's files
      {:ok, ndxr_directory} = build_directory(catalog, relpath, files, dirs)

      Logger.debug("ndxr_directory: #{inspect(ndxr_directory)}")

      # if we're testing, we'll be in the same process
      # replace with Registry dispatcher?
      if self() != caller_pid do
        # notify about our new directory
        Logger.debug("Notifying added directory for #{inspect(ndxr_directory.relpath)}")
        :ok = GenServer.call(caller_pid, {:add_directory, ndxr_directory}, 60000)
      end

      # append each subdir to the current relpath, and recurse
      Enum.each(ndxr_directory.subdirs, fn subdir ->
        subdirpath = normalize_relpath("#{relpath}/#{subdir}")
        :ok = walk_path(caller_pid, catalog, subdirpath)
      end)
    else
      Logger.error("#{fullpath} does not exist")
    end

    :ok
  end

  @doc ~S"""
  Takes the catalog, the current path, the File.Stat for
  all of the files, and the subdir File.Stats and converts
  them into a %Ndxr.Directory with %Ndxr.Files
  """
  def build_directory(catalog, relpath, filestats, subdirstats) do
    relpath = normalize_relpath(relpath)
    clean_fullpath = full_path(catalog, relpath)

    newfilestats = Enum.map(filestats, &convert_file_fstat(catalog, &1))

    Logger.debug("subdirstats: #{inspect(subdirstats)}")

    # creates subdir column entries,
    # stripping the catalog path, relative path, etc.
    subdirs =
      Enum.map(subdirstats, & &1.path)
      |> Enum.map(fn sub ->
        tmp = Path.relative_to(sub, clean_fullpath)

        tmp
      end)
      |> Enum.map(&normalize_relpath(&1))

    Logger.debug("build_directory subdirs: #{inspect(subdirs)}")

    fixed_relpath = normalize_relpath(strip_catpath(catalog, relpath))

    {
      :ok,
      %Ndxr.Directory{
        relpath: fixed_relpath,
        name: Path.basename(relpath),
        files: newfilestats,
        subdirs: subdirs,
        qcksum: cksum_directory(newfilestats)
      }
    }
  end

  def convert_filespecs(catalog) do
    excs =
      for {:ok, reg} <- Enum.map(catalog.exclude, &:glob.compile(&1)) do
        reg
      end

    incs =
      for {:ok, reg} <- Enum.map(catalog.include, &:glob.compile(&1)) do
        reg
      end

    {incs, excs}
  end

  @doc ~S"""
  incs and excs are arrays of compiled globs
  """
  def filter_path(path, incs, excs) do
    with false <- Enum.any?(excs, fn e -> :glob.matches(path, e) end),
         true <- Enum.any?(incs, fn i -> :glob.matches(path, i) end) do
      true
    else
      _ -> false
    end
  end

  @doc ~S"""
  if it gets an error, it ignores it
  """
  def get_fstats(paths) do
    # ignore paths that give an error
    Enum.map(paths, fn p ->
      case File.stat(p) do
        {:ok, fstat} ->
          %{path: p, fstat: fstat}

        val ->
          Logger.warn("Fstat failed. Ignoring path #{inspect(p)}. #{inspect(val)}")
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  @doc ~S"""
  returns {dirs, files} filtered by includes and excludes in path
  files are fstats
  """
  def get_paths(catalog, path) do
    # get everything in the base path
    paths = Path.wildcard("#{path}/*")

    {incs, excs} = convert_filespecs(catalog)
    okpaths = Enum.filter(paths, &filter_path(&1, incs, excs))

    get_fstats(okpaths)
    |> Enum.split_with(&(&1.fstat.type == :directory))
  end

  @doc ~S"""
  Takes fstat output for a file and converts to 
   - Strips the filename to it's basename
   - Removes the catalog path to create the relpath (shouldn't it just use the directory?)
   - converts size, and datetimes to UTC
   - calcs qcksum
   - gets mimetype
  """
  def convert_file_fstat(catalog, stat) do
    fstat = stat.fstat

    # if the file has been deleted or renamed, it'll stop here
    {:ok, qsum} = qcksum_filepath(stat.path, fstat.size)

    mtype = :mimerl.filename(stat.path)
    
    %Ndxr.File{
      name: Path.basename(stat.path),
      relpath: normalize_relpath(Path.relative_to(stat.path, Path.expand(catalog.path))),
      # strip_catpath(catalog, stat.path),
      size: fstat.size,
      modified: convert_dtime(fstat.mtime),
      created: convert_dtime(fstat.ctime),
      qcksum: qsum,
      mimetype: mtype
    }
  end

  defp convert_dtime(ctime) do
    Timex.format!(Timex.to_datetime(ctime, "Etc/UTC"), "{ISO:Extended:Z}")
  end

  def qcksum_filepath(filepath, bytecount) do
    bytes_to_read = Enum.min([bytecount, @block_size])

    case File.open(filepath) do
      {:ok, f} ->
        bytes = IO.binread(f, bytes_to_read)

        ret = cksum(bytes)

        File.close(f)
        {:ok, ret}

      {:error, err} ->
        msg = :file.format_error(err)
        Logger.error("qcksum: #{filepath}: #{msg}")
        {:ok, "error calculating"}
    end
  end

  defp cksum(bytes) do
    hash = :crypto.hash_init(:sha256)

    hash = :crypto.hash_update(hash, bytes)
    hash = :crypto.hash_final(hash)

    hash
    |> Base.encode16()
    |> String.downcase()
  end

  defp cksum_directory(file_entry_list) do
    hash = :crypto.hash_init(:sha256)

    hash =
      Enum.reduce(file_entry_list, hash, fn fentry, hash ->
        :crypto.hash_update(hash, fentry.qcksum)
      end)

    hash = :crypto.hash_final(hash)

    hash
    |> Base.encode16()
    |> String.downcase()
  end
end
