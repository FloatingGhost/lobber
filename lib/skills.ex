defmodule Lobber.Skills do
  @dir "priv/skills"

  defp list_skills() do
    File.ls!(@dir)
    |> Enum.filter(fn name -> String.ends_with?(name, ".md") end)
  end

  def format() do
    list_skills()
    |> Enum.map_join("\n", fn f ->
      @dir
      |> Path.join(f)
      |> File.read!()
    end)
  end
end
