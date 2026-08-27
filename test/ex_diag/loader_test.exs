defmodule ExDiag.LoaderTest do
  use ExUnit.Case, async: true

  alias ExDiag.Loader

  @fixtures Path.join(__DIR__, "../support/fixtures/ex_diag")

  test "loads a valid diagram entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "valid"))

    assert entry.group == "Backend"
    assert entry.name == "System Overview"
    assert entry.source =~ "graph TD"
    assert entry.key =~ "overview.exs"
    refute Map.has_key?(entry, :error)
  end

  test "missing required key produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "missing_key"))

    assert entry.group == "Backend"
    assert entry.name == nil
    assert entry.error =~ "missing required key :name"
    assert entry.file =~ "broken.exs"
  end

  test "missing source file produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "missing_source"))

    assert entry.group == "Backend"
    assert entry.name == "Missing Source"
    assert entry.error =~ "could not read source file"
  end

  test "eval error in the exs file produces an error entry" do
    [entry] = Loader.scan(Path.join(@fixtures, "eval_error"))

    assert entry.group == nil
    assert entry.name == nil
    assert entry.error =~ "failed to evaluate"
  end

  test "a mix of valid and invalid files loads both, isolated from each other" do
    entries = Loader.scan(Path.join(@fixtures, "mixed"))

    assert length(entries) == 2
    good = Enum.find(entries, &(&1.name == "Good One"))
    bad = Enum.find(entries, &Map.has_key?(&1, :error))

    assert good.source =~ "graph TD"
    assert bad.error =~ "missing required key :source"
  end

  test "missing directory returns an empty list" do
    assert Loader.scan(Path.join(@fixtures, "does_not_exist")) == []
  end
end
