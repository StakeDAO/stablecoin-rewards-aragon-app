pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/TokenCache.sol";
import "@aragon/templates-shared/contracts/BaseTemplate.sol";

import "../dependencies/ITokenWrapper.sol";
import "../dependencies/ICycleManager.sol";
import "../StablecoinRewards.sol";

contract Template is BaseTemplate, TokenCache {

    // token-wrapper-sc.open.aragonpm.eth for local deployment
//    bytes32 constant internal TOKEN_WRAPPER_ID = 0x3482986293858da5c1bbfd8098f815afbef521eccb1f1739244610fc0bebb10a;

    string constant private ERROR_EMPTY_HOLDERS = "TEMPLATE_EMPTY_HOLDERS";
    string constant private ERROR_BAD_HOLDERS_STAKES_LEN = "TEMPLATE_BAD_HOLDERS_STAKES_LEN";
    string constant private ERROR_BAD_VOTE_SETTINGS = "TEMPLATE_BAD_VOTE_SETTINGS";

    address constant private ANY_ENTITY = address(-1);
    bool constant private TOKEN_TRANSFERABLE = true;
    uint8 constant private TOKEN_DECIMALS = uint8(18);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(0);

    constructor (
        DAOFactory _daoFactory,
        ENS _ens,
        MiniMeTokenFactory _miniMeFactory,
        IFIFSResolvingRegistrar _aragonID
    )
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID)
        public
    {
        _ensureAragonIdIsValid(_aragonID);
        _ensureMiniMeFactoryIsValid(_miniMeFactory);
    }

    /**
    * @dev Create a new MiniMe token and deploy a Template DAO.
    * @param _tokenName String with the name for the token used by share holders in the organization
    * @param _tokenSymbol String with the symbol for the token used by share holders in the organization
    * @param _holders Array of token holder addresses
    * @param _stakes Array of token stakes for holders (token has 18 decimals, multiply token amount `* 10^18`)
    * @param _votingSettings Array of [supportRequired, minAcceptanceQuorum, voteDuration] to set up the voting app of the organization
    */
    function newTokenAndInstance(ERC20 _sctToken, ERC20 _stablecoin, string _tokenName, string _tokenSymbol, address[] _holders, uint256[] _stakes, uint64[3] _votingSettings) external {
        newToken(_tokenName, _tokenSymbol);
        newInstance(_sctToken, _stablecoin, _holders, _stakes, _votingSettings);
    }

    /**
    * @dev Create a new MiniMe token and cache it for the user
    * @param _name String with the name for the token used by share holders in the organization
    * @param _symbol String with the symbol for the token used by share holders in the organization
    */
    function newToken(string memory _name, string memory _symbol) public returns (MiniMeToken) {
        MiniMeToken token = _createToken(_name, _symbol, TOKEN_DECIMALS);
        _cacheToken(token, msg.sender);
        return token;
    }

    /**
    * @dev Deploy a Template DAO using a previously cached MiniMe token
    * @param _holders Array of token holder addresses
    * @param _stakes Array of token stakes for holders (token has 18 decimals, multiply token amount `* 10^18`)
    * @param _votingSettings Array of [supportRequired, minAcceptanceQuorum, voteDuration] to set up the voting app of the organization
    */
    function newInstance(ERC20 _sctToken, ERC20 _stablecoin, address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings) public {
        _ensureTemplateSettings(_holders, _stakes, _votingSettings);

        (Kernel dao, ACL acl) = _createDAO();
        (Voting voting) = _setupBaseApps(dao, acl, _holders, _stakes, _votingSettings);

        ITokenWrapper tokenWrapper = _setupTokenWrapper(dao, acl, _sctToken, voting);
        ICycleManager cycleManager = _setupCycleManager(dao, acl, voting);
        _setupCustomApp(dao, acl, voting, cycleManager, tokenWrapper, _stablecoin);
        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, voting);
    }

    function _setupBaseApps(Kernel _dao, ACL _acl, address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings) internal returns (Voting){
        MiniMeToken token = _popTokenCache(msg.sender);
        TokenManager tokenManager = _installTokenManagerApp(_dao, token, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);
        Voting voting = _installVotingApp(_dao, token, _votingSettings);

        _mintTokens(_acl, tokenManager, _holders, _stakes);
        _setupBasePermissions(_acl, voting, tokenManager);

        return (voting);
    }

    function _setupBasePermissions(ACL _acl, Voting _voting, TokenManager _tokenManager) internal {
        _createEvmScriptsRegistryPermissions(_acl, _voting, _voting);
        _createVotingPermissions(_acl, _voting, _voting, _tokenManager, _voting);
        _createTokenManagerPermissions(_acl, _tokenManager, _voting, _voting);
    }

    function _setupCycleManager(Kernel _dao, ACL _acl, Voting _voting) internal returns (ICycleManager) {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("cycle-manager")));
        bytes memory initializeData = abi.encodeWithSelector(ICycleManager(0).initialize.selector, 50);
        ICycleManager cycleManager = ICycleManager(_installDefaultApp(_dao, _appId, initializeData));

        _acl.createPermission(ANY_ENTITY, cycleManager, cycleManager.UPDATE_CYCLE_ROLE(), _voting);
        _acl.createPermission(ANY_ENTITY, cycleManager, cycleManager.START_CYCLE_ROLE(), _voting);

        return cycleManager;
    }

    function _setupTokenWrapper(Kernel _dao, ACL _acl, ERC20 _sctToken, Voting _teamVoting) internal returns (ITokenWrapper) {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("token-wrapper-sc")));
        ITokenWrapper tokenWrapper = ITokenWrapper(_installNonDefaultApp(_dao, _appId));
        tokenWrapper.initialize(_sctToken, "Wrapped SCT", "wSCT");

        _acl.createPermission(ANY_ENTITY, tokenWrapper, tokenWrapper.DEPOSIT_TO_ROLE(), _teamVoting);
        _acl.createPermission(ANY_ENTITY, tokenWrapper, tokenWrapper.WITHDRAW_FOR_ROLE(), _teamVoting);

        return tokenWrapper;
    }

    function _setupCustomApp(Kernel _dao, ACL _acl, Voting _voting, ICycleManager _cycleManager, ITokenWrapper _tokenWrapper, ERC20 _stablecoin) internal {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("stablecoin-rewards")));
        bytes memory initializeData = abi.encodeWithSelector(StablecoinRewards(0).initialize.selector, _cycleManager, _tokenWrapper, _stablecoin);
        StablecoinRewards stablecoinRewards = StablecoinRewards(_installDefaultApp(_dao, _appId, initializeData));

        _acl.createPermission(ANY_ENTITY, stablecoinRewards, stablecoinRewards.CREATE_REWARD_ROLE(), _voting);
    }

    function _ensureTemplateSettings(address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings) private pure {
        require(_holders.length > 0, ERROR_EMPTY_HOLDERS);
        require(_holders.length == _stakes.length, ERROR_BAD_HOLDERS_STAKES_LEN);
        require(_votingSettings.length == 3, ERROR_BAD_VOTE_SETTINGS);
    }
}
