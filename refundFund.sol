pragma solidity ^0.4.20;

import "./TokenizedFund.sol";

contract TokenizedFundSaleInterface {
    function updateRequestRefund(address _investor, uint256 _requestRefundAmount) public returns (bool);
    function updateCancelRefund(address _investor) public returns (bool);
}

contract TokenizedFundInterface {
    function superTransfer(address _from, address _to, uint256 _value) public returns (bool);
    function transfer(address _to, uint256 _value) public returns (bool);
}

contract RefundFund {
    
    address public TokenizedFundSaleAddress;
    address public tokenAddress;
    mapping (address => uint256) public tokenForRefund;


    function RefundFund(address _TokenizedFundSaleAddress, address _tokenAddress) public {
        TokenizedFundSaleAddress = _TokenizedFundSaleAddress;   
        tokenAddress = _tokenAddress;
    }
    
    function requestRefund(uint256 _requestRefundAmount) public {
        require(tokenForRefund[msg.sender] == 0);
        // update request refund
        require(TokenizedFundSaleInterface(TokenizedFundSaleAddress).updateRequestRefund(msg.sender, _requestRefundAmount));
        tokenForRefund[msg.sender] = _requestRefundAmount;
        // token transfer
        require(TokenizedFundInterface(tokenAddress).superTransfer(msg.sender, address(this), _requestRefundAmount));
    }
    
    function cancelRefund() public {
        uint256 _requestRefundAmount = tokenForRefund[msg.sender];
        // update request refund
        require(TokenizedFundSaleInterface(TokenizedFundSaleAddress).updateCancelRefund(msg.sender));
        // token transfer
        tokenForRefund[msg.sender] = 0;
        require(TokenizedFundInterface(tokenAddress).transfer(msg.sender, _requestRefundAmount));
    }
    
    function collectRefundToken(address _investor, uint256 _collectTokenAmount) public returns (bool) {
        require(msg.sender == TokenizedFundSaleAddress);
        tokenForRefund[_investor] = 0;
        require(TokenizedFundInterface(tokenAddress).transfer(TokenizedFundSaleAddress, _collectTokenAmount));
        return true;
    }
    
}
