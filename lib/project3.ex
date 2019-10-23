defmodule Project3 do
  use GenServer

  def main(args) do

    #create nodeList
    numOfNodes = Enum.at(args, 0) |> String.to_integer()
    numOfRequests = Enum.at(args, 1) |> String.to_integer()

    nodeList = createNodes(numOfNodes)

    table = :ets.new(:table, [:named_table, :public])
    :ets.insert(table, {"hop_count", 0})

    #hashtable - map nodeIds to GUIDs
    #For each process id in the nodeList, create a hash value
    map = createGUIDs(nodeList)
    # IO.inspect(map)

    #Routing table
    #For each node - create a routing table taking all the GUIDs into consideration
    #Genserver

    #For each GUID, get all the other GUIDs in the map
    guidList = Map.values(map)
    # IO.inspect(guidList)
    routingTables = createRoutingTables(guidList)
    #Use pattern matching to place them in different levels
    #multi dimensional array - map of maps - 0 9, a - f columns; 40 rows - 0-39 levels



    #For message routing -> for each node select a random destination and make

    #compute max hops

  end

  def createNodes(numOfNodes) do
    Enum.map((1..numOfNodes), fn(x)->
      processId = start_node()
      allotProcessId(processId, x)
      processId
    end)
  end

  def createGUIDs(nodeList) do
    nodesWithIndex = nodeList |> Enum.with_index
    newMap = Enum.map(nodesWithIndex, fn ({value,key}) -> {value, :crypto.hash(:sha, to_string(key)) |> Base.encode16 |> String.downcase} end)
    map = Enum.into(newMap, %{})
    map
  end

  def createRoutingTables(guidList) do
    Enum.each(guidList, fn x ->
      routinglist = List.delete(guidList, x)


      #Genserver call for routing table of each node
      Project2.updateRoutingTable(x, guidList)
    end)

  end

  @impl true
  def init([]) do
    {:ok, {0, 0, [], 1}} #{nodeId, count, adjList, w}
  end

  #Client
  def start_node() do
    {:ok, processId} = GenServer.start_link(__MODULE__, [])
    processId
  end

  def allotProcessId(processId, nodeId) do
    GenServer.call(processId, {:AllotProcessId, nodeId})
  end

  @impl true
  def handle_call({:AllotProcessId, nodeId}, _from, state) do
    {node_id, count, adjList, w} = state
    state = {nodeId, count, adjList, w}
    {:reply, nodeId, state}
  end

end
