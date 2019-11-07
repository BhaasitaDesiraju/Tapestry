defmodule Project3 do
  use GenServer

  def main(args) do

    #Create nodeList
    numOfNodes = Enum.at(args, 0) |> String.to_integer()
    numOfRequests = Enum.at(args, 1) |> String.to_integer()
    #Create Number of Nodes -1 nodes(actors)
    numOfNodes = numOfNodes - 1
    nodeList = createNodes(numOfNodes)

    #Map Nodes to GUIDS(For each process id in the nodeList, create a hash value)
    guidMap = createGUIDs(nodeList)
    #List of all GUIDs
    guidList = Map.values(guidMap)
    #Create Routing table for every node
    createRoutingTables(guidMap, guidList)

    #For Dynamic node addition create a new node and allot it process ID
    newNode = start_node()
    newNumOfNodes = numOfNodes + 1
    allotProcessId(newNode, newNumOfNodes)

    # Add the new node to the list of Nodes
    nodeList = nodeList ++ [newNode]
    newNodeHash = :crypto.hash(:sha, to_string(newNumOfNodes-1)) |> Base.encode16 |> String.downcase |> String.slice(0..7)
    guidMap = Map.put(guidMap, newNode, newNodeHash)
    guidList = Map.values(guidMap)
    #Update routing tables of every node with the dynamic node
    updateRoutingTables(guidMap, guidList, newNodeHash)

    # Route messages and print Max Hops
    maxHops = routeMsgToDestination(guidMap, guidList, newNumOfNodes, numOfRequests, [])
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

  def updateRoutingTables(guidMap, guidList, newNodeHash) do
    #Create the dynamic node's routing table
    routinglist = List.delete(guidList, newNodeHash)
    routingTable = empty_map(8,16)
    map = getRowMap(routinglist, newNodeHash, routingTable, 0)
    newNodeProcessId = getProcessIdKey(guidMap, newNodeHash)
    Project3.updateRoutingTable(newNodeProcessId, map)

    #Update every nodes'routing table with respect to the dynamic node
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    Enum.each(routinglist, fn x ->
      sourceProcessId = getProcessIdKey(guidMap, x)
      sourceRoutingTable = getRoutingTable(sourceProcessId)
      #get the row based on the number of matching digits
      matchingLevel =  Enum.find_index(0..7, fn i -> String.at(x, i) != String.at(newNodeHash, i) end)
      placer = String.at(newNodeHash, matchingLevel)
      #get the hcolumn based on the concerned digit of the node
      column = hexEquivalent[placer]

      value = Map.get(sourceRoutingTable, {matchingLevel,column})
      value = if value == [] or nil do
        value = [newNodeHash]
      else
        checker1 = hexEquivalent[String.at(newNodeHash, matchingLevel+1)]
        checker2 = hexEquivalent[String.at(List.first(value), matchingLevel+1)]
        sourceChecker = hexEquivalent[String.at(x, matchingLevel+1)]
        if sourceChecker - checker1 < sourceChecker - checker2 do
          value = [newNodeHash]
        else
          value
        end
      end

      sourceRoutingTable = Map.put(sourceRoutingTable, {matchingLevel, column}, value)
      Project3.updateRoutingTable(sourceProcessId, sourceRoutingTable)
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
    #Iterate recursively for every row of the routing table
    getRowMap(newList, sourceNode, map, level+1)
  end

  def getRowMap(list, sourceNode, map, level) when level == 8 do
    map
  end

  def getNewList(list, filter, level, newList) when list != [] or nil do
    [head | tail] = list
    #Get the matching digits for sorting the nodes in their respective rows
    regex = String.slice(head, 0, level)
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

  def getColumnMap(list, map, row, sourceNode) when list != [] or nil do
    #Iterate through every node in the routing nodelist
    [head | tail] = list
    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    #compare the current node with the source node and place it in the routing table
    placer = String.at(head, row)
    column = hexEquivalent[placer]
    #update the routing table of the sourec node with the current node
    value = Map.get(map, {row,column})

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
    getColumnMap(tail, map, row, sourceNode)
  end

  #return Column Map when routinglist is empty
  def getColumnMap(list, map, row, sourceNode) do
    map
  end

  def empty_map(size_x, size_y) do
    Enum.reduce(0..size_x-1, %{}, fn x, acc ->
      Enum.reduce(0..size_y-1, acc, fn y, acc ->
        Map.put(acc, {x, y}, [])
      end)
    end)
  end

  #recursively send messages for 'number of requests' times
  def routeMsgToDestination(guidMap, guidList, numOfNodes, numOfRequests, maxHopsList) when numOfRequests != 0 do
    hopsList = []
    maxHops = iterateGUIDList(guidList, guidList, hopsList, guidMap, numOfNodes)
    maxHopsList = maxHopsList ++ [maxHops]
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

    if intermediateNode != nil do
      checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength)
    end

  end

  def getIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength) when row < destNodeLength and intermediateNode != "" or nil do
    intermediateProcessId = getProcessIdKey(guidMap, intermediateNode)
    intermediateRoutingTable = getRoutingTable(intermediateProcessId)

    hexEquivalent = %{"0"=>0, "1"=>1, "2"=>2, "3"=>3, "4"=>4, "5"=>5, "6"=>6, "7"=>7, "8"=>8, "9"=>9, "a"=>10, "b" =>11, "c"=>12, "d"=>13, "e"=>14, "f"=>15}
    column = hexEquivalent[String.at(destinationNode, row)]
    intermediateNode = List.first(Map.get(intermediateRoutingTable, {row,column}))

    if intermediateNode != nil do
      checkIntermediateNode(sourceNode, intermediateNode, destinationNode, guidMap, row, destNodeLength)
    end
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
