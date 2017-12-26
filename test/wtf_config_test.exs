defmodule WtfConfigTest do
  use ExUnit.Case, async: false
  require Logger


  test "don't load file" do
    assert {:error, _} = WtfConfig.load("expected failure")
  end

  test "open file" do
    # assert {:ok, _ } = WtfConfig.load()
    assert WtfConfig.load() ==
             {
               :ok,
               %{
                 catalogs: [
                   %{
                     exclude: ["*.git"],
                     fstype: "local",
                     include: ["*"],
                     name: "Current directory",
                     path: "./"
                   },
                   %{
                     exclude: ["*.git"],
                     fstype: "local",
                     include: ["*"],
                     name: "Projects",
                     path: "d:/data/projects/elixir"
                   }
                 ]
               }
             }
  end
end