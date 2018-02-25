defmodule ExWtfMain do
  @moduledoc """
  ExWtf main Application
  """

  use Application
  require Logger

  @doc """
  Main entry point
  """

  def start(_type, args) do
    Logger.debug("Starting ExWtf application with args #{inspect(args)}")
    Supervisor.start_link(__MODULE__, args, name: ExWtf)
  end

  def init(args) do
    with {:ok, config} <- load_config(args) do
      #config = struct(WtfConfigData, config)
      children = [
        %{
          id: ExWtf,
          start: {ExWtf, :start_link, [config, [name: __MODULE__]]}
        }
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      {:error, msg} -> Logger.error(msg)
      true -> {:error}
    end
  end

  defp load_config(args) do
    filename =
      case args[:config_file] do
        nil ->
          {:error, "No config file specified"}

        filename ->
          {:ok, filename}
      end

    # Logger.info("Loading config from #{filename}")

    with {:ok, filename} <- filename,
         {:ok, config} <- WtfConfig.load(filename) do
      Logger.debug(inspect(config))
      {:ok, config}
    else
      {:error, msg} ->
        {:error, msg}

      err ->
        Logger.error(inspect(err))
        err
    end
  end
end

defmodule ExWtf do
  @moduledoc """
  Supervises the children for the indexer
  """
  use Supervisor
  require Logger

  def start_link(%WtfConfigData{} = config, opts) do    
    Logger.info("Starting ExWtf supervisor: #{inspect(config)}, #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, config, opts)
  end

  # def init(config) do
  def init(config) do
    catndxr = %{
      id: ExWtf.CatalogNdxrs,
      start: {ExWtf.CatalogNdxrs, :start_link, [config, []]}
    }
    children = [
      {Registry, keys: :unique, name: Ndxrs},
      # {Registry, keys: :duplicate, name: CatalogNotify},
      # {Task.Supervisor, name: DbTasks},
      catndxr,
      {DynamicSupervisor, name: NdxCatalogSupervisor, strategy: :one_for_one},
      EctoStorage
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_id(catalog_name) do
    {:via, Registry, {Ndxrs, catalog_name}}
  end
end

