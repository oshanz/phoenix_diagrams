defmodule ExDiagTest do
  use ExUnit.Case
  doctest ExDiag

  test "greets the world" do
    assert ExDiag.hello() == :world
  end
end
