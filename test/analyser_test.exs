defmodule AnalyserTest do
  use ExUnit.Case
  doctest Analyser

  test "greets the world" do
    assert Analyser.hello() == :world
  end
end
