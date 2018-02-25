defmodule ExWtf.PathHelper do
  require Logger

  def normalize_relpath(relpath) do
    relpath = clean_path(relpath)

    relpath =
      case relpath do
        "" -> "./"
        "." -> "./"
        _ -> Path.join(Path.split(relpath))
      end

    relpath =
      case String.starts_with?(relpath, "./") do
        true -> relpath
        false -> "./#{relpath}"
      end

    relpath
  end

  # "path" is a full path
  def strip_catpath(catalog, path) do
    cpath = clean_path(catalog.path)
    npath = clean_path(path)

    stripped = String.replace_prefix(npath, cpath, "")
    stripped = String.replace_prefix(stripped, "/", "")
    clean_path(stripped)
  end

  def full_path(catalog, relpath) do
    catpath = Path.expand(catalog.path)
    relpath = Path.relative(relpath)
    tmp_path = "#{catpath}/#{relpath}"
    
    tmp_path = clean_path(tmp_path)
    tmp_path
  end

  def clean_path(path) do

    path = String.replace(path, "\\", "/")

    path = String.replace(path, "//", "/")
    path = Path.split(path)
    # path = path -- ["."]
    path = Enum.filter(path, fn(p) -> 
      p != "."
    end)

    if [] == path do
      ""
    else
      jpath = Path.join(path)
      # String.replace(jpath, "//", "/")
      jpath
    end
  end
end
