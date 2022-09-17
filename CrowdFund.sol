// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Import IERC20 token , source from: https://solidity-by-example.org/
import "./IERC20.sol";

contract CrowdFund {

    // Specifying events to call at the end of the functions:
    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );

    event Cancel(uint id);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    event Claim(uint id);
    event Refund(uint indexed id, address indexed caller, uint amount);


    // Defining the Campaign Struct to base all campaigns:
    struct Campaign {
        address creator;
        uint goal;
        uint pledged;
        uint32 startAt;
        uint32 endAt;
        bool claimed;
    }
    
    IERC20 public immutable token;      // Defining the token immutable so that it cannot be changed.
    uint public count;      // Defining a count variable to count each time a Campaign has been created.
    mapping(uint => Campaign) public campaigns;     // Creating a mapping for all campaigns by id.
    mapping(uint => mapping(address => uint)) public pledgedAmount;     // Creating a mapping for the amount that each address pledged by id.

    // Initializing the IERC20 token with constructor as soon as deployed:
    constructor(address _token) {
        token = IERC20(_token);
    }

    // Function to launch a new campaign:
    function launch(
        uint _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        require(_startAt <= block.timestamp, "start at < now");     // Start time was elpased.
        require(_endAt <= _startAt, "end at < start at");       // Start time must be greater then end time
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");  // Setting a max duration for campaign as 90 days.
       
        count +=1;      // Counting the campaigns to assign id's.
        
        // Assigning the campaign to campaigns array with index of count:
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        // Emit the launch event:
        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }
    
    
    // Function to cancel the not yet started campaign,  only by the owner of the campaign.
    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creator");
        require(block.timestamp < campaign.startAt, "started");
        delete campaigns[_id];
        emit Cancel(_id);       // Emit the Cancel event.
    }

    // Function to pledge to a campaign with campaign id and amount to be pledged:
    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "not started");        // Require the campaign to be started to pledge.
        require(block.timestamp <= campaign.endAt, "ended");        // Require the campaign is not ended to pledge.
    
        campaign.pledged += _amount;        // Pledge the amount to campaign.
        pledgedAmount[_id][msg.sender] += _amount;      // Update the amount that has been pledged for the id of campaign and sender address.
        token.transferFrom(msg.sender, address(this), _amount);     // Transfer amount from sender to campaign.

        emit Pledge(_id, msg.sender, _amount);      // Emit Pledge event.
    }

    // Function to unpledge from a campaign with campaign id and amount to be unpledged.
    function unpledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "ended");        // Require the campaign has not ended.

        campaign.pledged -= _amount;        // Substract the amount from campaign
        pledgedAmount[_id][msg.sender] -= _amount;      // Update the pledged amount of campaign of id for sender address.
        token.transfer(msg.sender, _amount);        // Transfer amount from campaign to sender address.

        emit Unpledge(_id, msg.sender, _amount);        // Emit Unpledge event.
    }

    // Function to claim amount if goal amount is reached, only claimable if unclaimed, address is the creator of the campaign and the campaign has ended.
    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creator");     // Require the address to be the creator of the campaign.
        require(block.timestamp > campaign.endAt, "not ended");     // Require the campaign has ended.
        require(campaign.pledged >= campaign.goal, "pledged < goal");       // Require the goal amount of campaign has been reached.
        require(!campaign.claimed, "claimed");      // Require the campaign is unclaimed.

        campaign.claimed = true;        // Set the campaign to claimed.
        token.transfer(msg.sender, campaign.pledged);       // Transfer all amount of campaign to campaign creator address.

        emit Claim(_id);        // Emit Claim event.
    }

    // Refund function for pledgers to the campaign:
    function refund(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "not ended");     // Require the campaign has ended.
        require(campaign.pledged < campaign.goal, "pledged >= goal");       // Require the campaign goal is not reached.

        uint bal = pledgedAmount[_id][msg.sender];      // Get the total amount that was pledged for this address and campaign and set it to bal variable.
        pledgedAmount[_id][msg.sender] = 0;         // Set the pledged amount of user to 0 for the campaign.     
        token.transfer(msg.sender, bal);        // Transfer bal to sender address.

        emit Refund(_id, msg.sender, bal);      // Emit Refund event.

    }
}
