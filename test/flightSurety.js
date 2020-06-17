
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) setOperatingStatus() `, async function () {

    // set operating status
    try 
    {
        await config.flightSuretyData.setOperatingStatus(true, {from: config.owner});
    }
    catch(e)
    {
       // console.log(e)
    }
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

    it('(airline) isAirline', async () =>
    {
        let result = await config.flightSuretyData.isAirline(config.firstAirline);
        assert.equal(result, true, "firstairline should be registared")
    });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
    
  it('(airline) fund airline', async () => {
    
    // ARRANGE
    
    // ACT
    try {
        await config.flightSuretyApp.fund({from: config.firstAirline, value: 1});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline); 
    // ASSERT
    assert.equal(result, true, "Airline should be funeded");

  });

  it('(airline) register an Airline using registerAirline() ', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, "AIR2", {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, true, "Airline should be registered");

  });

  it('(airline) fund new airline ', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.fund({from: newAirline, value: 2});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineFunded.call(newAirline); 

    // ASSERT
    assert.equal(result, true, "Airline should be registered");

  });

  it('(airline) register airlines for voting', async () => {
    
    // ARRANGE
    let newAirline  = accounts[2];
    let newAirline2 = accounts[3];
    let newAirline3 = accounts[4];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline2, "AIR3", {from: newAirline});
        await config.flightSuretyApp.registerAirline(newAirline3, "AIR4", {from: config.firstAirline});
    }
    catch(e) {

    }
    let result2 = await config.flightSuretyData.isAirline.call(newAirline2); 
    let result3 = await config.flightSuretyData.isAirline.call(newAirline3); 

    // ASSERT
    assert.equal(result2, true, "Airline2 should be registered");
    assert.equal(result3, true, "Airline3 should be registered");

  });

  it('(airline) try register airline before voting', async () => {
    
    // ARRANGE
    let newAirline4 = accounts[5];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline4, "AIR5", {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirline.call(newAirline4);
   
    // ASSERT
    assert.equal(result, false, "Airline should not be registered (voting)");

  });

    it('(airline) vote', async () => {
        
        // ARRANGE
        let newAirline  = accounts[2];
        let newAirline2 = accounts[3];
        let newAirline3 = accounts[4];
        let newAirline4 = accounts[5];

        //var mEvent1 = config.flightSuretyApp.Voted()
        //await mEvent1.watch((err, res) => {
        //    console.log(log);
        //    console.error(err);
        //})


        // ACT
        await config.flightSuretyApp.registerAirline(newAirline4, "AIR5", {from: newAirline  });
        try{
            await config.flightSuretyApp.registerAirline(newAirline4, "AIR5", {from: newAirline2 });
        }
        catch(e)
        {}
        //await config.flightSuretyApp.addVote(newAirline4, {from: config.newAirline3 });
       
        let result = await config.flightSuretyData.isAirline.call(newAirline4);
    
        // ASSERT
        assert.equal(result, true, "Airline should be registered (voting)");

    });

    

    
});
