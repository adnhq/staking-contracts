// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenLock is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _lockIds;

    struct StakeInfo {
        uint amount;
        uint lockedUntil;
        address staker;
        bool unstaked;
    }

    uint88 public constant STAKING_PERIOD = 4 * 30 days;
    address public admin; 
    bool public paused; 
    
    IERC20 private constant _TOKEN = IERC20(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    IERC20 private constant _xTOKEN = IERC20(0x17F6AD8Ef982297579C203069C1DbfFE4348c372);
    
    mapping (uint => StakeInfo) private _idToStakeInfo; 
    
    modifier adminOnly() {
        require(msg.sender == admin, "TokenLock: must be admin");
        _;
    }
    
    modifier notPaused() {
        require(paused == false, "TokenLock: contract paused");
        _;
    }

    constructor(address _admin) {
        admin = _admin; 
    }

    function lockTokens(uint _amount) external nonReentrant notPaused returns (uint currentId) {
        require(_amount > 0, "TokenLock: amount must be higher");
        _lockIds.increment();
        currentId = _lockIds.current();
        
        _idToStakeInfo[currentId] = StakeInfo({
            staker: msg.sender,
            amount: _amount,
            lockedUntil: block.timestamp + STAKING_PERIOD,
            unstaked: false
        });

        _xTOKEN.safeTransferFrom(msg.sender, address(this), _amount);
    } 

    function getStakeInfo(uint lockId) external view returns (StakeInfo memory) {
        require(msg.sender == _idToStakeInfo[lockId].staker || msg.sender == admin, "TokenLock: you are not the staker");
        return _idToStakeInfo[lockId];
    }

    function unlockTokens(uint lockId) external nonReentrant notPaused {
        StakeInfo memory stakeInfo = _idToStakeInfo[lockId];
        require(msg.sender == stakeInfo.staker, "TokenLock: you are not the staker");
        require(block.timestamp > stakeInfo.lockedUntil, "TokenLock: staking period still active");
        require(!stakeInfo.unstaked, "TokenLock: already unstaked");
        _idToStakeInfo[lockId].unstaked = true;

        _TOKEN.safeTransfer(msg.sender, stakeInfo.amount);
    }

    function withdraw() external adminOnly {
        _xTOKEN.transfer(msg.sender, _xTOKEN.balanceOf(address(this)));
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

