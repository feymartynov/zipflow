defmodule Zipflow.Spec.CDHTest do
  use ExUnit.Case, async: true

  alias Zipflow.Spec.CDH

  test "encode returns nil" do
    refute CDH.encode(fn x -> assert is_binary(x); nil end, [])
  end
end
