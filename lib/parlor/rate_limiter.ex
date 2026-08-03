defmodule Parlor.RateLimiter do
  @moduledoc """
  ETS-backed fixed-window rate limiter.
  """

  use GenServer

  @table :parlor_rate_limiter
  @sweep_interval_ms 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns `true` when the request is within the limit, `false` otherwise.
  """
  @spec allow?(term(), pos_integer(), pos_integer()) :: boolean()
  def allow?(key, limit, window_ms)
      when is_integer(limit) and limit > 0 and is_integer(window_ms) and window_ms > 0 do
    now = System.monotonic_time(:millisecond)
    window_id = div(now, window_ms)
    ets_key = {key, window_id}
    count = :ets.update_counter(@table, ets_key, 1, {ets_key, 0})

    if count <= limit do
      true
    else
      :telemetry.execute(
        [:parlor, :rate_limiter, :deny],
        %{count: count},
        %{key: key, limit: limit, window_ms: window_ms}
      )

      false
    end
  end

  @doc """
  Clears all counters for a key. Useful in tests.
  """
  @spec reset(term()) :: :ok
  def reset(key) do
    :ets.match_delete(@table, {{key, :_}, :_})
    :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    min_window = div(now, 1000) - 120

    :ets.select_delete(@table, [
      {{{:"$1", :"$2"}, :_}, [{:is_integer, :"$2"}, {:<, :"$2", min_window}], [true]}
    ])

    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end
end
