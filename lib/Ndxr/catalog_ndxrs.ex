defmodule ExWtf.CatalogNdxrs do
  @moduledoc """
  Launches and manages per-catalog processes
  """
  require Logger
  use GenServer

  def start_link(%WtfConfigData{} = config, _opts) do
    Logger.info("Starting ExWtf.CatalogNdxrs, config: #{inspect(config)}")
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    names = %{}
    refs = %{}
    pids = %{}
    running_ndxrs = []

    {:ok, %{:config => config, :servers => {names, pids, refs, running_ndxrs}}}
  end

  defp resolve_node(host) do
    case host do
      nil -> Node.self()
      _ -> String.to_atom("ndxr@#{host}")
    end
  end

  # client calls
  def run(host \\ nil) do   
    node = resolve_node(host)
    GenServer.cast({ExWtf.CatalogNdxrs, node}, :run)
  end

  def start_catalog(%Ndxr.Catalog{} = catalog) do
    GenServer.cast(ExWtf.CatalogNdxrs, {:start_catalog, catalog})
  end

  def stop_catalog(%Ndxr.Catalog{} = catalog) do
    GenServer.cast(ExWtf.CatalogNdxrs, {:stop_catalog, catalog})
  end

  def catalog_complete(%Ndxr.Catalog{} = catalog) do
    GenServer.cast(ExWtf.CatalogNdxrs, {:ndx_complete, catalog})
  end

  def get_catalog_pid(%Ndxr.Catalog{} = catalog) do
    GenServer.call(ExWtf.CatalogNdxrs, {:get_catalog_pid, catalog})
  end

  def ndxr_status(%Ndxr.Catalog{} = catalog) do
    GenServer.call(ExWtf.CatalogNdxrs, {:ndxr_status, catalog})
  end

  def start_ndxr(%Ndxr.Catalog{} = catalog) do
    Logger.info("Ndxing catalog #{inspect(catalog.name)}")
    GenServer.cast(ExWtf.CatalogNdxrs, {:start_ndxr, catalog})
  end

  # implementation

  defp del_catalog(servers, name, pid, ref) do
    with {names, pids, refs, running_ndxrs} <- servers do
      Logger.info("deleting: #{inspect(servers)}")
      Process.demonitor(ref)
      {_, nrefs} = Map.pop(refs, ref)
      {_, npids} = Map.pop(pids, pid)
      nnames = Map.delete(names, name)
      nrunning = running_ndxrs -- [name]
      nservers = {nnames, npids, nrefs, nrunning}
      Logger.info("deleted: #{inspect(nservers)}")
      {:ok, nservers}
    end
  end

  defp del_catalog_name(servers, catalog) do
    with {names, _, _, _} <- servers do
      name = catalog.name

      if Map.has_key?(names, name) do
        {pid, ref} = Map.get(names, name)
        del_catalog(servers, name, pid, ref)
      else
        {:error, "Server name not found"}
      end
    end
  end

  defp del_catalog_ref(servers, ref) do
    with {_, _, refs, _} <- servers do
      if Map.has_key?(refs, ref) do
        {name, pid} = Map.get(refs, ref)
        del_catalog(servers, name, pid, ref)
      else
        {:error, "Server reference not found"}
      end
    end
  end

  defp stop_catalog_impl(servers, catalog) do
    {names, _, _, _} = servers

    if Map.has_key?(names, catalog.name) do
      {pid, _} = Map.get(names, catalog.name)

      case del_catalog_name(servers, catalog) do
        {:ok, nservers} ->
          :ok = DynamicSupervisor.terminate_child(NdxCatalogSupervisor, pid)
          {:ok, nservers}

        {:error, emsg} ->
          {:error, emsg}
      end
    else
      {:error, "Not running?"}
    end
  end

  defp start_catalog_impl(servers, %Ndxr.Catalog{} = catalog) do
    Logger.info("Starting catalog #{inspect(catalog.name)}")

    with {names, pids, refs, running_ndxrs} <- servers do
      name = catalog.name

      cspec = %{
        id: ExWtf.Ndxr,
        start: {ExWtf.Ndxr, :start_link, [catalog]}
      }

      {:ok, pid} = DynamicSupervisor.start_child(NdxCatalogSupervisor, cspec)

      ref = Process.monitor(pid)
      nnames = Map.put(names, name, {pid, ref})
      npids = Map.put(pids, pid, {name, ref})
      nrefs = Map.put(refs, ref, {name, pid})
      {:ok, {nnames, npids, nrefs, running_ndxrs}}
    end
  end

  defp run_impl(%WtfConfigData{} = config, servers) do
    Logger.debug("config: #{inspect(config)}")
    Logger.debug("servers: #{inspect(servers)}")

    servers =
      Enum.reduce(config.catalogs, servers, fn cat, svrs ->
        Logger.info("Starting catalog #{inspect(cat.name)}")
        {:ok, nsrvrs} = start_catalog_impl(svrs, struct(Ndxr.Catalog, cat))
        nsrvrs
      end)

    servers =
      Enum.reduce(config.catalogs, servers, fn cat, svrs ->
        Logger.info("Starting ndxr for catalog #{inspect(cat.name)}")
        {:ok, nsrvrs} = start_ndxr_impl(svrs, struct(Ndxr.Catalog, cat))
        nsrvrs
      end)

    {:ok, servers}
  end

  defp start_ndxr_impl(servers, %Ndxr.Catalog{} = catalog) do
    with {names, pids, refs, running_ndxrs} <- servers do
      if not Map.has_key?(names, catalog.name) do
        Logger.error("Catalog process not running for #{catalog.name}")
        {:error, "Catalog process not running for #{catalog.name}"}
      else
        running_ndxrs = running_ndxrs ++ [catalog.name]
        {pid, _} = Map.get(names, catalog.name)
        :ok = GenServer.cast(pid, {:ndx_catalog})
        {:ok, {names, pids, refs, running_ndxrs}}
      end
    end
  end

  # server callbacks

  def handle_call(msg, _from, state) do
    case msg do
      # {:stop_catalog, catalog} ->
      #  Logger.info("Received call to stop catalog")
      #  {:ok, nservers} = stop_catalog_impl(servers, catalog)
      #  {:reply, {:ok, nservers}, nservers}

      {:status} ->
        Logger.info("Received call for status")
        {_, _, _, running_ndxrs} = state.servers
        Logger.info("Running catalogs: #{inspect(running_ndxrs)}")
        {:reply, {:ok, running_ndxrs}, state}

      {:ndxr_status, catalog} ->
        Logger.info("Received call for #{catalog.name} ndxr status")
        {_, _, _, running_ndxrs} = state.servers
        v = Enum.find(running_ndxrs, fn ndx -> ndx == catalog.name end)

        {:reply, {:ok, v}, state}

      {:get_catalog_pid, catalog} ->
        Logger.info("Received call for catalog pid for catalog #{inspect(catalog.name)}")
        {names, _, _, _} = state.servers
        ret = Map.get(names, catalog.name)

        if nil == ret do
          Logger.error("Catalog #{catalog.name} not found")
          Logger.error("CatalogNdxr state: #{inspect(state.servers)}")
          {:reply, {:error, "Catalog #{catalog.name} not found"}, state.servers}
        else
          {pid, _} = ret
          {:reply, {:ok, pid}, state}
        end

      _ ->
        Logger.error("Received unexpected call: #{inspect(msg)}")
        {:reply, {:error, "Unknown message"}, state}
    end
  end

  def handle_cast(msg, state) do
    case msg do
      :run ->
        Logger.warn("Received cast to start running catalogs")
        {:ok, nservers} = run_impl(state.config, state.servers)
        {:noreply, %{state | :servers => nservers}}

      {:ndx_complete, catalog} ->
        Logger.info("Received cast that ndxing is complete for catalog #{inspect(catalog.name)}")
        {names, pids, refs, running_ndxrs} = state.servers
        nndxrs = running_ndxrs -- [catalog.name]

        {:noreply, %{state | :servers => {names, pids, refs, nndxrs}}}

      {:start_catalog, catalog} ->
        Logger.info("Received cast to start catalog")
        {:ok, nservers} = start_catalog_impl(state.servers, catalog)
        {:noreply, %{state | :servers => nservers}}

      {:stop_catalog, catalog} ->
        Logger.info("Received cast to stop catalog")
        {:ok, nservers} = stop_catalog_impl(state.servers, catalog)
        {:noreply, %{state | :servers => nservers}}

      {:start_ndxr, catalog} ->
        Logger.info("Received cast to start ndxr")
        {:ok, nservers} = start_ndxr_impl(state.servers, catalog)
        {:noreply, %{state | :servers => nservers}}

      _ ->
        Logger.error("Received unexpected cast: #{inspect(msg)}")
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    with {_, _, refs, _} <- state.servers do
      case msg do
        {:DOWN, ref, _, pid, _} ->
          Logger.info("Catalog stopped #{inspect(pid)}, #{inspect(ref)}")

          if Map.has_key?(refs, ref) do
            Logger.error("Catalog crashed #{inspect(pid)}, #{inspect(ref)}")
            Logger.error("Current state: #{inspect(state.servers)}")
            {:ok, nservers} = del_catalog_ref(state.servers, ref)
            Logger.debug("nservers: #{inspect(nservers)}")
            {:noreply, %{state | :servers => nservers}}
          else
            {:noreply, state}
          end

        _ ->
          Logger.warn("Received unexpected info message: #{inspect(msg)}")
          {:noreply, state}
      end
    end
  end
end
