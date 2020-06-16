
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Watch contract events
    
  });
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;


  it('can register oracles', async () => {
    
    // ARRANGE
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`${a}: Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
    }
  });

  it('can request flight status', async () => {
    
    // ARRANGE
    let flight = 'ND1309'; // Course number
    let timestamp = Math.floor(Date.now() / 1000);

    var success = 0;
    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, flight, timestamp);
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, flight, timestamp, STATUS_CODE_ON_TIME, { from: accounts[a] });
          success += 1;
          console.log('Success', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }
        catch(e) {
          // Enable this when debugging
          //console.log(e)
          console.log('Error', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
        }

      }
    }
    assert.equal(success != 0, true, "no successful oracle response");
  });

  

  it('can request future flight status', async () => {
    
    // ARRANGE
    let flight = 'flight1'; // Course number
    //let time = Math.trunc(((new Date()).getTime() + 3 * 3600) / 1000);

    // Submit a request for oracles to get status information for a flight
    await config.flightSuretyApp.fetchFlightStatus(config.firstAirline, flight, config.flightTime);
    // ACT
    var success = 0;
    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {

      // Get oracle information
      let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a]});
      for(let idx=0;idx<3;idx++) {

        try {
          // Submit a response...it will only be accepted if there is an Index match
          await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.firstAirline, flight, config.flightTime, STATUS_CODE_LATE_AIRLINE, { from: accounts[a] });
          success += 1;
          console.log('Success', idx, oracleIndexes[idx].toNumber(), flight, config.flightTime);
        }
        catch(e) {
          // Enable this when debugging
          console.log(e)
          console.log('Error', idx, oracleIndexes[idx].toNumber(), flight, config.flightTime);
        }

      }
    }
    assert.equal(success != 0, true, "no successful oracle response");
  });

 
//});

//contract('Flight Surety Tests after oracle eval', async (accounts) => {

  it(`(passenger) claim credit`, async function () {

    
    // Get operating status
    let status = await config.flightSuretyApp.claimCredit(config.firstAirline, "flight1", config.flightTime);
    assert.equal(status, true, "Incorrect initial operating status value");

  });
 
});