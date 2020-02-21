pragma solidity ^0.4.24;

import "@aragon/os/contracts/lib/token/ERC20.sol";

contract ITokenWrapper is ERC20 {

    bytes32 public constant DEPOSIT_TO_ROLE = keccak256("DEPOSIT_TO_ROLE");
    bytes32 public constant WITHDRAW_FOR_ROLE = keccak256("WITHDRAW_FOR_ROLE");

    function initialize(ERC20 _depositedToken, string _name, string _symbol) external;

    function depositedToken() public view returns (ERC20);

    function depositTo(uint256 _amount, address _to) external;

    function withdrawFor(uint256 _amount, address _forAddress) external;
}