//SPDX-License-Identifier: UNLICENSED
//Code by @0xGeeLoko


pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StringUtils.sol";
import "./ensSubMerkle.sol";

//interfaces
/*
*ENS
*/
interface IENS {
    function owner(bytes32 node) external view returns (address);

    function resolver(bytes32 node) external view returns (address);

    function recordExists(bytes32 node) external view returns (bool);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);
}


/*
*BaseRegistrarImplementation
*/
interface IBaseRegistrarImplementation {
    function nameExpires(uint256 id) external view returns (uint256);
}


/*
*NameWrapper
*/
interface INameWrapper {
    function isWrapped(bytes32) external view returns (bool);
    
    function names(bytes32) external view returns (bytes memory);
    
    function setSubnodeRecord(
        bytes32 node,
        string calldata label,
        address owner,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32);

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    ) external returns (uint32 newFuses);
    
    function extendExpiry(
        bytes32 node,
        bytes32 labelhash,
        uint64 expiry
    ) external returns (uint64);

    function getData(
        uint256 id
    ) external view returns (address, uint32, uint64);

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) external view returns (bool);

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);
}



contract EnsSubDomainerMerkle is Ownable, ensSubMerkle, ReentrancyGuard {
    AggregatorV3Interface internal priceFeed = AggregatorV3Interface( 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e ); // change beefore mainnet
    

    IENS ens = IENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper nameWrapper = INameWrapper(0x114D4603199df73e7D157787f8778E21fCd13066);
    IBaseRegistrarImplementation baseRegistrarImplementation = IBaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    address public ensResolver = 0xd7a4F6473f32aC2Af804B3686AE8F1932bC35750;
    //bytes32 public parentNode;
    // will be removed so it can be maunually added per the user
    

    //uint256 public threeUpLetterFee;
    //uint256 public fourFiveLetterFee;
    //uint256 public sixDownLetterFee;

    //track eth balances mapping per node
    mapping(bytes32 => uint256) public parentNodeBalance;
    //track intt nodes
    mapping(bytes32 => bool) public parentNodeActive;
    //track canSub nodes
    mapping(bytes32 => bool) public parentNodeCanSubActive;
    //track letter prices mapping per node
    mapping(bytes32 => uint256) public threeUpLetterFee;
    mapping(bytes32 => uint256) public fourFiveLetterFee;
    mapping(bytes32 => uint256) public sixDownLetterFee;
    //track number prices mapping per node
    mapping(bytes32 => uint256) public oneNumberFee;
    mapping(bytes32 => uint256) public twoNumberFee;
    mapping(bytes32 => uint256) public threeNumberFee;
    mapping(bytes32 => uint256) public fourNumberFee;
    mapping(bytes32 => uint256) public fiveUpNumberFee;
    


    // set base fee letters
    function setLetterFees(bytes32 node, uint256 threeUpLetterFee_, uint256 fourFiveLetterFee_, uint256 sixDownLetterFee_)  
        external
        isNodeActiveOwnerorApproved(node)
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        threeUpLetterFee[node] = threeUpLetterFee_;
        fourFiveLetterFee[node] = fourFiveLetterFee_;
        sixDownLetterFee[node] = sixDownLetterFee_;
        
    }

    // set base fee numbers
    function setNumberFees(bytes32 node, uint256 oneNumberFee_, uint256 twoNumberFee_, uint256 threeNumberFee_, uint256 fourNumberFee_, uint256 fiveUpNumberFee_)  
        external
        isNodeActiveOwnerorApproved(node)
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        oneNumberFee[node] = oneNumberFee_;
        twoNumberFee[node] = twoNumberFee_;
        threeNumberFee[node] = threeNumberFee_;
        fourNumberFee[node] = fourNumberFee_;
        fiveUpNumberFee[node] = fiveUpNumberFee_;
        
    }

    /**
     * Returns the latest price.
     */
    // usd/eth chainlink oracle
    function getLatestPrice(uint256 usdPrice) 
        internal 
        view
        returns (int) 
    
    {
        (
            /* uint80 roundID */,
            int etherPrice,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return int(usdPrice) * 1000000000000000000 / (etherPrice);
    }

    
    //gets price base on string length
    function getLetterFees(bytes32 node, string memory label, uint256 duration)  
        public
        view
        returns (uint256) 
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        uint len = StringUtils.strlen(label);
        require(len > 0);

        uint256 price;
        if (len <= 3) {
            price = uint256(getLatestPrice(threeUpLetterFee[node])) * duration;
        } else if (len <= 5) {
            price = uint256(getLatestPrice(fourFiveLetterFee[node])) * duration;
        } else if (len >= 6) {
            price = uint256(getLatestPrice(sixDownLetterFee[node])) * duration;    
        }
        return price;
    }

    function getNumberFees(bytes32 node, string memory label, uint256 duration)  
        public
        view
        returns (uint256) 
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        uint len = StringUtils.strlen(label);
        require(len > 0);

        uint256 price;
        if (len == 1) {
            price = uint256(getLatestPrice(oneNumberFee[node])) * duration;
        } else if (len == 2) {
            price = uint256(getLatestPrice(twoNumberFee[node])) * duration;
        } else if (len == 3) {
            price = uint256(getLatestPrice(threeNumberFee[node])) * duration;    
        } else if (len == 4) {
            price = uint256(getLatestPrice(fourFiveLetterFee[node])) * duration;    
        } else if (len >= 5) {
            price = uint256(getLatestPrice(fiveUpNumberFee[node])) * duration;    
        }
        return price;
    }

    

   modifier isApprovedLabel (string memory subNodeLabel_) {
        require(StringUtils.validateString(subNodeLabel_) != 0, "not a valid string");
        _;
    }

    modifier isAvailableLabel (bytes32 node, string memory subNodeLabel_) {
        bytes32 labelhash = keccak256(bytes(subNodeLabel_));
        require(!ens.recordExists(keccak256(abi.encodePacked(node, labelhash))), "not Available Label");
        _;
    }

    modifier isNodeActiveOwnerorApproved (bytes32 node) {
        (address owner, /*uint32 fuses*/, /*uint64 expiry*/) = nameWrapper.getData(uint256(node));
        if(nameWrapper.isWrapped(node)) {
            require(msg.sender == owner || nameWrapper.isApprovedForAll(owner, msg.sender), "not the owner of node");
        } else {
            require(msg.sender == ens.owner(node) || ens.isApprovedForAll(ens.owner(node), msg.sender), "not the owner of node");
        }
        _;
    }

//function to set init node
    function setBaseEns(bytes32 node)  
        external 
        isNodeActiveOwnerorApproved(node)
    {
        require(!parentNodeActive[node], 'node active, try another');
        (address owner, /*uint32 fuses*/, /*uint64 expiry*/) = nameWrapper.getData(uint256(node));
        require(nameWrapper.isApprovedForAll(owner, address(this)), "please approve this contract address");
        parentNodeActive[node] = true;
    }

    function updateBaseEnsMerkle(bytes32 node, bytes32 merkleRoot, uint256 numberOfSubENS)  
        external 
        isNodeActiveOwnerorApproved(node)
    {
        require(parentNodeActive[node], 'node must be active');
        // add merkle
        _setSubListMerkle(merkleRoot, node);
        // set max
        _setMaxSubListENS(numberOfSubENS, node);
    }

    function flipBaseEnsSubMode(bytes32 node) 
        external 
        isNodeActiveOwnerorApproved(node)
    {
        require(parentNodeActive[node], 'node not active, cannot toggle');
        parentNodeCanSubActive[node] = !parentNodeCanSubActive[node];
    }



    
    function getParentExpiry(bytes32 node)  
        internal
        view
        returns (uint256) 
    {
        string memory label = StringUtils.extractLabel(nameWrapper.names(node));
        uint256 tokenId = uint256(keccak256(bytes(label)));
        return baseRegistrarImplementation.nameExpires(tokenId);
    }

    function updateNodeBalance(bytes32 node, uint256 amount) 
        internal 
    {
        parentNodeBalance[node] += amount;
    }
    
    function getPricetoUse (bytes32 node, string memory subNodeLabel, uint256 duration) 
        internal 
        view    
        returns(uint) 
    {
        uint256 price;
        if (StringUtils.validateString(subNodeLabel) == 1) {
            price = getLetterFees(node, subNodeLabel, duration);
        } else if(StringUtils.validateString(subNodeLabel) == 2) {
            price = getNumberFees(node, subNodeLabel, duration);
        }
        return price;
    }

// function to set new sub domain

    function setSubDomain(bytes32 node, string memory subNodeLabel, address owner, uint256 duration, bytes32[] memory merkleRoot)  
        external 
        payable 
        isApprovedLabel(subNodeLabel)
        isAvailableLabel(node, subNodeLabel)
        //availableSubENS(msg.sender, 1, node)
        nonReentrant
    {
        require(onSubList(msg.sender, merkleRoot, node), 'Not on sub ens list');

        if(parentNodeMaxSub[node] >= 1){
            require(getSubListENS(msg.sender, node) + 1 <= parentNodeMaxSub[node] , 'Purchase would exceed number of ens allotted');
        }else if(parentNodeMaxSub[node] < 1){
            require(getSubListENS(msg.sender, node) + 1 < parentNodeMaxSub[node], 'Purchase must be over zero');
        }
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        require(parentNodeCanSubActive[node], 'node owner has paused subdomain creation');

        //uint32 fuses = 65537; //fuse set to patent cannot control or cannot unwrap
        //uint64 timestamp = uint64(block.timestamp);
        uint256 parentNodeYrsLeft = getParentExpiry(node) - uint64(block.timestamp);
        uint64 maxYears = uint64(parentNodeYrsLeft) / uint64(31556926);

        

        require(duration <= maxYears,'cant extend date past the parent');
        require(nameWrapper.isWrapped(node), 'parent must be wrapped');
        require(nameWrapper.allFusesBurned(node, 1), 'parent must be locked');
        require(getPricetoUse(node, subNodeLabel, duration) == msg.value, 'price not correct');

        // do balance mapping record
        updateNodeBalance(node, getPricetoUse(node, subNodeLabel, duration));

        _setSubListENS(msg.sender, 1, node);
        
        uint64 subscriptionPeriod = uint64(duration) * 31556926;
        nameWrapper.setSubnodeRecord(node, subNodeLabel, owner, ensResolver, 0, 65537, subscriptionPeriod + uint64(block.timestamp));

    }

// might not be necesarry to use contract for this owner subdomain cannot be managed by main and therefore more need for proxy // letss see //might be need after all using payable fu
// the real issue here is we cannot emancipate or risk losing out on yearly subdomain subs model
// we have to lock instead
// solved
    function extendSubDomain(bytes32 node, bytes32 subNode,  uint256 duration, bytes32[] memory merkleRoot)
        external 
        payable
        isNodeActiveOwnerorApproved(subNode)
        nonReentrant
    {
        require(onSubList(msg.sender, merkleRoot, node), 'Not on sub ens list');
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        string memory label = StringUtils.extractLabel(nameWrapper.names(subNode));
        bytes32 labelhash = keccak256(bytes(label));
        uint256 tokenId = uint256(subNode);

        (/* address owner */, /*uint32 fuses*/, uint64 expiry) = nameWrapper.getData(tokenId);
        uint256 renewRange = getParentExpiry(node) - expiry;
        uint256 maxYears = (renewRange) / (31556926);
        
        
        
        require(maxYears >= 1 && duration <= maxYears, 'cant extend date past the parent');
        require(getPricetoUse(node, label, duration) == msg.value, 'price not correct');

        // do balance mapping record
        updateNodeBalance(node, getPricetoUse(node, label, duration));

        uint64 subscriptionPeriod = uint64(duration) * 31556926;
        nameWrapper.extendExpiry(node, labelhash, subscriptionPeriod + expiry);  
    }


    /*
    * Withdraw funds
    */
    function withdrawNodeBalance(bytes32 node) 
        external
        isNodeActiveOwnerorApproved(node)
        nonReentrant
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        require(parentNodeBalance[node] > 0, 'sell some subs and come back..GL');
        require(msg.sender != address(this), 'contract is approved but cannot withdraw');
        
        //only balance taken
        
        uint256 nodeBalance = parentNodeBalance[node];
        parentNodeBalance[node] = 0;
        (bool success, ) = msg.sender.call{value: nodeBalance}(""); 
        require(success, "Transfer failed");
    }

    // emergency withdraw for node by contract owner***
}