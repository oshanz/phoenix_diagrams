defmodule ExDiag.Loader do
  @moduledoc """
  Scans a directory of `.exs` diagram metadata files and reads each
  one's referenced `.mmd` source into a list of entry maps.
  """

  @type entry :: %{
          key: String.t(),
          group: String.t(),
          name: String.t(),
          source: String.t(),
          type: :mermaid | :plantuml
        }

  @type error_entry :: %{
          key: String.t(),
          group: String.t() | nil,
          name: String.t() | nil,
          error: String.t(),
          file: String.t()
        }

  @spec scan(String.t()) :: [entry() | error_entry()]
  def scan(path) do
    path
    |> Path.join("**/*.exs")
    |> Path.wildcard()
    |> Enum.map(&load_file/1)
  end

  defp load_file(file) do
    case eval_file(file) do
      {:error, message} ->
        error_entry(file, nil, nil, message)

      {:ok, opts} ->
        build_entry(file, opts)
    end
  end

  defp eval_file(file) do
    {opts, _bindings} = Code.eval_file(file)
    {:ok, opts}
  rescue
    e -> {:error, "failed to evaluate #{file}: #{Exception.message(e)}"}
  end

  defp build_entry(file, opts) when is_list(opts) do
    group = Keyword.get(opts, :group)
    name = Keyword.get(opts, :name)
    source_path = Keyword.get(opts, :source)

    cond do
      is_nil(group) ->
        error_entry(file, group, name, "missing required key :group in #{file}")

      is_nil(name) ->
        error_entry(file, group, name, "missing required key :name in #{file}")

      is_nil(source_path) ->
        error_entry(file, group, name, "missing required key :source in #{file}")

      true ->
        read_source(file, group, name, source_path)
    end
  end

  defp build_entry(file, _opts) do
    error_entry(file, nil, nil, "#{file} did not evaluate to a keyword list")
  end

  defp read_source(file, group, name, source_path) do
    case source_type(source_path) do
      {:error, message} ->
        error_entry(file, group, name, message)

      {:ok, type} ->
        case File.read(source_path) do
          {:ok, source} ->
            %{key: file, group: group, name: name, source: source, type: type}

          {:error, reason} ->
            message = "could not read source file #{source_path}: #{:file.format_error(reason)}"
            error_entry(file, group, name, message)
        end
    end
  end

  defp source_type(source_path) do
    case Path.extname(source_path) do
      ".mmd" -> {:ok, :mermaid}
      ".puml" -> {:ok, :plantuml}
      ext -> {:error, "unsupported diagram source extension #{inspect(ext)} in #{source_path}"}
    end
  end

  defp error_entry(file, group, name, message) do
    %{key: file, group: group, name: name, error: message, file: file}
  end
end
