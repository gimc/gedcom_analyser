defmodule Analyser do
  alias Codepagex

  @tag_only ~r/(?<level>\d+)\ (?<tag>\w+)/
  @value ~r/(?<level>\d+)\ (?<tag>\w+)\ (?<value>.*)/
  @identifier ~r/(?<level>\d+)\ @(?<id>[\w\d]+)@\ (?<tag>\w+)/

  def analyse(filename) do
    convert_text = &(Codepagex.to_string(&1, :iso_8859_1))

    transitions =
      File.stream!(filename, [:read, :raw, :binary], :line)
      |> Stream.map(convert_text)
      |> Stream.map(&process_line/1)
      |> Stream.reject(&(&1 == nil))
      |> Enum.reduce({0, "", [], %{}}, fn %{"level" => level, "tag" => tag}, {prev_level, prev_tag, history, transition_map} ->
        cond do
          level == prev_level ->
            parent = peek_stack(history)
            if parent == nil do
              {level, tag, history, transition_map}
            else
              %{"tag" => parent_tag} = parent
              {level, tag, history, Map.update(transition_map, parent_tag, [tag], &(uniq_update(tag, &1)))}
            end
          level > prev_level ->
            new_parent = %{"tag" => prev_tag, "level" => prev_level}
            {level, tag, push_stack(history, new_parent), Map.update(transition_map, prev_tag, [tag], &(uniq_update(tag, &1)))}
          level < prev_level ->
            case pop_stack(history) do
              nil ->
                raise "Attempting to move to an invalid level?"
              {_old_parent, history} ->
                {level, tag, history, transition_map}
            end
        end
      end)
      |> elem(3)

    stringified =
      transitions
      |> Enum.to_list
      |> Enum.map(fn {parent, children} ->
        "#{parent} -> [#{Enum.join(children, ",")}]\n"
      end)

    File.write("output.txt", stringified)
  end

  def uniq_update(value, list) do
    if Enum.member?(list, value), do: list, else: [value|list]
  end

  def process_line({:ok, line}) do
    Regex.named_captures(@value, line, capture: :all_but_first)
  end

  defp push_stack(stack, value), do: [value | stack]
  defp pop_stack([head|rest]), do: {head, rest}
  defp pop_stack([]), do: nil
  defp peek_stack([head|rest]), do: head
  defp peek_stack([]), do: nil

end
