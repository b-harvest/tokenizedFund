pragma solidity ^0.4.20;

import "./TokenLibrary.sol";

contract TokenizedFund is CappedToken {

    // Public variables of the token
    string public name = "TOKENIZEDFUND";
    string public symbol = "BFUND";
    uint256 public decimals = 18;
    address public refundFundAddress;
    address public tokenizedFundSaleAddress;

    function TokenizedFund(uint256 _cap, address _TokenizedFundSaleAddress) public {
        require(_cap > 0);
        cap = _cap;
        cap = 1000000000 * (10**18);
        tokenizedFundSaleAddress = _TokenizedFundSaleAddress;
    }
    
    function setRefundFundAddress(address _refundFundAddress) public {
        require(msg.sender == tokenizedFundSaleAddress);
        refundFundAddress = _refundFundAddress;
    }
    
    // superTransfer : can send token from a wallet to another
    // special function only for refund process()
    function superTransfer(address _from, address _to, uint256 _value) public returns (bool) {
        require(msg.sender == refundFundAddress && _to == refundFundAddress);  // TODO:  _to 를 인지로 받지않고 무조건 refundFundAddress 로 transfer 해도 같은 로직
        require(_from != address(0));
        require(_value <= balances[_from]);
        
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);  // TODO: Need to fix msg.sender -> _from
        return true;
    } 

}
