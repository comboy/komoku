defmodule Komoku.Util do
  def ecto_to_ts(datetime) do
   datetime 
     |> Ecto.DateTime.to_erl
     |> :calendar.datetime_to_gregorian_seconds
     |> Kernel.-(:calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}))
     |> Kernel.+(datetime.usec / 1_000_000)
  end

end
