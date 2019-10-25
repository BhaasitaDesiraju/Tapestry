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
    #For each GUID, get all the other GUIDs in the map
    guidList = Map.values(guidMap)
    createRoutingTables(guidMap, guidList)
    #For message routing -> for each node select a random destination and make

    #Route messages and print Max Hops
    maxHops = routeMsgToDestination(guidMap, guidList, numOfNodes, numOfRequests, [])
    IO.puts("Max Hops = #{maxHops}")
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
      Project3.updateRoutingTable(processId, map)
    end)

  end

  def getProcessIdKey(map, value) when value != nil do
    key = Enum.find(map, fn {key,val} -> val == value end) |> elem(0)
    key
  end

  def getRowMap(list, sourceNode, map, level) when level >= 0 and level < 8 do
    #send entire list
    map = getColumnMap(list, map, level, sourceNode)
    #filter list to get values matching with source node
    filter = String.slice(sourceNode, 0, level+1)
    newList = getNewList(list, filter,level+1, [])
    #self call and increase level
    getRowMap(newList, sourceNode, map, level+1)
  end

  def getRowMap(list, sourceNode, map, level) when level == 8 do
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
  def getColumnMap(list, map, row, sourceNode) when list != [] or nil do
    [head | tail] = list
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    #head and compare it with the source node and place it in  the map
    placer = String.at(head, row)
    #get the hexEquivalent of placer - y
    column = hexEquivalent[placer]
    #update map {row, y} with head
    value = Map.get(map, {row,column})
    # value = value ++ [head]
    value = if value == [] or nil do
      value = [head]
    else
      checker1 = hexEquivalent[String.at(head, row+1)]
      checker2 = hexEquivalent[String.at(List.first(value), row+1)]
      sourceChecker = hexEquivalent[String.at(sourceNode, row+1)]
      if sourceChecker - checker1 < sourceChecker - checker2 do
        value = [head]
      else
        value
      end
    end

    map = Map.put(map, {row, column}, value)
    #If there is one digit matching, place it in the correspoding position of the map
    #recursively call getMap with the updated list
    getColumnMap(tail, map, row, sourceNode)
    #until list is empty
    #when list is empty-return the map
  end

  #Column Map when list is empty
  def getColumnMap(list, map, row, sourceNode) do
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

  def routeMsgToDestination(guidMap, guidList, numOfNodes, numOfRequests, maxHopsList) when numOfRequests != 0 do
    #for each node(process Id) in guidMap, select a random destination node
    hopsList = []
    maxHops = iterateGUIDList(guidList, guidList, hopsList, guidMap, numOfNodes)
    maxHopsList = maxHopsList ++ [maxHops]
    # IO.inspect(maxHopsList)
    Process.sleep(1000)
    routeMsgToDestination(guidMap, guidList, numOfNodes, numOfRequests-1, maxHopsList)
  end

  def routeMsgToDestination(guidMap, guidList, numOfNodes, numOfRequests, maxHopsList) do
    maxHops = Enum.max(maxHopsList)
    maxHops
  end

  def iterateGUIDList(guidList, iterateGuidList, hopsList, guidMap, numOfNodes) when iterateGuidList != [] or nil do
    sourceNode = List.first(iterateGuidList)
    routinglist = List.delete(guidList, sourceNode)
    sourceProcessId = getProcessIdKey(guidMap, sourceNode)
    destinationNode = Enum.random(routinglist)
    getRoutingPath(sourceNode, destinationNode, guidMap)
    hopCount = getHopCount(sourceProcessId)
    hopsList = addHopsToList(hopsList, hopCount, numOfNodes)
    iterateGuidList = List.delete(iterateGuidList, sourceNode)
    iterateGUIDList(guidList, iterateGuidList, hopsList, guidMap, numOfNodes)
  end

  def iterateGUIDList(guidList, iterateGuidList, hopsList, guidMap, numOfNodes) do
    listLength = length(hopsList)
    maxHops = if listLength == numOfNodes do
      maxHops = getMaxHops(hopsList, guidMap)
      end
    maxHops
  end
  def addHopsToList(hopsList, hopCount, numOfNodes) do
    hopsList = hopsList ++ [hopCount]
  end

  def getMaxHops(hopsList, guidMap) do
    maxHops = Enum.max(hopsList)
    #set hop counts of each process Id to 0
    setHopCount(guidMap)
    maxHops
  end

  #Get routing path gets an intermediate node until that is equal to dest
  #when it's equal to destination - same func will update hop count
  #else it'll keep calling itself until source == destination

  def getRoutingPath(sourceNode, destinationNode, guidMap) do
    destNodeLength = String.length(destinationNode)
    getIntermediateNode(sourceNode, "", destinationNode, guidMap, 0, destNodeLength)
  end

  def getIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength) when row < destNodeLength and intermediateNode == "" or nil do
    sourceProcessId = getProcessIdKey(guidMap, sourceNode)
    sourceRoutingTable = getRoutingTable(sourceProcessId)
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    column = hexEquivalent[String.at(destinationNode, row)]
    intermediateNode = List.first(Map.get(sourceRoutingTable, {row,column}))
    # IO.inspect(intermediateNode)
    checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength)
  end

  def getIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength) when row < destNodeLength and intermediateNode != "" or nil do
    intermediateProcessId = getProcessIdKey(guidMap, intermediateNode)
    intermediateRoutingTable = getRoutingTable(intermediateProcessId)
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    column = hexEquivalent[String.at(destinationNode, row)]
    intermediateNode = List.first(Map.get(intermediateRoutingTable, {row,column}))
    # IO.inspect(intermediateNode)
    checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength)
  end

  def checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength) when intermediateNode != destinationNode do
    sourceProcessId = getProcessIdKey(guidMap, sourceNode)
    intermediateNode = getIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row+1,  destNodeLength)
    updateHopCount(sourceProcessId, 1)
  end

  def checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength) when intermediateNode == destinationNode do
    sourceProcessId = getProcessIdKey(guidMap, sourceNode)
    updateHopCount(sourceProcessId, 1)
  end

  def getRoutingTable(processId) do
    GenServer.call(processId, {:GetRoutingTable})
  end

  @impl true
  def handle_call({:GetRoutingTable}, _from, state) do
    {nodeId, routingTable, processId, hops} = state
    {:reply, routingTable, state}
  end

  def getHopCount(processId) do
    GenServer.call(processId, {:GetHopCount})
  end

  @impl true
  def handle_call({:GetHopCount}, _from, state) do
    {nodeId, routingTable, processId, hops} = state
    {:reply, hops, state}
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

  def updateHopCount(processId, hopCount) do
    GenServer.cast(processId, {:UpdateHopCount, hopCount})
  end

  @impl true
  def handle_cast({:UpdateHopCount, hopCount}, state) do
    {node_id, routing_table, processId, hops} = state
    hops = hops + hopCount
    state = {node_id, routing_table, processId, hops}
    {:noreply, state}
  end

  def setHopCount(guidMap) do
    processIdsList = Map.keys(guidMap)
    Enum.each(processIdsList, fn i ->
      GenServer.cast(i, {:SetHopCount, 0})
    end)
  end

  @impl true
  def handle_cast({:SetHopCount, newHopCount}, state) do
    {node_id, routing_table, processId, hops} = state
    hops = newHopCount
    state = {node_id, routing_table, processId, hops}
    {:noreply, state}
  end

end
