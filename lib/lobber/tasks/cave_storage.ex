defmodule Lobber.Tasks.CaveStorage do
  @behaviour Quantum.Storage

  require Logger
  import Crontab.CronExpression

  use GenServer

  @persistence "cron_state.json"

  @initial_state %{
    last_execution_date: nil,
    jobs: []
  }

  def start_link(opts) do
    Logger.info("Starting cave cron...")
    GenServer.start_link(__MODULE__, load(), opts)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  defp maybe_prepend_mod("Elixir." <> _mod = mod), do: mod
  defp maybe_prepend_mod(mod), do: "Elixir.#{mod}"

  defp decode_job(%{"task" => task, "schedule" => schedule, "state" => state} = job) do
    Lobber.Tasks.Scheduler.new_job()
    |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!(schedule))
    |> Quantum.Job.set_task({String.to_existing_atom(maybe_prepend_mod(task)), :run, []})
    |> Quantum.Job.set_state(String.to_existing_atom(state))
  end

  defp decode_time(nil), do: nil

  defp decode_time(s) do
    NaiveDateTime.from_iso8601!(s)
  end

  defp persist({:reply, _code, state} = repl) do
    {:ok, data} = Jason.encode(state, pretty: true)
    Lobber.Cave.write_to_cave(@persistence, data)
    repl
  end

  defp load() do
    case Lobber.Cave.read_from_cave(@persistence) do
      {:ok, raw} ->
        {:ok, data} = Jason.decode(raw)

        %{
          jobs:
            data
            |> Map.get("jobs", [])
            |> Enum.map(&decode_job/1),
          last_execution_date: decode_time(Map.get(data, "last_execution_date"))
        }

      {:error, _} ->
        @initial_state
    end
  end

  def handle_call({:last_execution_date}, _from, %{last_execution_date: nil} = state),
    do: {:reply, :unknown, state}

  def handle_call({:last_execution_date}, _from, %{last_execution_date: date} = state),
    do: {:reply, date, state}

  def handle_call({:last_execution_date, new_date}, _from, state) do
    {:reply, :ok, %{state | last_execution_date: new_date}}
    |> persist()
  end

  def handle_call({:jobs}, _from, %{jobs: [] = jobs} = state) do
    {:reply, :not_applicable, state}
  end

  def handle_call({:jobs}, _from, %{jobs: jobs} = state) do
    {:reply, jobs, state}
  end

  def handle_call({:add_job, job}, _from, %{jobs: jobs} = state) do
    {:reply, :ok, %{state | jobs: [job | jobs]}}
    |> persist()
  end

  def handle_call({:delete_job, job}, _from, %{jobs: jobs} = state) do
    {:reply, :ok, %{state | jobs: Enum.reject(jobs, fn j -> j == job end)}}
    |> persist()
  end

  def handle_call({:purge}, _from, _state) do
    {:reply, :ok, @initial_state}
    |> persist()
  end

  @impl true
  def last_execution_date(storage_pid) do
    GenServer.call(storage_pid, {:last_execution_date})
  end

  @impl true
  def jobs(storage_pid) do
    GenServer.call(storage_pid, {:jobs})
  end

  @impl true
  def update_last_execution_date(storage_pid, execution_date) do
    GenServer.call(storage_pid, {:last_execution_date, execution_date})
  end

  @impl true
  def add_job(storage_pid, job) do
    GenServer.call(storage_pid, {:add_job, job})
  end

  @impl true
  def purge(storage_pid) do
    GenServer.call(storage_pid, {:purge})
  end

  @impl true
  def delete_job(storage_pid, job) do
    GenServer.call(storage_pid, {:delete_job, job})
  end
end

defimpl Jason.Encoder, for: Quantum.Job do
  def encode(value, opts) do
    {mod, :run, []} = value.task

    %{
      "schedule" => value.schedule,
      "task" => mod,
      "state" => value.state
    }
    |> Jason.Encode.map(opts)
  end
end

defimpl Jason.Encoder, for: Crontab.CronExpression do
  def encode(value, opts) do
    Crontab.CronExpression.Composer.compose(value)
    |> Jason.Encode.string(opts)
  end
end
