pragma solidity >=0.5.0 <0.7.0;
/**
 * @title Restate1
 * @dev Register a land for sale
**/
contract Land_Registry {
    address payable owner;
    uint public minimumAsk;
    //uint tokensPerEther = 100;
    uint tokenPriceInWei = 10**18;
    mapping (address => uint) public balances;


    enum PropertyType {LAND, BUILDING, HOUSE}
    //PropertyType choice1;
    PropertyType constant defaultChoice1 =PropertyType.LAND;

    enum PropertyZone {RESIDENTIAL, COMMERCIAL, AGRICULTURE}
    //PropertyZone choice2;
    PropertyZone constant defaultChoice2 =PropertyZone.RESIDENTIAL;


    constructor() public {
        //since deployment is done by owner, msg.sender refers to owner
        owner = msg.sender;
    }

    struct landOwner {
        address addr;
        string name;
        bool registered;
        uint regfee;
        uint estimatedValue;
        bytes32 hashstring;    //proof of ownership e.g title/deed
        uint tokenBal;
        //uint8 propertytcount;
    }

    mapping (address => landOwner) public landOwnerList;
    landOwner[] public listOwners;
    //are events useful here
    //event LandRegistered(address indexed addr, string name, uint amount);
    //event LandDeregistered(address indexed addr, string name, uint amount);
    event TokensBought(uint num);


    struct property {
        address _owner;     //current owner's address
        uint256 _type;      //land , house&land, building
        string location;    //address [map coordinates e.g "15N, 30E"]
        uint256 zone_type;  //commercial, residential, agricultural, etc.
        uint256 lotNum;     //lot number
        uint256 sizeInSqft; //square footage
        bytes32 hashstring; //proof of ownership e.g title/deed
        //uint openBids;    //number of open bids on this property
    }

    mapping (address => property) public propertyList;

    //are events useful here re change of ownership

     struct propertySeeker {
        address addr;
        string name;
        uint feeDeposit;
        uint bidVal;
        bytes32 ownerHash;    //owner's unique identifyer
        uint tokenBal;
    }

    mapping(address => propertySeeker) public propertySeekerList;
    propertySeeker[] public interestedBuyers;

    struct bids {
        address addr;
        string name;
        uint bidVal;
        bytes32 propertyHash;    //property's unique identifyer per owner
        bool accepted;
        uint creationTime;
    }
    mapping(address => bids) public activeBids;
    bids[] public bidsList;
    event Deposit(address indexed _from, uint _value);
    event CustomerBidAccepted(address _from, string _name, uint _bidVal);

    //This function registers a Land owners property
    function registerLand(string memory _name, uint _estimatedValue, string memory _location, uint256 _lotnumber,uint256 _sizeInSqft) public payable{
        require(msg.value >= 1 ether,"Platform requires registration fee of 1 ether");
        balances[msg.sender] = msg.value;
        uint tempBal=buyTokens((msg.value / tokenPriceInWei),false);     //swap Ether for cutom Token
        bytes32 _hash =getHashString(_location, _sizeInSqft, _lotnumber,msg.sender);
        landOwner memory temp =landOwnerList[msg.sender] = landOwner(msg.sender, _name, true, msg.value, _estimatedValue, _hash, tempBal);
        propertyList[msg.sender] = property(msg.sender,uint(defaultChoice1),_location,uint(defaultChoice2),_lotnumber,_sizeInSqft,_hash);
        setAsk(_estimatedValue);
        listOwners.push(temp);

        // remember to implement event listeners here (changing state of data on the blockchain)
    }

    //This function generates a unique identify associated with the property registered
    function getHashString(string memory _location, uint256 _sizeInSqft,uint256 _lotnumber, address _addr) public pure returns(bytes32 result){
        return keccak256(abi.encode(_location,_sizeInSqft,_lotnumber, _addr));
    }

    //This function manages interest in registered property
    function requestPropertyTour(string memory _name,uint _val,uint256 _desiredSize, uint256 _type) public payable{
        address[] memory temp; propertySeeker memory newInterest;
        require(msg.value >= 1 ether,"Platform requires registration fee of 1 ether");
        require(msg.sender == owner,"Only owner of an address can place purchase bid");
        balances[msg.sender] = msg.value;
        uint tempBal=buyTokens((msg.value / tokenPriceInWei),true);     //swap Ether for cutom Token
        //get a list of properties avaialble
        temp = getOwnerProperties(_val);   //find properties that are within desired price range;
        for (uint i=0; i < temp.length; i++){
            if (propertyList[temp[i]].sizeInSqft >=_desiredSize && propertyList[temp[i]]._type ==_type )
            //Register Bid
            newInterest=propertySeekerList[msg.sender] = propertySeeker(msg.sender, _name, msg.value, _val, propertyList[temp[i]].hashstring, tempBal);
            interestedBuyers.push(newInterest);
            transerTokens(propertyList[temp[i]]._owner, 25, true, false, false, false);     //needs prevention of overspend +plus only one payment per owener

            // remember to implement event listeners here (changing state of data on the blockchain)
        }
    }

    //This function initates a bid on a registered property
    function placePropertyBid(string memory _name,uint _val,bytes32 _hashstring, address _landowner) public payable{
        bids memory newBid; uint must_deposit_atleast =(landOwnerList[_landowner].estimatedValue + 1 ether);
        require(msg.value >= must_deposit_atleast,"Platform requires registration fee of 1 Ether + Sellers asking price");
        require(msg.sender == owner,"Only owner of an address can place purchase bid");
        //require( _val >= minimumAsk,"bids below landOwners minimum estimated value are not allowed");
        emit Deposit(msg.sender, msg.value);
        balances[msg.sender] += msg.value;
        uint tempBal=buyTokens((msg.value / tokenPriceInWei),true);     //swap Ether for cutom Token
        delete tempBal;     //find something useful to do with tempBal, perhaps display in UI in ETH 2
        //Register Bid
        //transferTokens(_to, 25, true, false, false, false);  //shouldnt the bid  amount be incentive enough for acceptance?
        newBid=activeBids[msg.sender] = bids(msg.sender, _name, _val, _hashstring,false,block.timestamp);
        bidsList.push(newBid);
    }

    //This function returns registered addresses who own porperties for a listing below or equal to his bid price
    function getOwnerProperties(uint _val) public view returns (address [] memory){
        address[] memory temp;  uint y = 0;
        for (uint i=0; i< listOwners.length; i++){
            if (listOwners[i].estimatedValue <= _val){
             temp[y]=listOwners[i].addr;
             y++;
            }
        }
        return temp;
    }

    //This function returns a list of requests for Tours of the parameterised porperty
    function getInterestedProperty(bytes32 _hashstring) public view returns (address [] memory){
        address[] memory temp;  uint y = 0;
        for (uint i=0; i< interestedBuyers.length; i++){
            if (keccak256(abi.encodePacked(interestedBuyers[i].ownerHash)) == keccak256(abi.encodePacked(_hashstring))){
             temp[y]=interestedBuyers[i].addr;
             y++;
            }
        }
        return temp;
    }

    //This function returns the registered bids on the callers porperties
    function getBids(bytes32 _hashstring) public view returns (address [] memory){
        address[] memory temp;  uint y = 0;
        for (uint i=0; i< bidsList.length; i++){
            if (keccak256(abi.encodePacked(bidsList[i].propertyHash)) == keccak256(abi.encodePacked(_hashstring))){
             temp[y]=listOwners[i].addr;
             y++;
            }
        }
        return temp;
    }

    //This function returns the maximum registered bid on the callers porperties
    function getMaxBid(bytes32 _hashstring) public view returns (address){
        uint previousMaxBid;  uint y = 0;  address[] memory temp; uint maxBidIndex;
        for (uint i=0; i< bidsList.length; i++){
            if (keccak256(abi.encodePacked(bidsList[i].propertyHash)) == keccak256(abi.encodePacked(_hashstring))){
                temp[y]=listOwners[i].addr;
                if (previousMaxBid < bidsList[i].bidVal){
                     previousMaxBid=bidsList[i].bidVal;
                     maxBidIndex=y;
                }
             y++;
            }
        }
        return temp[maxBidIndex];
    }

    //This function maintains the lowest asked value for property in a public variable
    function setAsk(uint _minimumAsk) public {
         require(msg.sender == owner,"Unauthorized access!");
         // only update variable if a new low minimum ask is submitted
         if (minimumAsk > _minimumAsk){
            minimumAsk = _minimumAsk;
         }
    }

    //This function supports transfer of Ether to RealEstate Token "RES"
    function buyTokens(uint tokenNum,bool ifReg) public payable returns (uint allocated) {
       uint actualTokens = msg.value / tokenPriceInWei;
       require(tokenNum <= actualTokens, "You've sent less money than required for buying specified tokens");
       uint balanceInWei = msg. value - (tokenNum * tokenPriceInWei);

       if (ifReg == true){// only update balance if mapping previously exist
            landOwnerList[msg.sender].tokenBal += tokenNum;
       }
       msg.sender.transfer(balanceInWei);
       emit TokensBought(tokenNum);
       return tokenNum;

    }

    // This function returns the tokenBalance of the caller
    function getTokensBalance() public view returns (uint balance){
        return landOwnerList[msg.sender].tokenBal;
    }

    //This function transfers tokens from one party to the other
    //future update: create a ENUM to represent/replace multiple bool parameters
    function transerTokens(address to, uint numTokens, bool to_owner, bool to_realtor, bool to_legal, bool to_surveyor) public {
        require(msg.sender != to, "You cannot send tokens to yourself");
        if (to_owner == true){
            require(numTokens <=  propertySeekerList[msg.sender].tokenBal, "You don't have enough tokens to send!");
            propertySeekerList[msg.sender].tokenBal -= numTokens;
            landOwnerList[to].tokenBal += numTokens;
        } else if (to_realtor){
            //send message to owner indicating interest in seeing property
            //owner or dapp should automatically set up appointment for viewing
            //owner has the choice to pay a realtor or do the meeting himself/herself
            //establish logistics in ETH Part II course

        } else if (to_legal){
            //authorize legal team to start processing the transfer of ownership
            //legal team performs other services like registration of title for owners who do not yet posess title/deed
            //legal team can provide services of verifying all legal documents are in order and valid
            //establish in ETH Part II course
        } else if (to_surveyor){
            //incentivize surveyor to identify/verify boundaries of property
            //legal team performs other services like registration of title for owners who do not yet posess title/deed
            //legal team can provide services of verifying all legal documents are in order and valid
            //establish in ETH Part II course
        } else {
            //incentivize interested parties by offering to cover the fees or donate towards their expences
            //effective offering discounts to initiate purchase in their property
            require(numTokens <=  landOwnerList[msg.sender].tokenBal, "You don't have enough tokens to send!");
            landOwnerList[msg.sender].tokenBal -= numTokens;
            propertySeekerList[to].tokenBal += numTokens;
        }
    }

    //This function updates a unique identify to properties associated with their owner's address, during transfer of ownership
    //It seeks to a) remove land from the registerred properties list up for sale
    //It seeks to b) de-associate property with previous owner and associate with new owner
    function deregisterLand(address _to) public payable {
        require(msg.value >= 1 ether,"Platform requires closing cost fee of minimum 1 ether");
        //generate new owners hash
        bytes32 _hash =getHashString(propertyList[msg.sender].location, propertyList[msg.sender].sizeInSqft, propertyList[msg.sender].lotNum,_to);
        //create new landOwners record but mark property "not for sale" (unregistered), Hence having no estimated value and closing cost fees applied
        landOwnerList[_to] = landOwner(_to, propertySeekerList[_to].name, false, msg.value, 0, _hash,propertySeekerList[_to].tokenBal);
        //create new mapping to land record
        property(_to,uint(defaultChoice1),propertyList[msg.sender].location,uint(defaultChoice2),propertyList[msg.sender].lotNum,propertyList[msg.sender].sizeInSqft,_hash);
        //remove old owners record mapping
        delete landOwnerList[msg.sender];
        //remove old property record mapping
        delete propertyList[msg.sender];
    }

    function acceptPropertyBid() public payable{
        address temp;
        require(owner !=msg.sender ,"you cannot transfer ownership to yourself");
        //get maximum bid on my property
        temp=getMaxBid(landOwnerList[msg.sender].hashstring);

        //accept highest bids
        if(activeBids[temp].bidVal >= landOwnerList[msg.sender].estimatedValue){
            activeBids[temp].accepted=true;
            emit CustomerBidAccepted(temp, activeBids[temp].name, activeBids[temp].bidVal);
        }

        //transfer tokens
        if(balances[temp] > activeBids[temp].bidVal){
            uint balance = activeBids[temp].bidVal;
            balances[temp] -= activeBids[temp].bidVal;       // first debit
            msg.sender.transfer(balance);                   // then credit
            balances[msg.sender] += activeBids[temp].bidVal;

        }

         //delete all existing other bids on the property;
         //if arrays are not the best way, need to learn how best to achieve this in ETH II course

        //transfer property ownership
        deregisterLand(temp);

    }

}
