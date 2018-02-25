{:ok, _} = Application.ensure_all_started(:tzdata)
_ = Tzdata.ReleaseUpdater.poll_for_update()


Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
EctoStorage.start_link()
# Mix.Task.run "ecto.create"
# Mix.Task.run("ecto.migrate")

ExUnit.configure(exclude: [:skip])
ExUnit.start()
