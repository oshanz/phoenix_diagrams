{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = PhoenixDiagrams.TestEndpoint.start_link()
ExUnit.start()
