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
    guidMap = createGUIDs(nodeList)
    # IO.inspect(guidMap)

    #Routing table
    #For each node - create a routing table taking all the GUIDs into consideration
    #Genserver

    #For each GUID, get all the other GUIDs in the map
    guidList = Map.values(guidMap)
    # IO.inspect(guidList)
    createRoutingTables(guidMap, guidList)
    # IO.inspect(routingTables)
    #For message routing -> for each node select a random destination and make
    messageRouting = routeMsgToDestination(guidMap, guidList)
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
    newMap = Enum.map(nodesWithIndex, fn ({value,key}) -> {value, :crypto.hash(:sha, to_string(key)) |> Base.encode16 |> String.downcase |> String.slice(0..7)} end)
    map = Enum.into(newMap, %{})
    map
  end

  def createRoutingTables(guidMap, guidList) do
    Enum.each(guidList, fn x ->
      routinglist = List.delete(guidList, x)
      #creating an empty map with 8 rows and 16 columns
      routingTable = empty_map(8,16)
      map = getRowMap(routinglist, x, routingTable, 0)
      #Genserver call for routing table of each node
      processId = getProcessIdKey(guidMap, x)
      # IO.inspect(x)
      # IO.inspect(processId)
      # IO.inspect(map)
      Project3.updateRoutingTable(processId, map)
      # Process.sleep(1000)
    end)

  end

  def getProcessIdKey(map, value) do
    key = Enum.find(map, fn {key,val} -> val == value end) |> elem(0)
    key
  end

  def getRowMap(list, sourceNode, map, level) when level >= 0 and level < 8 do
    #send entire list
    map = getColumnMap(list, map, level)
    #filter list to get values matching with source node
    filter = String.slice(sourceNode, 0, level+1)
    newList = getNewList(list, filter,level+1, [])
    #self call and increase level
    getRowMap(newList, sourceNode, map, level+1)
  end

  def  getRowMap(list, sourceNode, map, level) when level == 8 do
    map
  end

  def getNewList(list, filter, level, newList) when list != [] or nil do
    [head | tail] = list
    # regex = Regex.compile(filter) |> Tuple.to_list |> Enum.at(1)
    regex = String.slice(head, 0, level)
    # newList = []
    newList = if regex == filter do
      newList = newList ++ [head]
    else
      newList
    end
    getNewList(tail, filter, level, newList)
  end

  def getNewList(list, filter, level, newList) do
    newList
  end

  #Column Map when list is not empty
  def getColumnMap(list, map, row) when list != [] or nil do
    [head | tail] = list
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    #head and compare it with the source node and place it in  the map
    placer = String.at(head, row)
    #get the hexEquivalent of placer - y
    column = hexEquivalent[placer]
    #update map {row, y} with head
    value = Map.get(map, {row,column})
    value = value ++ [head]
    map = Map.put(map, {row, column}, value)
    #If there is one digit matching, place it in the correspoding position of the map
    #recursively call getMap with the updated list
    getColumnMap(tail, map, row)
    #until list is empty
    #when list is empty-return the map
  end

  #Column Map when list is empty
  def getColumnMap(list, map, row) do
    #when list is empty-return the map
    map
  end

  def empty_map(size_x, size_y) do
    Enum.reduce(0..size_x-1, %{}, fn x, acc ->
      Enum.reduce(0..size_y-1, acc, fn y, acc ->
        Map.put(acc, {x, y}, [])
      end)
    end)
  end

  def routeMsgToDestination(guidMap, guidList) do
    #for each node(process Id) in guidMap, select a random destination node
    Enum.each(guidList, fn sourceNode ->
      routinglist = List.delete(guidList, sourceNode)

      #this should happen as many times as the num of requests

      #select a random node from the routingList
      destinationNode = Enum.random(routinglist)
      # IO.inspect(destinationNode)
      #compare the source guid and dest guid
      matchingLevel = Enum.find_index(0..7, fn i-> String.at(sourceNode, i) != String.at(destinationNode, i) end)
      if matchingLevel == nil do
        7
      else
        matchingLevel
      end
      sourceProcessId = getProcessIdKey(guidMap, sourceNode)
      sourceRoutingTable = getRoutingTable(sourceProcessId)
      hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
      #Get the column value from the destination string
      placer = String.at(destinationNode, matchingLevel)
      column = hexEquivalent[placer]
      intermediateNode = Map.get(sourceRoutingTable, {matchingLevel,column})
      # IO.inspect(intermediateNode)
    end)
  end

  def getRoutingTable(processId) do
    GenServer.call(processId, {:GetRoutingTable})
  end

  def handle_call({:GetRoutingTable}, _from, state) do
    {nodeId, routingTable, processId, hops} = state
    {:reply, routingTable, state}
  end

  @impl true
  def init([]) do
    {:ok, {0, %{}, self(), 0}} #{nodeId,routingTable, processId, hops}
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
    {node_id, routingTable, processId, hops} = state
    state = {nodeId, routingTable, processId, hops}
    {:reply, nodeId, state}
  end

  def updateRoutingTable(processId, routingTable) do
    GenServer.cast(processId, {:UpdateRoutingTable, routingTable})
  end

  @impl true
  def handle_cast({:UpdateRoutingTable, routingTable}, state) do
    {node_id, routing_table, processId, hops} = state
    state = {node_id, routingTable, processId, hops}
    # IO.inspect(state)
    {:noreply, state}
  end

end
