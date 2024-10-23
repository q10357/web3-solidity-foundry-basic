// SPDX-License-Identifier: MIT

// EVM, Ethereum Virtual Machine
// Avalanche, Fantom, Polygon

// 0.8.8 = Need exact version, ^0.8.8 = If you give me newer version, it's key
// >=0.8.8 < 0.9.0 = equal or newer than v0.8.8, but not v0.0.9 or newer
pragma solidity 0.8.19;

contract SimpleStorage {
    // 0 is default if no other value is set
    // dvs variable gets initialized to zero
    uint256 favoriteNumber;
    //Person public person = Person({favoriteNumber: 2, name: "Isabel"});

    mapping(string => uint256) public nameToFavoriteNumber;
    struct Person {
        uint256 favoriteNumber;
        string name;
    }

    // uint256 public favoriteNumbersList;
    Person[] public people;

    // index 0: 2, Isabel, 1: 3, Jon

    function store(uint256 _favoriteNumber) public virtual {
        favoriteNumber = _favoriteNumber;
    }

    /*
        view, pure no cost, just read state CANNOT update blockchain

        exception: If a gass calling function (non view/pure) calls 
        a view or pure function - only then will it cost gas    
    */
    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }

    // calldata, memory, storage
    // calldata: temporary variables that cant be redefined
    // memory: same but can be redefined
    // storage: permanent variables that can be modified
    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        people.push(Person(_favoriteNumber, _name));
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
}
