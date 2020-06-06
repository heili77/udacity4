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
        address insureeAccount; // account address of insuree
        uint256 amount;                 // insurance amount
        address airlineAccount;         // account address of airline
        string airlineName;             // name of airline
        uint256 timestamp;              // timestamp of airline
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
        string airlineName // name of airline
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
                            )
                            external
                            payable
    {
        
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund
                            (
                            )
                            public
                            payable
    {
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        pure
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
                            external
                            payable
    {
        fund();
    }


}

