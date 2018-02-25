defmodule WtfConfig do
  require Logger

  def load(filename) do
    Logger.info("Loading config file #{filename}")

    with {:ok, file} <- File.open(filename),
         data <- IO.binread(file, :all),
         :ok <- File.close(file),
         {:ok, config} <- Poison.Parser.parse(data, keys: :atoms) do
      config = struct(WtfConfigData, config)
      {:ok, config}
    else
      {:error, err} ->
        msg = :file.format_error(err)
        Logger.error("Error opening file '#{filename}': #{msg}")
        {:error, msg}

      e ->
        Logger.error("Unexpected error: #{inspect(e)}")
    end
  end
end
