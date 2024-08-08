// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// dispatch eth to multiple addresses in one transaction
// the amount of eth to be sent to each address is the same
// op-sepolia: 0x8C306F482f79Ff101FAAAa5fFDB1B6690F8a9ae0
contract ethDispatcher {
  constructor() {}

  function dispatch(address[] memory _to) public payable {
    
    uint256 amount = (msg.value / _to.length) - 1;
    for (uint i = 0; i < _to.length; i++) {
      payable(_to[i]).transfer(amount);
    }
  }
}