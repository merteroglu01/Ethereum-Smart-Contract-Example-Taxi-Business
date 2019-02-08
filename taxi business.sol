pragma solidity >=0.4.22 <0.6.0;

contract TaxiBusiness{
    
    struct propesedCar{
       uint32 carID;
       uint price;
       uint validTime;
    }
   
    struct propesedPurchase{
       uint32 carID;
       uint price;
       uint validTime;
       bool approval;
    }
   
    struct participant{
       uint balance;
       uint lastwithdrawal;
    }
   
    mapping (address => participant) public participants;
    
    mapping (address => bool) public votes;
    
    uint public participantsNumber;
    
    address payable public owner;
    
    address payable public manager;
    
    address payable public taxiDriver;
    
    // driver's account that holds his salary.
    uint taxiAccountBalance;
    
    address payable public carDealer;
    
    // fixed driver salary.
    uint driverSalary;
    
    uint public contractBalance;
    
    // net profit that divided by number of participants
    uint public dividend;
    
    // holds how many participants approved
    uint public approveCount;
    
    // fixed expenses
    uint public expenses = 10 ether;
    
    uint32 public carID;
    
    propesedCar propCar;
    
    propesedPurchase propPurchase;
    
    // time that last salary paid to driver
    uint lastDriverSalaryPayment;
    
    // time that last car expenses paid to car dealer
    uint lastCarExpensesPaid;
    
    // time that net profit calculated last time;
    uint lastPayDividend;
       
       
    // constructor
    constructor(address payable _manager) payable public{
        owner = msg.sender;
        manager = _manager;
        // some time needed to pass to pay expenses or get salary etc.
        // times are initialized when contract created.
        lastDriverSalaryPayment = now;
        lastCarExpensesPaid = now;
        lastPayDividend = now;
        // fixed driver's salary
        driverSalary = 1 szabo;
    }
    
    // to prevent re-entering the business.
    modifier isAccountExists(){
        require(!(participants[msg.sender].balance > 0));
        _;
    }
    // check if user sending correct amount
    modifier balanceOkey(){
        require(msg.value == 1 ether);
        _;
    }
    
    // max 100 participants rule
    modifier isContractFull(){
        require(participantsNumber < 100);
        _;
    }
    
    modifier onlyManager(){
        require(msg.sender == manager);
        _;
    }
    
    modifier onlyTaxiDriver(){
        require(msg.sender == taxiDriver);
        _;
    }
    
    modifier onlyParticipants(){
        require(participants[msg.sender].balance > 0);
        _;
    }
    
    // prevent re-vote
    modifier checkUserVotedAlready(){
        require(!votes[msg.sender]);
        _;
    }
    
    modifier onlyCarDealer(){
        require(msg.sender == carDealer);
        _;
    }
    // join the business
    function join()  isAccountExists balanceOkey isContractFull payable public{
        participants[msg.sender].balance = 1 wei;
        participants[msg.sender].lastwithdrawal = now;
        // add participation fee to contract balance
        contractBalance += 1 ether;
        // increment participation number
        participantsNumber++;
       
    }
    
    // manager sets car dealer address
    function setCarDealer(address payable _carDealer) onlyManager public{
        carDealer = _carDealer;
    }
    
    
    function carPropose(uint32 _carID, uint _price, uint _validTime) onlyCarDealer public{
        propCar.carID = _carID;
        propCar.price = _price;
        propCar.validTime = _validTime;
    }
    
    function purchaseCar() onlyManager payable public{
        // check if propose valid
        require(now >= propCar.validTime);
        // decrease the money of car from contract balance
        contractBalance -= propCar.price;
        // transfer to carDealer
        carDealer.transfer(propCar.price);
		// set current carID
        carID = propCar.carID;
    }
    
    function purchasePropose(uint32 _carID, uint _price, uint _validTime) onlyCarDealer public{
        propPurchase.carID = _carID;
        propPurchase.price = _price;
        propPurchase.validTime = _validTime;
        propPurchase.approval = false;
    }
    
    function approveSellProposel() onlyParticipants checkUserVotedAlready public{
        // increment approve count
        approveCount++;
        // prevent re-vote
        votes[msg.sender] = true;
    }
    
    function sellCar() onlyCarDealer payable public{
        // check user balance is enough
        require(msg.sender.balance >= propPurchase.price);
        // check msg value is okey
        require(msg.value == propPurchase.price);
        // check selling is approved
        require(approveCount > participantsNumber/2);
        // check is offer still valid 
        require(now >= propPurchase.validTime);
        // increment money of contract
        contractBalance += propPurchase.price;
        // sets approve to 0 for next propose
        approveCount = 0;
    }
    
    function setDriver(address payable _driverAddress) onlyManager public{
        taxiDriver = _driverAddress;
    }
    
    function getCharge() payable public{
        // check money is okey
        require(msg.value > 0);
        contractBalance += msg.value;
    }
    
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }
    
    function paySalary() onlyManager public{
        // check the time 
        require(now >= lastDriverSalaryPayment + 30 days);
        // add money to driver account
        taxiAccountBalance += driverSalary;
        // update the time to prevent invalid calls
        lastDriverSalaryPayment = now;
    }
    
    function getSalary() onlyTaxiDriver payable public{
        // if account is not empty get money
        if(taxiAccountBalance > 0){
            taxiDriver.transfer(taxiAccountBalance);
            contractBalance -= driverSalary;
            taxiAccountBalance = 0;
        }
    }
    
    function carExpenses() onlyManager payable public{
        // confirm payment process of expenses to car dealer in order to make car dealer can take the money
        // check last confirm time to prevent invalid confirmation
        require(now >= lastCarExpensesPaid + (180 days)); // 6 months
        if(carDealer.send(expenses)){
            // update the time
            lastCarExpensesPaid = now;
            contractBalance -= expenses;
        }
    }
    
    function payDividend() onlyManager public{
        // check time to prevent invalid calls
        require(now >= lastPayDividend + (180 days));
        uint profit = contractBalance;
        // decrease driver salary and expenses if the payment time of those has come
        if(now >= lastCarExpensesPaid + (180 days)){
           profit -= expenses;
        }
        if(now >= lastDriverSalaryPayment + 30 days){
           profit -= driverSalary;
        }
        // calculate net profit for every participants
        dividend = profit/participantsNumber;
        // update the time
        lastPayDividend = now;
    }
    
    
    function getDividend() onlyParticipants payable public{
        // check if user allready the his/her dividend
        require(participants[msg.sender].lastwithdrawal <= lastPayDividend);
        // if the money is not taken
        require(dividend > 0);
        // update time to prevent recalls
        participants[msg.sender].lastwithdrawal = now;
        // send money
        msg.sender.transfer(dividend);
        contractBalance -= dividend;
    }
    
    function() payable external{ 
        revert();
    }

}
