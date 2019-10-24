defmodule Project3Test do
  use ExUnit.Case
  doctest Project3

  # test "columnMap" do
    # assert Project3.getRowMap(["b6589fc6", "356a192b", "da4b9237", "77de68da", "1b645389", "ac3478d6",
    # "c1dfd96e", "902ba3cd", "fe5dbbce", "0ade7c2c"], "b6589fc6", %{
    #   {0, 0} => [],
    #   {0, 1} => [],
    #   {0, 2} => [],
    #   {0, 3} => [],
    #   {0, 4} => [],
    #   {0, 5} => [],
    #   {0, 6} => [],
    #   {0, 7} => [],
    #   {0, 8} => [],
    #   {0, 9} => [],
    #   {0,10} => [],
    #   {0, 11} => [],
    #   {0, 12} => [],
    #   {0, 13} => [],
    #   {0, 14} => [],
    #   {0, 15} => [],
    #  }, 0) == %{}
  # end

  test "main" do
    assert Project3.main(["10", "10"]) == "hello"
  end
end
