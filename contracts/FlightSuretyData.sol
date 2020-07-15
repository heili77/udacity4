pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    mapping(address => bool) private authorizedCallers; // Addresses that can access this contract

    // data structure to determine an airline
    struct Airline {
        address airlineAccount; // account address of airline
        string name;            // name of airline
        bool isRegistered;      // is this airline registered or not
        bool isFunded;          // is this airline funded or not
        uint256 fund;           // amount of fund available
    }
    // mapping to store airlines data
    mapping(address => Airline) private airlines;
    // number of airlines available
    uint256 internal airlinesCount = 0;

    // data structure to determine insurance
    struct Insurance {
        address insureeAccount;
        uint256 amount;
        address airlineAccount;
        string flightName;
        uint256 timestamp;
    }
    // mapping to store insurances data
    mapping(bytes32 => Insurance[]) private insurances;
    // mapping to indicate flights whose payout have been credited
    mapping(bytes32 => bool) private payoutCredited;
    // mapping to store credits available for each insuree
    mapping(address => uint256) private creditPayoutsToInsuree;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(
        address indexed airlineAccount, // account address of airline
        string  airlineName             // name of airline
    );

    event AirlineFunded(
        address indexed airlineAccount, // account address of airline
        uint256 amount                  // amount funded to airline
    );

    event InsurancePurchased(
        address indexed insureeAccount, // account address of insuree
        uint256 amount,                 // insurance amount
        address airlineAccount,         // account address of airline
        string  flightName,            // name of airline
        uint256 timestamp               // timestamp of airline
    );

    event InsuranceCreditAvailable(
        address indexed airlineAccount, // account address of airline
        string  indexed flight,    // name of airline
        uint256 indexed timestamp       // timestamp of airline
    );

    event InsuranceCredited(
        address indexed insureeAccount, // account address of insuree
        uint256 amount                  // insurance amount
    );

    event InsurancePaid(
        address indexed insureeAccount, // account address of insuree
        uint256 amount                  // insurance amount
    );

    event CallerAuthorized(
        address Caller
    );

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
        (
            address _initialAirlineAccount,
            string memory _initialAirlineName
        )
        public
    {
        contractOwner = msg.sender;
        addAirline(_initialAirlineAccount, _initialAirlineName);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender] == true, "not authorized");
        _;
    }

    modifier hasMsgData() {
        require(msg.data.length > 0, "Message data is empty");
        _;
    }

    modifier is_airline() {
        require(airlines[msg.sender].isRegistered, "Caller not Airline");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
        (
            bool mode
        )
        external
        requireContractOwner()
    {
        operational = mode;
    }

    /**
     * @dev Add a new address to the list of authorized callers
     *      Can only be called by the contract owner
     */
    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedCallers[contractAddress] = true;
        emit CallerAuthorized(contractAddress);
    }

    function getFlightKey(
        address airline,
        string flight,
        uint256 timestamp
    )
    internal
    pure
    returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getAirlinesCount()
        external
        view
        returns(uint256)
    {
        return airlinesCount;
    }

    function isAirline
        (
            address airlineAccount
        )
        external
        view
        returns(bool)
    {
        return airlines[airlineAccount].isRegistered;
    }

    function isAirlineFunded
        (
            address airlineAccount
        )
        external
        view
        returns(bool)
    {
        return airlines[airlineAccount].isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
        (
            address _airlineAccount,
            string  _airlineName
        )
        external
        isAuthorizedCaller
    {
        addAirline(_airlineAccount, _airlineName);
    }

    function addAirline(
        address _airlineAccount,
        string  _airlineName
    )
    private
    {
        airlinesCount = airlinesCount.add(1);
        airlines[_airlineAccount] = Airline(
            _airlineAccount,
            _airlineName,
            true,
            false,
            0
        );
        emit AirlineRegistered(_airlineAccount, _airlineName);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
        (
            address _insureeAccount,
            address _airlineAccount,
            string  _flightName,
            uint256 _timestamp
        )
        external
        payable
    {
        bytes32 flightKey = getFlightKey(_airlineAccount, _flightName, _timestamp);
        airlines[_airlineAccount].fund = airlines[_airlineAccount].fund.add(msg.value);
        insurances[flightKey].push(
            Insurance(
                _insureeAccount,
                msg.value,
                _airlineAccount,
                _flightName,
                _timestamp
            )
        );
        emit InsurancePurchased(
            _insureeAccount,
            msg.value,
            _airlineAccount,
            _flightName,
            _timestamp
        );
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
        (
            uint256 _creditPercentage,
            address _airlineAccount,
            string  _flightName,
            uint256 _timestamp
        )
        external
        isAuthorizedCaller
    {
        bytes32 flightKey = getFlightKey(_airlineAccount, _flightName, _timestamp);
        require(!payoutCredited[flightKey], "Insurance payout have already been credited");
        for (uint i = 0; i < insurances[flightKey].length; i++) {
            address insureeAccount = insurances[flightKey][i].insureeAccount;
            uint256 amountToReceive = insurances[flightKey][i].amount.mul(_creditPercentage).div(100);
            creditPayoutsToInsuree[insureeAccount] = creditPayoutsToInsuree[insureeAccount].add(amountToReceive);
            airlines[_airlineAccount].fund = airlines[_airlineAccount].fund.sub(amountToReceive);
            emit InsuranceCredited(insureeAccount, amountToReceive);
        }
        payoutCredited[flightKey] = true;
        emit InsuranceCreditAvailable(_airlineAccount, _flightName, _timestamp);
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
        (
            address _insureeAccount
        )
        external
        isAuthorizedCaller
    {
        uint256 payableAmount = creditPayoutsToInsuree[_insureeAccount];
        delete(creditPayoutsToInsuree[_insureeAccount]);
        _insureeAccount.transfer(payableAmount);
        emit InsurancePaid(_insureeAccount, payableAmount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund
        (
            address _airlineAccount
        )
        public
        payable
        isAuthorizedCaller
    {
        addFund(_airlineAccount, msg.value);
        airlines[_airlineAccount].isFunded = true;
        emit AirlineFunded(_airlineAccount, msg.value);
    }

    function addFund(
        address _airlineAccount,
        uint256 _fundValue
    )
    private {
        airlines[_airlineAccount].fund = airlines[_airlineAccount].fund.add(_fundValue);
    }

    function getInsureePayoutCredits
        (
            address _insureeAccount
        ) external
        view
        returns(uint256 amount)
    {
        return creditPayoutsToInsuree[_insureeAccount];
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function ()
        external
        payable
        hasMsgData
        is_airline
    {
        addFund(msg.sender, msg.value);
        airlines[msg.sender].isFunded = true;
        emit AirlineFunded(msg.sender, msg.value);
    }


}

