defmodule ExWtf.NdxrIOTest do
  use ExUnit.Case, async: false
  require Logger
  doctest ExWtf

  import ExWtf.NdxrIO

  setup do
    {:ok, config} = WtfConfig.load("wtf_config_test.json")
    # this is separate from the test catalog below
    one_catalog = struct(Ndxr.Catalog, (hd(config[:catalogs])))

    name = {:via, Registry, {Ndxrs, one_catalog.name}}


    {:ok, _} = ExWtf.Ndxr.start_link(one_catalog, name: name)

    %{
      config: config,
      name: name,
      catalog: %Ndxr.Catalog{
        exclude: [".git", ".gitlike", "*blah*"],
        path: "testdata/"
      },
      one_catalog: one_catalog
    }
  end

  test "map paths", %{catalog: catalog} do
    filelist = [
      "./whatever",
      "./whatever/.git",
      "./subdir",
      ".git",
      ".git/somefile.txt",
      "./borf.txt",
      "thisblahfile.txt",
      "./subdir/another.txt"
    ]


    correct = MapSet.new(
      ["./borf.txt", "./subdir", "./whatever", "./subdir/another.txt"]
    )

    # ExWtf.Ndxr.walk_path(cat, "testdata", fn(dir) -> dir end)
    {incs, excs} = convert_filespecs(catalog)
    assert false == filter_path(".gitlike", incs, excs)
    assert true == filter_path("whatev.txt", incs, excs)

    {dirs, files} = get_paths(catalog, "")
    assert Enum.count( dirs ) == 2
    assert Enum.count(files) == 1


    catalog = %Ndxr.Catalog{catalog | include: ["*.txt"]}

  end

  test "walk path (direct)", %{one_catalog: one_catalog} do
    catalog = cond do
      ("" == one_catalog.path or "." == one_catalog.path) ->
        %Ndxr.Catalog{one_catalog | path: "./"}
      true -> one_catalog
    end

    assert {:ok, _} = walk_path(catalog, "")

  end

  @tag :quick
  test "quick NdxrIO" do
    # {:ok, _} = Registry.register(CatalogNotify, "add_directory", :dummy)

  end

end
