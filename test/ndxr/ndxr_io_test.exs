defmodule ExWtf.NdxrIOTest do
  use ExUnit.Case, async: false
  require Logger
  doctest ExWtf

  import ExWtf.NdxrIO
  import ExWtf.PathHelper

  setup do
    # "D:\\Data\\projects\\elixir\\ex_wtf\\testdata",
    catalog_rel = %Ndxr.Catalog{
      name: "Testdata directory",
      path: ".\\testdata",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }

    catalog_abs = %Ndxr.Catalog{
      name: "Testdata directory",
      path: "D:\\Data\\projects\\elixir\\ex_wtf\\testdata",
      include: ["*"],
      exclude: ["*.git"],
      fstype: "local"
    }

    %{
      catalog_rel: catalog_rel,
      catalog_abs: catalog_abs
    }
  end

  @tag :skip
  test "walk path", %{catalog_rel: catalog} do
    assert :ok == walk_path(self(), catalog, "./")
  end

  test "build one directory", %{catalog_rel: catalog_rel, catalog_abs: catalog_abs} do
    relpath = "./"
    relpath = clean_path(normalize_relpath(relpath))
    fullpath = full_path(catalog_rel, relpath)

    {dirs, files} = get_paths(catalog_rel, fullpath)

    correct =
      {:ok,
       %Ndxr.Directory{
         files: [
           %Ndxr.File{
             created: "2017-12-20T00:59:13Z",
             mimetype: "text/plain",
             modified: "2017-12-20T00:59:13Z",
             name: "testdata.txt",
             qcksum: "43ad68a2eb4e56f0171361d82d08307103546feceb38d0b85a7d25814b340089",
             relpath: "./testdata.txt",
             size: 30
           }
         ],
         name: ".",
         qcksum: "c81e68d120be7062ecbe8a5516bb7787597e55b2176ac07a6b32b292fe05ffe2",
         relpath: "./",
         subdirs: ["./subdir", "./whatever", "./whatever - Copy123"]
       }}

    assert build_directory(catalog_rel, relpath, files, dirs) == correct
  end

  test "build one subdir", %{catalog_rel: catalog_rel, catalog_abs: catalog_abs} do

    relpath = "./whatever"
    relpath = clean_path(normalize_relpath(relpath))
    fullpath = full_path(catalog_rel, relpath)

    {dirs, files} = get_paths(catalog_rel, fullpath)

    correct =
      {:ok,
       %Ndxr.Directory{
         files: [
           %Ndxr.File{
             created: "2017-12-20T00:59:13Z",
             mimetype: "text/plain",
             modified: "2017-12-20T00:59:13Z",
             name: "whatever.txt",
             qcksum: "117fd1d1adbb10b7f8fea7827a95b371dcf4ddd6fd6f1da10d12adfab7292d40",
             relpath: "./whatever/whatever.txt",
             size: 25
           }
         ],
         name: "whatever",
         qcksum: "5e227dff8fea9c435c979af16d202e3552b291e982b54af6c4d291670c5164ea",
         relpath: "./whatever",
         subdirs: ["./another_whatever", "./whatever_subdir"]
       }}

    assert build_directory(catalog_rel, relpath, files, dirs) == correct
    
  end
end
