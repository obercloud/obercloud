defmodule OberCloud.Reconciler.TofuRunner do
  @moduledoc "Runs OpenTofu in a temp working dir."

  def run(hcl_content, args, env \\ []) do
    tmp = System.tmp_dir!() |> Path.join("ober-tofu-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    try do
      File.write!(Path.join(tmp, "main.tf"), hcl_content)
      bin = Application.fetch_env!(:obercloud, :tofu_binary)
      {output, exit_code} = System.cmd(bin, args, cd: tmp, env: env, stderr_to_stdout: true)
      {:ok, %{exit_code: exit_code, stdout: output, workdir: tmp}}
    rescue
      e -> {:error, e}
    after
      File.rm_rf(tmp)
    end
  end
end
