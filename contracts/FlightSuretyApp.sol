pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private constant AIRLINES_THRESHOLD = 4;
    uint256 public constant INSURANCE_RETURN_PERCENTAGE = 150;
    
    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        string flight;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    mapping(address => uint256) votesMap;//positive votes
    mapping(address => mapping(address => bool)) votersMap;//voters


    FlightSuretyData internal flightSuretyData;

    event FlightRegistered(
        address airlineAccount,
        string airlineName,
        uint256 timestamp
    );

    event AirlineRegistered(
        bool success,
        uint256 votes
    );

    event Voted(
        address airline,
        uint256 votes
    );

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
    modifier isOperational()
    {
         // Modify to call data contract's status
        require(is_operational(), "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier isContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires sender account to be the function caller
     */
    modifier isAirline() {
        require(flightSuretyData.isAirline(msg.sender), "Caller is not registered airline");
        _;
    }

    /**
     * @dev Modifier that requires an airline account to be the function caller
     */
    modifier isAirlineFunded() {
        require(flightSuretyData.isAirlineFunded(msg.sender), "Caller airline is not funded");
        _;
    }

    modifier isFutureFlight(uint256 _timestamp) {
        require(_timestamp > block.timestamp, "Flight is not in future");
        _;
    }

   // modifier isMinimumFunded()
   // {
  //      require(flightSuretyData.)
 //       _;
 //   }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
        (
            address dataContract
        )
        public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function is_operational()
        public
        view
        returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    function addVote
        (
            address _airlineAccount
            //address _callerAirlineAccount
        )
        internal
        isAirline()
    {
        require(votersMap[_airlineAccount][msg.sender] == false, "already voted");
        votersMap[_airlineAccount][msg.sender] = true;
        votesMap[_airlineAccount] = votesMap[_airlineAccount].add(1);
        emit Voted(_airlineAccount, votesMap[_airlineAccount]);
    }

    function getFlightKey
        (
            address airline,
            string flight,
            uint256 timestamp
        )
        internal
        pure
        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
        (
            address _airlineAccount,
            string  _airlineName
        )
        external
        isOperational
        isAirline
        isAirlineFunded
        returns(bool success, uint256 votes)
    {
        require(!flightSuretyData.isAirline(_airlineAccount), "Airline is already registered");
        success = false;
        votes = 0;
        uint256 airlinesCount = flightSuretyData.getAirlinesCount();
        if (airlinesCount < AIRLINES_THRESHOLD) {
            flightSuretyData.registerAirline(_airlineAccount, _airlineName);
            success = true;
        } else {
            uint256 votesNeeded = airlinesCount.mul(100).div(2);
            addVote(_airlineAccount);
            votes = votesMap[_airlineAccount];
            if (votes.mul(100) >= votesNeeded) {
                flightSuretyData.registerAirline(_airlineAccount, _airlineName);
                success = true;
            }
        }
        //return (success, vo);
        emit AirlineRegistered(success, votes);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
        (
            string  _flightname,
            uint256 _timestamp
        )
        external
        isOperational
        isAirline
        isAirlineFunded
        isFutureFlight(_timestamp)
    {
        bytes32 flightKey = getFlightKey(msg.sender, _flightname, _timestamp);
        flights[flightKey] = Flight(
            true,
            _flightname,
            STATUS_CODE_UNKNOWN,
            _timestamp,
            msg.sender
        );
        emit FlightRegistered(msg.sender, _flightname, _timestamp);
    }

    function fund()
        external
        payable
        isOperational
        isAirline
    {
        flightSuretyData
            .fund
            .value(msg.value)(msg.sender);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
        (
            address airline,
            string flight,
            uint256 timestamp,
            uint8 statusCode
        )
        internal
        //pure
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey].updatedTimestamp = block.timestamp;
        flights[flightKey].statusCode = statusCode;
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
        (
            address airline,
            string flight,
            uint256 timestamp
        )
        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    function buyInsurance
        (
            address _airlineAccount,
            string  _flight,
            uint256 _timestamp
        )
        external
        payable
        isOperational
    {
        require(!flightSuretyData.isAirline(msg.sender), "Caller is airline itself");
        require(block.timestamp < _timestamp, "Insurance is not before flight timestamp");
        require(msg.value <= 1 ether, "Value sent by caller is above insurance cost");
        require(msg.value != 0, "invalid value");
        bytes32 flightKey = getFlightKey(_airlineAccount, _flight, _timestamp);
        require(flights[flightKey].isRegistered == true, "Flight is not registered");
        flightSuretyData
            .buy
            .value(msg.value)(
                msg.sender,
                _airlineAccount,
                _flight,
                _timestamp
            );
    }

    function claimCredit(
        address _airlineAccount,
        string  _flight,
        uint256 _timestamp
    ) external
    isOperational {
        bytes32 flightKey = getFlightKey(_airlineAccount, _flight, _timestamp);
        require(flights[flightKey].statusCode == STATUS_CODE_LATE_AIRLINE, "Flight status is not late");
        //require(block.timestamp > flights[flightKey].updatedTimestamp, "Claim not allowed yet");
        flightSuretyData.creditInsurees(
            INSURANCE_RETURN_PERCENTAGE,
            _airlineAccount,
            _flight,
            _timestamp
        );
    }

    function withdrawCredits()
    external
    isOperational {
        require(flightSuretyData.getInsureePayoutCredits(msg.sender) > 0, "No credits available");
        flightSuretyData.pay(msg.sender);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            external
                            view
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
                "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "\nFlight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

interface FlightSuretyData {

    function isOperational() external view returns(bool);

    function isAirline(address airlineAccount) external view returns(bool);

    function isAirlineFunded(address airlineAccount) external view returns(bool);

    function getAirlinesCount() external view returns(uint256);

    function registerAirline(address airlineAccount, string airlineName) external;

    function buy(address insureeAccount, address airlineAccount, string airlineName, uint256 timestamp) external payable;

    function getAmountPaidByInsuree(address insureeAccount, address airlineAccount,
                                    string airlineName, uint256 timestamp) external view returns(uint256 amountPaid);

    function creditInsurees(uint256 creditPercentage, address airlineAccount, string airlineName, uint256 timestamp) external;

    function getInsureePayoutCredits(address insureeAccount) external view returns(uint256 amount);

    function pay(address insureeAccount) external;

    function fund(address airlineAccount) external payable;
}