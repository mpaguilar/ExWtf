defmodule ExWtf.NdxrStorage do
  require Logger
  use Task
  require Model.Catalog

  def start_link(args) do
    Task.start_link(__MODULE__, :add, args)
  end

  def add_directory(%Ndxr.Catalog{} = catalog, %Ndxr.Directory{} = directory) do
    Logger.debug("Adding directory (task) for catalog #{inspect(catalog)}")
    Logger.debug(" *** \nDirectory: #{inspect(directory)}")

    Model.Ndxr.upsert(directory, catalog)
  end

end