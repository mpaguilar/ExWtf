{:ok, _} = Application.ensure_all_started(:tzdata)
_ = Tzdata.ReleaseUpdater.poll_for_update()

Registry.start_link(keys: :unique, name: Ndxrs)
Registry.start_link(keys: :duplicate, name: CatalogNotify)

Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
EctoStorage.start_link()
# Mix.Task.run "ecto.create"
Mix.Task.run "ecto.migrate"


ExUnit.configure exclude: [:quick]
ExUnit.start()
