## Watching orderbook events:
I have written a method which will track events as they happen on the orderbook:

1. The watchOrderbook method tracks the orderbook smart contract for any event.
When a new event is received, that is, a new offer is submitted to the orderbook,
it refreshes the orderbook to add the new event:

**watchOrderbook() { <br/>
let app = this; <br/>
var contractOB = new <br/>
app.watchweb3.eth.Contract(this.OrderbookABI.abi,this.OrderbookABI. 
address);** <br/>

I start by instantiating our orderbook contract through the watchweb3 web3
object.

2. Next, I get the latest block number from the blockchain. watchOrderbook
starts watching for events after the orderbook is initialized and set for the first
time. Thus, it starts watching from the block, after which the app is initialized:

**app.watchweb3.eth.getBlockNumber(function(error,response){ <br/>
if(response) <br/>
{ <br/>
let lastBlock = response;** <br/>

3. Next, I use the web3 object to track all the events on our orderbook contract
instance:

**contractOB.events.allEvents({ <br/>
fromBlock: lastBlock+1 }, <br/>
function(error, event){ <br/>
console.log("Event",event); <br/>
app.setOrderbook(); <br/>
}).on('error', console.error);** <br/>

I track all events from the orderbook contract after the block where the listener is first
initialized. Any time there is a new event, the listener logs a new event to the console and
calls the setOrderbook method in order to set the orderbook again.
