defmodule Ndxr.PathHelperTest do
  use ExUnit.Case, async: false
  require Logger
  doctest ExWtf

  import ExWtf.PathHelper

  setup do
    catalog = %Ndxr.Catalog{
      name: "Testdata directory",
      path: "D:\\data\\projects\\elixir\\ex_wtf\\testdata",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }

    %{
      catalog: catalog
    }
  end

  test "strip catpath", %{catalog: catalog} do
    Logger.configure(level: :debug)
    assert "" == strip_catpath(catalog, "d:\\data\\projects\\elixir\\ex_wtf\\testdata")
    assert "blah" == strip_catpath(catalog, "d:\\data\\projects\\elixir\\ex_wtf\\testdata\\blah")

    assert "test.txt" ==
             strip_catpath(catalog, "d:\\data\\projects\\elixir\\ex_wtf\\testdata\\test.txt")
  end

  test "full path", %{catalog: catalog} do
    assert "d:/data/projects/elixir/ex_wtf/testdata/meh" == full_path(catalog, "meh")
    assert "d:/data/projects/elixir/ex_wtf/testdata/meh" == full_path(catalog, "./meh")
    assert "d:/data/projects/elixir/ex_wtf/testdata/meh" == full_path(catalog, "/meh")
    assert "d:/data/projects/elixir/ex_wtf/testdata" == full_path(catalog, "")
  end

  test "clean paths" do
    assert "./fakepath" == clean_path(".//./fakepath")
  end

  test "expand path", %{catalog: catalog} do
    assert "d:/data/projects/elixir/ex_wtf/testdata" == full_path(catalog, "")
    assert "d:/data/projects/elixir/ex_wtf/testdata" == full_path(catalog, "./")
  end
end
