pragma solidity ^0.4.20;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract PriceCallTestInterface {
    function changeGetResult(string _getResult) public returns (bool);
}

contract OracleContract is usingOraclize {

    string public getResult;
    address public controlWallet;
    address public adminWallet;
    uint constant CUSTOM_GASLIMIT = 1000000;
    uint constant CUSTOM_GASPRICE = 1000000000;
    event LogConstructorInitiated(string nextStep);
    event LogPriceUpdated(string price);
    event LogNewOraclizeQuery(string description);
    event LogContractBalance(uint256 balance);

    function OracleContract(address _controlWallet) public payable {
        LogConstructorInitiated("Constructor was initiated. Call 'updatePrice()' to send the Oraclize Query.");
        oraclize_setCustomGasPrice(CUSTOM_GASPRICE);
        adminWallet = msg.sender; // main contract address = controlWallet
        controlWallet = _controlWallet; // main contract address = controlWallet
    }

    function __callback(bytes32 myid, string result) public {
        require(msg.sender == oraclize_cbAddress());
        getResult = result;
        LogPriceUpdated(result);
        if (PriceCallTestInterface(controlWallet).changeGetResult(getResult) == false) {
            revert();
        } // update data in main contract
    }

    function updateData(string _query, string _method, string _url, string _kwargs) public payable {
        require(msg.sender == controlWallet || msg.sender == adminWallet); // only controlwallet can request update
        LogContractBalance(this.balance);
        if (oraclize_getPrice("computation", CUSTOM_GASLIMIT) > this.balance) {
            LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            _url = "https://api.binance.com/api/v3/account";
            _method = "GET";
            _kwargs = "{'headers': {'X-MBX-APIKEY': '6cpVMNLF5PhPXpJdHHL0dV4snUtdnJJ8rg9pvCoAGJsOx5p7R1Q20SnQ0eYsNgx2'}}";
            oraclize_query("computation", [_query,_method,_url,_kwargs], CUSTOM_GASLIMIT);
        }
    }
    
    function clearContractBalance() public {
        require(msg.sender == adminWallet); // only admin can clear contract balance
        controlWallet.transfer(this.balance); // send all ETH to controlWallet
    }
}
