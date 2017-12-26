defmodule WtfConfig do
    require Logger

    def load(filename \\ "wtf_config.json") 
    do
        Logger.debug("Loading config file #{filename}")
        with {:ok, file} <- File.open(filename),
             data <- IO.binread(file, :all),
             :ok <- File.close(file),
             {:ok, config} <- Poison.Parser.parse(data, keys: :atoms)
        do
            {:ok, config}
        else
            {:error, err} ->
                msg = :file.format_error(err)
                Logger.error("Error opening file '#{filename}': #{msg}")
                {:error, msg}
            e -> Logger.error("Unexpected error: #{inspect(e)}")
        end
    end
end