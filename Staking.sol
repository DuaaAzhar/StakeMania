// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
 
interface IERC20 {
   function transferFrom(
       address from,
       address to,
       uint256 amount
   ) external returns (bool);
   function transfer(address to, uint256 amount) external returns (bool);
   function balanceOf(
       address account
   ) external returns(uint256);
}
 
contract Staking is Ownable {
    using SafeMath for uint256;
    address immutable token;
    uint totalClaimable;
   
    struct pool {
        uint duration;
        uint apr;
        uint claimable;
    }
    mapping (uint => pool) pools;
    uint [] poolIds;
   //Unlock Pool named as stakingPool
    struct unLockPool{
       bool initialize;
       uint256 rewardFunds;
       uint256 members;
       address token;
   }
    unLockPool public stakingPool;
 
    struct user {
        uint investment;
        uint outcome;
        uint expiry;
    }
    mapping (address => mapping (uint => mapping (uint => user))) users;
   
    struct instance {
        uint [] enteries;
    }
 
    mapping (address => mapping (uint => instance)) instances;
 
    //User for Unlock Pool
    struct stakingUser{
       uint256 amount;
       uint256 stakingTime;
   }
   mapping(address=> mapping(uint256=>stakingUser)) public stakingUsers;
 
    event Stake(address _to, uint _poolId, uint _amount);
    event Claim(address _to, uint _poolId, uint _instanceId, uint _amount);
    //Events for UnlockPool
    event StakeInUnLock(address _to, uint _instance, uint _amount, uint256 stakingTime);
    event UnStakeFromUnlock(address _to, uint _instance,  uint _amount, uint256 unLockTime);
 
    constructor(address _token) {
        token = _token;
        poolIds = [1, 2, 3, 4];
 
        //initialize pools
        pools[1] = pool(30 days, 10, 0);
        pools[2] = pool(91 days, 15, 0);
        pools[3] = pool(182 days, 20, 0);
        pools[4] = pool(365 days, 30, 0);
    }
 
    modifier validPool(uint _poolId) {
        require(pools[_poolId].duration > 0, "invalid pool id");
        _;
    }
 
    function addPool(uint _poolId, uint _duration, uint _apr) external onlyOwner {
        require(pools[_poolId].duration == 0, "pool already exists");
        pools[_poolId] = pool(_duration, _apr, 0);
        poolIds.push(_poolId);
    }
       
    function stake(address _to, uint _poolId, uint _amount) external validPool(_poolId) returns (uint) {
        IERC20(token).transferFrom(_msgSender(), address(this), _amount);
        uint reward = (_amount * pools[_poolId].apr) / 100;
        uint _instanceId = getInstanceId(_to, _poolId);
        instances[_to][_poolId].enteries.push(_instanceId);
        users[_to][_poolId][_instanceId] = user(_amount, _amount + reward, block.timestamp + pools[_poolId].duration);
        pools[_poolId].claimable += _amount + reward;
        totalClaimable += _amount + reward;
        emit Stake(_to, _poolId, _amount);
        return _instanceId;
    }
 
    function claim(address _to, uint _poolId, uint _instanceId) external validPool(_poolId) {
        require(pools[_poolId].duration > 0, "invalid pool id" );
        require(users[_to][_poolId][_instanceId].investment > 0, "zero stake");
        require(users[_to][_poolId][_instanceId].expiry < block.timestamp, "time remaining");
        IERC20(token).transfer(_to, users[_to][_poolId][_instanceId].outcome);
        pools[_poolId].claimable -= users[_to][_poolId][_instanceId].outcome;
        totalClaimable -= users[_to][_poolId][_instanceId].outcome;
        emit Claim(_to, _poolId, _instanceId, users[_to][_poolId][_instanceId].outcome);
        delete users[_to][_poolId][_instanceId];
    }
 
    function getPool(uint _poolId) public view validPool(_poolId) returns (uint, uint, uint) {
        return(pools[_poolId].duration, pools[_poolId].apr, pools[_poolId].claimable);
    }
 
    function getPoolIds() public view returns (uint[] memory) {
        return poolIds;
    }
 
    function getUserPool(address _to, uint _poolId, uint _instanceId) public view validPool(_poolId) returns (uint, uint, uint) {
        require(users[_to][_poolId][_instanceId].investment > 0, "zero stake");
        return(users[_to][_poolId][_instanceId].investment, users[_to][_poolId][_instanceId].outcome, users[_to][_poolId][_instanceId].expiry);
    }
 
    function getTotalClaimable() public view returns (uint) {
        return totalClaimable;
    }
 
    function getInstanceId(address _to, uint _poolId) internal view returns (uint) {
        return instances[_to][_poolId].enteries.length + 1;
    }
 
    //<<<<<<..............UNLOCK POOL.............>>>>>>>>>>>>>>
   
   function initializePool(uint256 _rewardFunds,address _token) onlyOwner
   public{
       require(!stakingPool.initialize, "Pool Already initialized");
       require(IERC20(token).balanceOf(address(this)) >= _rewardFunds, "Enough Rewards are not funded to pool");
       stakingPool= unLockPool(true,_rewardFunds, 0, _token);
   }
 
   function addFundsToUnlock(uint256 _rewardFunds) onlyOwner public{
       require(stakingPool.initialize, "Pool Not initialized");
       IERC20(token).transferFrom(msg.sender, address(this), _rewardFunds);
       stakingPool.rewardFunds+=_rewardFunds;
   }
 
   function stakeInUnLock(uint256 _amount, uint _instance) public{
       require(_amount > 0 && stakingUsers[msg.sender][_instance].amount==0, "You have Already Staked in this instance. Try Some other Instance");
       stakingUsers[msg.sender][_instance].amount= _amount;
       stakingUsers[msg.sender][_instance].stakingTime= block.number;
       IERC20(token).transferFrom(msg.sender,address(this), _amount);
       stakingPool.members+=1;
       emit StakeInUnLock(msg.sender, _instance, _amount, block.number);
   }
   function unStakeFromUnlock(uint256 _amount, uint256 _instance)public {
       require(stakingUsers[msg.sender][_instance].amount >= _amount, "Not have enough staked amount");
       uint256 reward= calculateReward(_amount, msg.sender, _instance);
       IERC20(token).transfer(msg.sender, _amount.add(reward));
       if(stakingUsers[msg.sender][_instance].amount.sub(_amount) > 0){
           stakingUsers[msg.sender][_instance].amount-=_amount;
       }
       else{
           stakingUsers[msg.sender][_instance].amount=0;
           stakingPool.members-=1;
           stakingPool.rewardFunds-= reward;
           delete stakingUsers[msg.sender][_instance];
       }
       emit UnStakeFromUnlock(msg.sender, _instance, _amount, block.number);
   }
   function calculateReward(uint256 amount, address _user, uint256 _instance) public view returns(uint256){
       require(stakingUsers[_user][_instance].amount >= amount, "Not Enough staked Amount by this user");
       uint256 membersRate= ((stakingPool.rewardFunds/stakingPool.members)*33)/100;
       uint256 duration=getMultiplier(block.number,stakingUsers[_user][_instance].stakingTime);
       uint256 TimeRate= duration.mul(33).div(100);
       uint256 reward= ((amount*33)/100) +  membersRate + TimeRate;
       return reward;
   }
 
   function getMultiplier(uint256 _from, uint256 _to) internal pure returns (uint256) {
       return _from.sub(_to).div(1e6);
   }
 
}

