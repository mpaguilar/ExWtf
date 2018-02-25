defmodule WtfConfigData do
  defstruct(
    catalogs: []
    # Ndxr.Catalog
  )
end

defmodule Ndxr.Catalog do
  defstruct(
    name: "",
    path: "",
    include: ["**"],
    exclude: [],
    directories: [],
    fstype: "local",
    host: nil
  )
end

defmodule NdxrState do
  defstruct(
    catalog: nil
  )
end

defmodule Ndxr.Directory do
  defstruct(
    relpath: "",
    files: [],
    subdirs: [],
    name: "",
    qcksum: ""
  )
end

defmodule Ndxr.File do
  defstruct(
    name: "",
    relpath: "",
    size: 0,
    mimetype: "",
    modified: DateTime.utc_now(),
    created: DateTime.utc_now(),
    qcksum: ""
  )
end
