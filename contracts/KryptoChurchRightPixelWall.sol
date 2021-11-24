// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Signable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract KryptochurchRightPixelWall is Signable {
    event PixelsDrawn(address indexed from, uint numberOfPixels);
    
    mapping (uint256 => uint256) private _pixels;
    
    mapping (address => uint256) private _lastCommit;
    mapping (address => uint256) private _commitTotal;
    
    uint256 private _totalPixels;
    uint256 private _totalTransactions;
    
    uint256 private _lastUpdate;
    
    address[] private _participants;
    
    function commitPixels(uint256[] memory indexes, uint8[] memory colors, uint32 availableColors, bytes calldata signature) public {
        require(!Address.isContract(msg.sender), "Address is contract");
        require(_verify(signer(), _hash(msg.sender, availableColors), signature), "Invalid signature");
        
        uint256 delta = recommendedDelta(msg.sender);
        uint256 lastTime = lastCommitTime(msg.sender);
        require(block.timestamp - delta > lastTime, "Don't call it too often");
        
        uint256 length = indexes.length;
        require(length <= 2178, "Maximum 2178 pixels one-time");
        
        uint256[] memory valuesIndexes = new uint256[](43);
        uint8 preveousColor = 0;
        
        _totalPixels += length;
        _totalTransactions += 1;
        
        uint256 useNumber = 0;
        
        for (uint32 i = 0; i < length; i++) {
            uint256 index = indexes[i];
            require(index < 2178, "Pixel out of bounds");
            
            uint256 globalIndex = index / 51;
            if (_isUsed(useNumber, globalIndex) == false) {
                useNumber = _setUsed(useNumber, globalIndex);
                valuesIndexes[globalIndex] = _pixels[globalIndex];
            }
            uint8 color = colors[i];
            require(color < 31, "Color out of bounds");
            
            if (preveousColor != color) {
                preveousColor = color;
                require(_validateColor(color, availableColors), "You can't use this color");
            }
            
            valuesIndexes[globalIndex] = _setColor(valuesIndexes[globalIndex], index, color);
        }
        
        uint256 setNunber = 0;
        
        for (uint32 i = 0; i < length; i++) {
            uint256 index = indexes[i] / 51;
            if (_isUsed(setNunber, index)) {
                continue;
            }
            _pixels[index] = valuesIndexes[index];
            setNunber = _setUsed(setNunber, index);
        }
        
        _lastUpdate += 1;
        
        if (commitsTotal(msg.sender) == 0) {
            _participants.push(msg.sender);
        }
        
        _lastCommit[msg.sender] = block.timestamp;
        _commitTotal[msg.sender] = commitsTotal(msg.sender) + 1;
        
        emit PixelsDrawn(msg.sender, length);
    }

    function colorAtIndex(uint256 index) public view returns (uint256) {
        uint256 rowIndex = index / 51;
        uint256 colorBitIndex = (index % 51) * 5;
        uint256 colorRow = _pixels[rowIndex];
        return (colorRow >> colorBitIndex) & 31;
    }
    
    function lastUpdate() public view returns (uint256) {
        return _lastUpdate;
    }
    
    function pixels() public view returns (uint256[] memory) {
        uint256 length = 43;
        uint256[] memory values = new uint256[](length);
        
        for (uint128 i = 0; i < length; i++) {
            values[i] = _pixels[i];
        }
        
        return values;
    }
    
    function hasParticipated(address operator) public view returns (bool) {
        return _commitTotal[operator] > 0;
    }
    
    function lastCommitTime(address operator) public view returns (uint256) {
        return _lastCommit[operator];
    }
    
    function commitsTotal(address operator) public view returns (uint256) {
        return _commitTotal[operator];
    }
    
    function recommendedDelta(address operator) public view returns (uint256) {
        uint256 total = commitsTotal(operator);
        if (total < 10) {
            return 1 seconds;
        } else if (total < 30) {
            return 2 seconds;
        } else if (total < 50) {
            return 3 seconds;
        } else if (total < 80) {
            return 5 seconds;
        } else if (total < 120) {
            return 10 seconds;
        } else if (total < 300) {
            return 15 seconds;
        } else {
            return 30 seconds;
        }
    }
    
    function totalPixels() public view returns (uint256) {
        return _totalPixels;
    }
    
    function totalTransactions() public view returns (uint256) {
        return _totalTransactions;
    }
    
    function totalParticipants() public view returns (uint256) {
        return _participants.length;
    }
    
    function participants() public view returns (address[] memory) {
        return _participants;
    }
    
    function participant(uint index) public view returns (address) {
        return _participants[index];
    }
    
    function _setColor(uint256 value, uint256 index, uint8 color) private pure returns (uint256) {
        uint256 colorBitIndex = (index % 51) * 5;
        uint256 colorBit = uint256(color) << colorBitIndex;
        uint256 colorBitMask = ~(31 << colorBitIndex);
        return (value & colorBitMask) | colorBit;
    }
    
    function _verify(address signer, bytes32 hash, bytes memory signature) private pure returns (bool) {
        return signer == ECDSA.recover(hash, signature);
    }
    
    function _hash(address account, uint32 amount) private pure returns (bytes32) {
        return ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(account, amount)));
    }
    
    function _validateColor(uint8 color, uint32 availableColors) private pure returns (bool) {
        if (color <= 1) {
            return true;
        }
        
        uint32 value = uint32(1) << uint32(color);
        return value & availableColors == value;
    }
    
    function _isUsed(uint256 number, uint256 index) private pure returns (bool) {
        uint256 usedBitIndex = index % 256;
        uint256 mask = (1 << usedBitIndex);
        return number & mask == mask;
    }
    
    function _setUsed(uint256 number, uint256 index) private pure returns (uint256) {
        uint256 usedBitIndex = index % 256;
        return number | (1 << usedBitIndex);
    }
}