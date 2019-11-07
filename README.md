# Project3

**Tapestry Algorithm**

## Group Members
Ananda Bhaasita Desiraju - UFID: 40811191
Nidhi Sharma - UFID: 68431215

## What's Working
Tapestry algorithm has been implemented for dynamic network node joins and routing.
The message from source node travels to the destination node through intermediate nodes. The intermediate nodes are selected by comparing the intermediate node's address with the destination node address (which is a hash value) and increasing the number of matching characters in each hop. The GUID address used in this project is 8-bit long. The maximum number of hops required by the nodes to reach the destination is displayed. Also, each nodes sends the message "number of requests" times.
We have also implemented dynamic node insertion by adding one node dynamically. When the dynamic node is added, the routing table of all the present nodes are updated with respect to the dynamic node and the dynamic node is placed in the correct level of every node after being compared with the values already present in that position.

## Execution Instructions
To Compile and Build:
mix compile 
mix run
mix escript.build
To Execute:
escript project3 numNodes numRequests

## Output
Maximum number of hops (node connections) that must be traversed for all requests for all nodes.

## Observations for largest network
Nodes: 10000
Requests: 50
Max Hops: 6