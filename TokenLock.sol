// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenLock is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _lockId;

    struct StakeInfo {
        uint amount;
        uint lockedUntil;
        address staker;
        bool unstaked;
    }

    uint public constant STAKING_PERIOD = 4 * 30 days;
    address public admin; 
    bool public paused; 
    
    IERC20 private constant _TOKEN = IERC20(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    IERC20 private constant _xTOKEN = IERC20(0x17F6AD8Ef982297579C203069C1DbfFE4348c372);
    
    mapping (uint => StakeInfo) private _idToStakeInfo; 
    
    modifier adminOnly() {
        require(msg.sender == admin);
        _;
    }
    
    modifier notPaused() {
        require(paused == false);
        _;
    }

    constructor(address _admin) {
        admin = _admin; 
    }

    function lockTokens(uint _amount) external nonReentrant notPaused returns (uint lockId) {
        require(_amount > 0, "Invalid amount");
        _lockId.increment();
        lockId = _lockId.current();
        _idToStakeInfo[lockId] = StakeInfo({
            staker: msg.sender,
            amount: _amount,
            lockedUntil: block.timestamp + STAKING_PERIOD,
            unstaked: false
        });

        _xTOKEN.safeTransferFrom(msg.sender, address(this), _amount);
    } 

    function getStakeInfo(uint _id) external view returns (StakeInfo memory) {
        if(msg.sender != admin) require(msg.sender == _idToStakeInfo[_id].staker, "You are not the staker of this ID");
        return _idToStakeInfo[_id];
    }

    function withdrawTokens(uint _id) external nonReentrant notPaused {
        StakeInfo storage stakeInfo = _idToStakeInfo[_id];
        require(msg.sender == stakeInfo.staker, "You are not the staker of this ID");
        require(block.timestamp > stakeInfo.lockedUntil, "Tokens still locked");
        require(!stakeInfo.unstaked);
        stakeInfo.unstaked = true;

        _TOKEN.safeTransfer(msg.sender, stakeInfo.amount);
    }

    function adminWithdraw() external adminOnly {
        _xTOKEN.transfer(msg.sender, _xGRAV.balanceOf(address(this)));
    }

    function pause() external adminOnly {
        paused = true;
    }

    function unpause() external adminOnly {
        paused = false;
    }
 
    function transferAdminRole(address _newAdmin) external adminOnly {
        admin = _newAdmin;
    }
}

