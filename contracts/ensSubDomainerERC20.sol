//SPDX-License-Identifier: UNLICENSED
//Code by @0xGeeLoko


pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./StringUtils.sol";

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

interface IERC20{
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}



contract EnsSubDomainerERC20 is Ownable, ReentrancyGuard {
    
     //Treasury
    address payable public treasury = payable(0xF7B083022560C6b7FD0a758A5A1edD47eA87C2bC);

    IENS ens = IENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper nameWrapper = INameWrapper(0x114D4603199df73e7D157787f8778E21fCd13066);
    IBaseRegistrarImplementation baseRegistrarImplementation = IBaseRegistrarImplementation(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);
    address public ensResolver = 0xd7a4F6473f32aC2Af804B3686AE8F1932bC35750;

    //track eth balances mapping per node
    mapping(bytes32 => uint256) public parentNodeBalance;
    //track eth balances mapping per node ERC20
    
    mapping(bytes32 => mapping(address => uint256)) public parentNodeBalanceERC20;
    
    //track intt nodes
    mapping(bytes32 => bool) public parentNodeActive;
    //track canSub nodes ERC20
    mapping(bytes32 => mapping(address => bool)) public parentNodeCanSubERC20Active;
    //track nodes ERC20 list
    mapping(bytes32 => address[]) private parentNodeERC20Contracts;



    //track letter prices mapping per node ERC20
    mapping(bytes32 => mapping(address => uint256)) public threeUpLetterFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public fourFiveLetterFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public sixDownLetterFeeERC20;
    //track number prices mapping per node ERC20
    mapping(bytes32 => mapping(address => uint256)) public oneNumberFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public twoNumberFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public threeNumberFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public fourNumberFeeERC20;
    mapping(bytes32 => mapping(address => uint256)) public fiveUpNumberFeeERC20;



    //add erc20contract
    function addERC20(bytes32 node, address erc20Contract) external {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        //req not on list... check for that
        for (uint i = 0; i < parentNodeERC20Contracts[node].length; i++) {
            require(parentNodeERC20Contracts[node][i] != erc20Contract, 'already added');
        }
        parentNodeERC20Contracts[node].push(erc20Contract);
    }
    //remove?
    function listERC20(bytes32 node) external view returns (address[] memory) {
        return parentNodeERC20Contracts[node];
    }
    
    // set base fee letters
    function setLetterFeesERC20(bytes32 node, address erc20Contract, uint256 threeUpLetterFee_, uint256 fourFiveLetterFee_, uint256 sixDownLetterFee_)  
        external
        isNodeActiveOwnerorApproved(node)
    {
        for (uint i = 0; i < parentNodeERC20Contracts[node].length; i++) {
            require(parentNodeERC20Contracts[node][i] == erc20Contract, 'not added');
        }
        
        threeUpLetterFeeERC20[node][erc20Contract] = threeUpLetterFee_;
        fourFiveLetterFeeERC20[node][erc20Contract] = fourFiveLetterFee_;
        sixDownLetterFeeERC20[node][erc20Contract] = sixDownLetterFee_;
        
    }

    // set base fee numbers
    function setNumberFeesERC20(bytes32 node, address erc20Contract, uint256 oneNumberFeeERC20_, uint256 twoNumberFeeERC20_, uint256 threeNumberFeeERC20_, uint256 fourNumberFeeERC20_, uint256 fiveUpNumberFeeERC20_)  
        external
        isNodeActiveOwnerorApproved(node)
    {
        for (uint i = 0; i < parentNodeERC20Contracts[node].length; i++) {
            require(parentNodeERC20Contracts[node][i] == erc20Contract, 'not added');
        }
        
        oneNumberFeeERC20[node][erc20Contract] = oneNumberFeeERC20_;
        twoNumberFeeERC20[node][erc20Contract] = twoNumberFeeERC20_;
        threeNumberFeeERC20[node][erc20Contract] = threeNumberFeeERC20_;
        fourNumberFeeERC20[node][erc20Contract] = fourNumberFeeERC20_;
        fiveUpNumberFeeERC20[node][erc20Contract] = fiveUpNumberFeeERC20_;
        
    }


    //gets price base on string length
    function getLetterFeesERC20(bytes32 node, address erc20Contract, string memory label, uint256 duration)  
        public
        view
        returns (uint256) 
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        uint len = StringUtils.strlen(label);
        require(len > 0);

        uint256 price;
        if (len <= 3) {
            price = uint256((threeUpLetterFeeERC20[node][erc20Contract])) * duration;
        } else if (len <= 5) {
            price = uint256((fourFiveLetterFeeERC20[node][erc20Contract])) * duration;
        } else if (len >= 6) {
            price = uint256((sixDownLetterFeeERC20[node][erc20Contract])) * duration;    
        }
        return price;
    }

    function getNumberFeesERC20(bytes32 node, address erc20Contract, string memory label, uint256 duration)  
        public
        view
        returns (uint256) 
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        uint len = StringUtils.strlen(label);
        require(len > 0);

        uint256 price;
        if (len == 1) {
            price = uint256((oneNumberFeeERC20[node][erc20Contract])) * duration;
        } else if (len == 2) {
            price = uint256((twoNumberFeeERC20[node][erc20Contract])) * duration;
        } else if (len == 3) {
            price = uint256((threeNumberFeeERC20[node][erc20Contract])) * duration;    
        } else if (len == 4) {
            price = uint256((fourFiveLetterFeeERC20[node][erc20Contract])) * duration;    
        } else if (len >= 5) {
            price = uint256((fiveUpNumberFeeERC20[node][erc20Contract])) * duration;    
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



    function flipBaseEnsSubMode(bytes32 node, address erc20Contract) 
        external 
        isNodeActiveOwnerorApproved(node)
    {
        require(parentNodeActive[node], 'node not active, cannot toggle');
        parentNodeCanSubERC20Active[node][erc20Contract] = !parentNodeCanSubERC20Active[node][erc20Contract];
        if(!parentNodeCanSubERC20Active[node][erc20Contract]){
            parentNodeERC20Contracts[node].push(erc20Contract);
        }else{
            parentNodeERC20Contracts[node];
            for (uint256 i = 0; i < parentNodeERC20Contracts[node].length; i++) {
                if (parentNodeERC20Contracts[node][i] == erc20Contract) {
                    // Move the last element to the position of the element to be removed
                    parentNodeERC20Contracts[node][i] = parentNodeERC20Contracts[node][parentNodeERC20Contracts[node].length - 1];
                    // Remove the last element (duplicate) from the array
                    parentNodeERC20Contracts[node].pop();
                    // Exit the loop as the address is found and removed
                    break;
                }
            }
        }
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


    function updateNodeBalanceERC20(bytes32 node, uint256 amount, address erc20Contract) 
        internal 
    {
        parentNodeBalanceERC20[node][erc20Contract] += amount;
    }
    
    function getPricetoUse (bytes32 node, string memory subNodeLabel, uint256 duration, address erc20Contract) 
        internal 
        view    
        returns(uint) 
    {
        uint256 price;
        if (StringUtils.validateString(subNodeLabel) == 1) {
            price = getLetterFeesERC20(node, erc20Contract, subNodeLabel, duration);
        } else if(StringUtils.validateString(subNodeLabel) == 2) {
            price = getNumberFeesERC20(node, erc20Contract, subNodeLabel, duration);
        }
        return price;
    }

    function tranferERC20(uint256 price, address erc20Contract) 
        internal 
    {
        IERC20 tokenContract = IERC20(erc20Contract);
        require(tokenContract.balanceOf(msg.sender) >= price, 'not enough tokens');
        bool transferred = tokenContract.transferFrom(msg.sender, address(this), price);
        require(transferred, "failed transfer"); 
    }


// function to set new sub domain ERC20

    function setSubDomainERC20(bytes32 node, string memory subNodeLabel, address owner, uint256 duration, address erc20Contract)  
        external
        isApprovedLabel(subNodeLabel)
        isAvailableLabel(node, subNodeLabel)
        nonReentrant
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        require(parentNodeCanSubERC20Active[node][erc20Contract], 'node owner has paused subdomain creation with this erc20 token');

        
        uint32 fuses = 65537; //fuse set to patent cannot control or cannot unwrap
        uint64 timestamp = uint64(block.timestamp);
        uint256 parentNodeYrsLeft = getParentExpiry(node) - timestamp;
        uint64 maxYears = uint64(parentNodeYrsLeft) / uint64(31556926);

        require(duration <= maxYears,'cant extend date past the parent');
        require(nameWrapper.isWrapped(node), 'parent must be wrapped');
        require(nameWrapper.allFusesBurned(node, 1), 'parent must be locked');

        // do balance mapping record
        tranferERC20( getPricetoUse(node, subNodeLabel, duration, erc20Contract), erc20Contract );
        updateNodeBalanceERC20(node, getPricetoUse(node, subNodeLabel, duration, erc20Contract), erc20Contract);
        
        
        uint64 subscriptionPeriod = uint64(duration) * 31556926;
        nameWrapper.setSubnodeRecord(node, subNodeLabel, owner, ensResolver, 0, fuses, subscriptionPeriod + timestamp);

    }


    

// might not be necesarry to use contract for this owner subdomain cannot be managed by main and therefore more need for proxy // letss see //might be need after all using payable fu
// the real issue here is we cannot emancipate or risk losing out on yearly subdomain subs model
// we have to lock instead
// solved

    function extendSubDomainERC20(bytes32 node, bytes32 subNode, uint256 duration, address erc20Contract)
        external 
        payable
        isNodeActiveOwnerorApproved(subNode) 
        nonReentrant
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        require(parentNodeCanSubERC20Active[node][erc20Contract], 'node owner has paused subdomain extending with this erc20 token');
        
        
        string memory label = StringUtils.extractLabel(nameWrapper.names(subNode));
        bytes32 labelhash = keccak256(bytes(label));
        uint256 tokenId = uint256(subNode);

        (/* address owner */, /*uint32 fuses*/, uint64 expiry) = nameWrapper.getData(tokenId);
        uint256 renewRange = getParentExpiry(node) - expiry;
        uint256 maxYears = (renewRange) / (31556926);
        

        
        require(maxYears >= 1 && duration <= maxYears, 'cant extend date past the parent');
        
        // do balance mapping record
        tranferERC20( getPricetoUse(node, label, duration, erc20Contract), erc20Contract );
        updateNodeBalanceERC20(node, getPricetoUse(node, label, duration, erc20Contract), erc20Contract);
        
        uint64 subscriptionPeriod = uint64(duration) * 31556926;
        nameWrapper.extendExpiry(node, labelhash, subscriptionPeriod + expiry);  
    }


    /*
    * Withdraw funds ERC20
    */
    function withdrawNodeBalanceERC20(bytes32 node, address erc20Contract) 
        external
        isNodeActiveOwnerorApproved(node)
        nonReentrant
    {
        require(parentNodeActive[node], 'node not active, approve contract & setBaseENS to activate');
        
        require(parentNodeBalanceERC20[node][erc20Contract] > 0, 'sell some subs and come back..GL');
        require(msg.sender != address(this), 'contract is approved but cannot withdraw');
        
        //only balance taken
        
        uint256 nodeBalanceERC20 = parentNodeBalanceERC20[node][erc20Contract];
        parentNodeBalanceERC20[node][erc20Contract] = 0;
        (bool success, ) = msg.sender.call{value: nodeBalanceERC20 / 1000 * 990}(""); 
        (bool success1, ) = treasury.call{value: nodeBalanceERC20}(""); 
        
        require(success, "Transfer failed");
        require(success1, "Transfer failed");
    }
    // emergency withdraw for node by contract owner***
}


