pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/TokenCache.sol";
import "@aragon/templates-shared/contracts/BaseTemplate.sol";

import "../dependencies/ITokenWrapper.sol";
import "../dependencies/ICycleManager.sol";
import "../StablecoinRewards.sol";

contract Template is BaseTemplate, TokenCache {

    string constant private ERROR_EMPTY_HOLDERS = "TEMPLATE_EMPTY_HOLDERS";
    string constant private ERROR_BAD_HOLDERS_STAKES_LEN = "TEMPLATE_BAD_HOLDERS_STAKES_LEN";
    string constant private ERROR_BAD_VOTE_SETTINGS = "TEMPLATE_BAD_VOTE_SETTINGS";

    address constant private ANY_ENTITY = address(-1);
    bool constant private TOKEN_TRANSFERABLE = true;
    uint8 constant private TOKEN_DECIMALS = uint8(18);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(0);

    // Used to prevent stack too deep errors.
    ITokenWrapper private tokenWrapper;
    ICycleManager private cycleManager;
    StablecoinRewards private stablecoinRewards;

    constructor (DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory, IFIFSResolvingRegistrar _aragonID)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory, _aragonID) public
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
        tokenWrapper = ITokenWrapper(0);
        cycleManager = ICycleManager(0);
        stablecoinRewards = StablecoinRewards(0);

        newToken(_tokenName, _tokenSymbol);
        newInstance(_sctToken, _stablecoin, _holders, _stakes, _votingSettings);
    }

    /**
    * @dev Create a new MiniMe token and cache it for the user
    * @param _name String with the name for the token used by share holders in the organization
    * @param _symbol String with the symbol for the token used by share holders in the organization
    */
    function newToken(string memory _name, string memory _symbol) internal returns (MiniMeToken) {
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
    function newInstance(ERC20 _sctToken, ERC20 _stablecoin, address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings)
        internal
    {
        _ensureTemplateSettings(_holders, _stakes, _votingSettings);

        (Kernel dao, ACL acl) = _createDAO();
        (Voting voting, Agent agent, Finance finance) = _setupBaseApps(dao, acl, _holders, _stakes, _votingSettings);

        tokenWrapper = _setupTokenWrapper(dao, acl, _sctToken, voting);
        cycleManager = _setupCycleManager(dao, acl, voting);
        stablecoinRewards = _setupStablecoinRewards(dao, acl, voting, cycleManager, tokenWrapper, agent, _stablecoin);

        _setupAgentPermissions(acl, agent, finance, voting, stablecoinRewards, _stablecoin);
        _setupCustomAppPermissions(acl, tokenWrapper, cycleManager, stablecoinRewards, voting);
        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, voting);
    }

    function _setupBaseApps(Kernel _dao, ACL _acl, address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings)
        internal returns (Voting, Agent, Finance)
    {
        MiniMeToken token = _popTokenCache(msg.sender);
        TokenManager tokenManager = _installTokenManagerApp(_dao, token, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);
        Voting voting = _installVotingApp(_dao, token, _votingSettings);
        Agent agent = _installDefaultAgentApp(_dao);
        Finance finance = _installFinanceApp(_dao, agent, uint64(1 days));

        _mintTokens(_acl, tokenManager, _holders, _stakes);
        _setupBasePermissions(_acl, voting, tokenManager, agent, finance);

        return (voting, agent, finance);
    }

    function _setupBasePermissions(ACL _acl, Voting _voting, TokenManager _tokenManager, Agent _agent, Finance _finance) internal {
        _createEvmScriptsRegistryPermissions(_acl, _voting, _voting);
        _createVotingPermissions(_acl, _voting, _voting, _tokenManager, _voting);
        _createTokenManagerPermissions(_acl, _tokenManager, _voting, _voting);
        _createFinanceCreatePaymentsPermission(_acl, _finance, _voting, _voting);
    }

    function _setupTokenWrapper(Kernel _dao, ACL _acl, ERC20 _sctToken, Voting _teamVoting) internal returns (ITokenWrapper) {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("token-wrapper-sc")));
        ITokenWrapper tokenWrapper = ITokenWrapper(_installNonDefaultApp(_dao, _appId));
        tokenWrapper.initialize(_sctToken, "Wrapped SCT", "wSCT");

        return tokenWrapper;
    }

    function _setupCycleManager(Kernel _dao, ACL _acl, Voting _voting) internal returns (ICycleManager) {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("cycle-manager")));
        bytes memory initializeData = abi.encodeWithSelector(ICycleManager(0).initialize.selector, 60);
        ICycleManager cycleManager = ICycleManager(_installDefaultApp(_dao, _appId, initializeData));

        return cycleManager;
    }

    function _setupStablecoinRewards(Kernel _dao, ACL _acl, Voting _voting, ICycleManager _cycleManager, ITokenWrapper _tokenWrapper, Agent _agent, ERC20 _stablecoin)
        internal returns (StablecoinRewards)
    {
        bytes32 _appId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("stablecoin-rewards")));
        bytes memory initializeData = abi.encodeWithSelector(StablecoinRewards(0).initialize.selector, _cycleManager, _tokenWrapper, _agent, _stablecoin);
        StablecoinRewards stablecoinRewards = StablecoinRewards(_installDefaultApp(_dao, _appId, initializeData));

        _acl.createPermission(ANY_ENTITY, stablecoinRewards, stablecoinRewards.CREATE_REWARD_ROLE(), _voting);

        return stablecoinRewards;
    }

    function _setupAgentPermissions(ACL _acl, Agent _agent, Finance _finance, Voting _voting, StablecoinRewards _stablecoinRewards, ERC20 _stablecoin) internal {
        _acl.createPermission(_finance, _agent, _agent.TRANSFER_ROLE(), address(this));
        _acl.grantPermission(_stablecoinRewards, _agent, _agent.TRANSFER_ROLE());
        _acl.setPermissionManager(_voting, _agent, _agent.TRANSFER_ROLE());

        _acl.createPermission(address(this), _agent, _agent.ADD_PROTECTED_TOKEN_ROLE(), address(this));
        _agent.addProtectedToken(_stablecoin);
        _acl.revokePermission(address(this), _agent, _agent.ADD_PROTECTED_TOKEN_ROLE());
        _acl.setPermissionManager(_voting, _agent, _agent.ADD_PROTECTED_TOKEN_ROLE());
    }

    function _setupCustomAppPermissions(ACL _acl, ITokenWrapper _tokenWrapper, ICycleManager _cycleManager, StablecoinRewards _stablecoinRewards, Voting _teamVoting)
        internal
    {
        _acl.createPermission(_stablecoinRewards, _tokenWrapper, _tokenWrapper.DEPOSIT_TO_ROLE(), _teamVoting);
        _acl.createPermission(_stablecoinRewards, _tokenWrapper, _tokenWrapper.WITHDRAW_FOR_ROLE(), _teamVoting);

        _acl.createPermission(ANY_ENTITY, _cycleManager, _cycleManager.UPDATE_CYCLE_ROLE(), _teamVoting);
        _acl.createPermission(_stablecoinRewards, _cycleManager, _cycleManager.START_CYCLE_ROLE(), _teamVoting);
    }

    function _ensureTemplateSettings(address[] memory _holders, uint256[] memory _stakes, uint64[3] memory _votingSettings) private pure {
        require(_holders.length > 0, ERROR_EMPTY_HOLDERS);
        require(_holders.length == _stakes.length, ERROR_BAD_HOLDERS_STAKES_LEN);
        require(_votingSettings.length == 3, ERROR_BAD_VOTE_SETTINGS);
    }
}
