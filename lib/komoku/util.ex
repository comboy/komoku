defmodule Komoku.Util do
  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  def ecto_to_ts(datetime) do
   datetime 
     |> Ecto.DateTime.to_erl
     |> :calendar.datetime_to_gregorian_seconds
     |> Kernel.-(@epoch)
     |> Kernel.+(datetime.usec / 1_000_000)
  end

  def ts_to_ecto(ts) do
    {:ok, datetime} =  ts 
    |> round
    |> Kernel.+(@epoch)
    |> :calendar.gregorian_seconds_to_datetime
    |> Ecto.DateTime.cast
    usec = ((ts - Float.floor(ts)) * 1_000_000) |> round
    %{datetime | usec: usec}
  end

  # Return current timestamp
  def ts, do: :os.system_time(:micro_seconds) / 1_000_000

end
