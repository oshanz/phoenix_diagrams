{:ok, _} = Application.ensure_all_started(:phoenix)
{:ok, _} = ExDiag.TestEndpoint.start_link()
ExUnit.start()
