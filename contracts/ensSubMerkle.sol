// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ensSubMerkle {
    
    
    mapping(bytes32 => bytes32) public parentNodeMerkleRoot;
    
    mapping(bytes32 => uint256) public parentNodeMaxSub;
    
    mapping (bytes32 => mapping(address => uint256)) private _parentNodeSubListENS;

    /**
     * @dev emitted when an account has subdomained some ens
    */
    event SubListed(address indexed account, uint256 amount, bytes32 node);

    /**
     * @dev emitted when the merkle root has changed per node
    */
    event ParentNodeMerkleRootChanged(bytes32 merkleRoot, bytes32 node);


    /**
     * @dev sets the merkle root per node
     */
    function _setSubListMerkle(bytes32 merkleRoot_, bytes32 node) internal virtual {
        parentNodeMerkleRoot[node] = merkleRoot_;

        emit ParentNodeMerkleRootChanged(parentNodeMerkleRoot[node], node);
    }

    /**
     * @dev sets the number of ENS max to the incoming address per node
     */
    
    function _setMaxSubListENS(uint256 numberOfSubENS, bytes32 node) internal virtual {
        parentNodeMaxSub[node] += numberOfSubENS;
    }


    /**
     * @dev adds the number of ens to the incoming address per node
     */
    
    function _setSubListENS(address to, uint256 numberOfSubENS, bytes32 node) internal virtual {
        _parentNodeSubListENS[node][to] += numberOfSubENS;

        emit SubListed(to, numberOfSubENS, node);
    }

    /**
     * @dev gets the number of ens from the address per node
     */
    
    function getSubListENS(address from, bytes32 node) public view virtual returns (uint256) {
        return _parentNodeSubListENS[node][from];
    }
    

    /**
     * @dev checks if the sublister has a valid proof per node
     */
    function onSubList(address subLister, bytes32[] memory proof, bytes32 node) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(subLister));
        return MerkleProof.verify(proof, parentNodeMerkleRoot[node], leaf);
    }
}