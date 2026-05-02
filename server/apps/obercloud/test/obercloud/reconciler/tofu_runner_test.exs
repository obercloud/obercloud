defmodule OberCloud.Reconciler.TofuRunnerTest do
  use ExUnit.Case, async: true
  alias OberCloud.Reconciler.TofuRunner

  test "writes HCL, runs binary, captures output" do
    {:ok, result} = TofuRunner.run(~s(resource "null" "x" {}), ["init"])
    assert result.exit_code == 0
    assert is_binary(result.stdout)
  end
end
