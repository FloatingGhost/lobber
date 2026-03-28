defmodule Lobber.Skills do
  @moduledoc """
  Functions for interacting with the skills system
  skills are basically just markdown files in priv/ for now
  """

  defp skill_dir() do
    Lobber.Config.priv_path("skills")
  end

  defp list_skills() do
    skill_dir()
    |> File.ls!()
    |> Enum.filter(fn name -> String.ends_with?(name, ".md") end)
  end

  def format() do
    list_skills()
    |> Enum.map_join("\n", fn f ->
      skill_dir()
      |> Path.join(f)
      |> File.read!()
    end)
  end
end
