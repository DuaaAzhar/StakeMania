// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
 
contract ERC20Token is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
 
    constructor() ERC20("erc20", "TKN") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
 
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
 
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
 
    function burn(uint256 amount) public virtual onlyRole(MINTER_ROLE) {
        _burn(_msgSender(), amount);
    }
}

