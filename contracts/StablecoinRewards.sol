pragma solidity ^0.4.24;

import "@aragon/os/contracts/apps/AragonApp.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "@aragon/os/contracts/lib/token/ERC20.sol";
import "@aragonone/apps-token-wrapper/contracts/TokenWrapper.sol"; // TODO: Fork the token wrapper, add permissions, add depositFor and withdrawFor
import "./ICycleManager.sol";

// TODO: Consider generalizing the naming, replacing stablecoin with something more generic.
contract StablecoinRewards is AragonApp {
    using SafeMath for uint256;

    bytes32 constant public CREATE_REWARD_ROLE = keccak256("CREATE_REWARD_ROLE");

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    ICycleManager cycleManager;
    TokenWrapper wrappedSct;
    ERC20 stablecoin;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function initialize(ICycleManager _cycleManager, TokenWrapper _wrappedSct, ERC20 _stablecoin) public onlyInit {
        cycleManager = _cycleManager;
        wrappedSct = _wrappedSct;
        stablecoin = _stablecoin;
        initialized();
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, periodFinish);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function rewardPerToken() public view returns (uint256) {
        if (wrappedSct.totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(wrappedSct.totalSupply())
        );
    }

    function earned(address account) public view returns (uint256) {
        return
        wrappedSct.balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        // TODO: Replace with depositFor
        wrappedSct.deposit(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        // TODO: Replace with withdrawFor
        wrappedSct.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(wrappedSct.balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            stablecoin.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // This must be called before a new cycle is started, to prevent any updates to cycle length effecting the calculations
    function notifyRewardAmount(uint256 reward)
    external
    auth(CREATE_REWARD_ROLE)
    updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(cycleManager.cycleLength());
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(cycleManager.cycleLength());
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(cycleManager.cycleLength());
        emit RewardAdded(reward);
    }
}
