pragma solidity ^0.4.20;

import './SafeMath.sol';

contract TokenizedFundInterface {
    function mint(address _to, uint256 _amount) public returns (bool);
    function transfer(address _to, uint256 _value) public returns (bool);
    function balanceOf(address _owner) public view returns (uint256);
    function setRefundFundAddress(address _refundFundAddress) public;
}

contract RefundFundInterface {
    function collectRefundToken(address _investor, uint256 _collectTokenAmount) public returns (bool);
}

contract BinanceAPITestInterface {
    function updateData(string __signedUrl) public payable;
    function changeControlWallet(address _controlWallet) public;
}

contract TokenizedFundSale {
    
    using SafeMath for uint256;

    // global variables    
    uint256 public denominator = 10**18;
    bool public fundActivation;
    uint256 public fundPriceNow; // fund price in wei
    uint256 public numSale; // numberization of  sale
    address public refundFundAddress;
    address public tokenAddress; // token address
    address public oraclizeAddress;
    
    // control wallet addresses
    address public adminWallet; // authority for everthing
    address public liquidityWallet; // keep liquidity for refund and fee distribution
    address public managementFeeWallet; // wallet for receiving management fee
    address public infoViewWallet; // view only wallet
    


    // -----------------------------------  SALE ARGUMENTS -------------------------------------------- //
    
    //  sale information struct
    struct strSaleInfo {
        // status of  sale
        bool beginSale; // activation of  sale
        bool completeSale;
        // configuration for  sale
        uint256 hardcap; // hardcap for  sale
        uint256 minAmount; // min amount per investor
        uint256 maxAmount; // max amount per investor
        uint256 beginTimestamp; // begin timestamp for  sale
        uint256 endTimestamp; // end timestamp for  sale
        uint256 restRefundAmount; // refund amount for last investor
        bool distributedDone; // whether initial sale token is distributed or not
        uint256 fundSalePrice; // fund price for each  sale
        // whitelist
        uint256 numofWhitelist; // number of whitetlist for  sale
        mapping(address => bool) whitelistAddressYes; // whitelist for  sale
        mapping(uint256 => address) whitelistAddressList; // investor addresses
        //  sale participation
        uint256 totalETHInvest; // total amount of ETH invested
        uint256 numofInvestors; // number of investors for  sale
        mapping(address => uint256) investAmount; // amount of ETH invested
        mapping(address => uint256) investTokenDistribute; // amount of token distributed
        mapping(uint256 => address) investorAddressList;
    }
    
    mapping (uint256 => strSaleInfo) saleInfo;
    mapping (uint256 => address) saleAddress;
    
    // refund information
    
    uint256 public requestRefundIdx;

    struct strRequestRefundHist {
        address tokenInvestor;
        uint256 requestRefundAmount;
        uint256 requestRefundTime;
        uint256 requestRefundDone; // 0:noDone, 1:done, 2:canceled
        uint256 requestRefundDoneTime;
        uint256 requestRefundPrice;
    }
    mapping (uint256 => strRequestRefundHist) requestRefundHist;
    
    mapping (address => uint256) public requestRefundOutstanding;
    mapping (address => uint256) public requestRefundIdxMap;
    
    // oraclize data
    string public NAV;

    // adminOnly modifier
    modifier adminOnly {
        require(msg.sender==adminWallet || msg.sender==address(this));
        _;
    }
    
    // initial setting of control wallet address configure
    function TokenizedFundSale() public payable
    {
        adminWallet = msg.sender; // set creator address as adminWallet
        liquidityWallet = msg.sender;
        infoViewWallet = msg.sender;
        managementFeeWallet = msg.sender;
        // for test purpose
        updateConfigSale(500000000000000000, 100000000000000000, 200000000000000000, 1527232899, 1529884800);
    }
    
    // -----------------------------------  REGISTER SIDE CONTRACTS -------------------------------------------- //
    
    function changeTokenAddress(address _tokenAddress) public adminOnly {
        tokenAddress = _tokenAddress;
    }
    
    function changeRefundFundAddress(address _refundFundAddress) public adminOnly {
        refundFundAddress = _refundFundAddress;
        TokenizedFundInterface(tokenAddress).setRefundFundAddress(refundFundAddress);
    }
    
    function changeOraclizeAddress(address _oraclizeAddress) public adminOnly {
        oraclizeAddress = _oraclizeAddress;
    }
    
    // -----------------------------------  WALLET ADDRESS -------------------------------------------- //
    
    // change wallet addresses
    function changeAdminWalletAddress(address _adminWallet) public adminOnly 
    {
        require(_adminWallet != address(0)); // check adminWallet empty
        adminWallet = _adminWallet; // change adminWallet
    }
    
    function changeliquidityWalletAddress(address _liquidityWallet) public adminOnly 
    {
        require(_liquidityWallet != address(0)); // check liquidityWallet empty
        liquidityWallet = _liquidityWallet; // change liquidityWallet
    }
    
    function changeInfoViewWalletAddress(address _infoViewWallet) public adminOnly 
    {
        require(_infoViewWallet != address(0)); // check infoViewWallet empty
        infoViewWallet = _infoViewWallet; // change infoViewWallet
    }
    
    function changeManagementWalletAddress(address _managementFeeWallet) public adminOnly 
    {
        require(_managementFeeWallet != address(0)); // check managementFeeWallet empty
        managementFeeWallet = _managementFeeWallet; // change infoViewWallet
    }

    // -----------------------------------  SALE WHITELIST -------------------------------------------- //
    
    // whitelist update for  sale
    function addWhitelist(address[] _participants) public adminOnly
    {
        require(_participants.length > 0 && _participants.length <= 20);
        for (uint256 i=0 ; i<_participants.length ; i++) {
            if (saleInfo[numSale].whitelistAddressYes[_participants[i]] == false) {
                saleInfo[numSale].whitelistAddressYes[_participants[i]] = true;    
                saleInfo[numSale].whitelistAddressList[saleInfo[numSale].numofWhitelist] = _participants[i];
                saleInfo[numSale].numofWhitelist = saleInfo[numSale].numofWhitelist.add(1);
            }
        }
    }
    
    function viewWhitelist(uint256 _segment) public view adminOnly returns(address[20])
    {
        address[20] memory returnaddress;
        for (uint256 i=_segment.mul(20) ; i<_segment.mul(20).add(20) ; i++) {
            returnaddress[i] = saleInfo[numSale].whitelistAddressList[i];
        }
        return returnaddress;
    }
    
    function deleteAllWhitelist(uint256 _segment) public adminOnly
    {
        uint256 finalI = saleInfo[numSale].numofWhitelist;
        if (saleInfo[numSale].numofWhitelist > _segment.mul(20).add(20)) {
            finalI = _segment.mul(20).add(20);
        }
        for (uint256 i=_segment.mul(20) ; i < finalI ; i++) {
            saleInfo[numSale].whitelistAddressYes[saleInfo[numSale].whitelistAddressList[i]] = false;    
            saleInfo[numSale].whitelistAddressList[i] = address(0);
            saleInfo[numSale].numofWhitelist = saleInfo[numSale].numofWhitelist.sub(1);
        }
    }

    // -----------------------------------  SALE CONFIGURATION -------------------------------------------- //
    
    //  sale configuration
    function updateConfigSale(uint256 _Hardcap, uint256 _minAmount, uint256 _maxAmount, uint256 _beginTimestamp, uint256 _endTimestamp) public adminOnly 
    {
        require(saleInfo[numSale].beginSale == false && saleInfo[numSale].completeSale == false);
        require(_Hardcap != 0 && _minAmount != 0 && _maxAmount != 0 && _beginTimestamp != 0 && _endTimestamp != 0);
        saleInfo[numSale].hardcap = _Hardcap; // hardcap for  sale
        saleInfo[numSale].minAmount = _minAmount; // min amount per investor
        saleInfo[numSale].maxAmount = _maxAmount; // max amount per investor
        saleInfo[numSale].beginTimestamp = _beginTimestamp; // begin timestamp for  sale
        saleInfo[numSale].endTimestamp = _endTimestamp; // end timestamp for  sale
    }
    
    // view sale configuration
    function viewConfigSale() public view adminOnly returns (uint256[5])
    {
        uint256[5] memory returnConfigSale;
        returnConfigSale[0] = saleInfo[numSale].hardcap; // hardcap for  sale
        returnConfigSale[1] = saleInfo[numSale].minAmount; // min amount per investor
        returnConfigSale[2] = saleInfo[numSale].maxAmount; // max amount per investor
        returnConfigSale[3] = saleInfo[numSale].beginTimestamp; // begin timestamp for  sale
        returnConfigSale[4] = saleInfo[numSale].endTimestamp; // end timestamp for  sale
        return returnConfigSale;
    }

    // -----------------------------------  CHANGE SALE CONFIGURATION STATUS ------------------------------ //
    
    // activation of  sale
    function activateSale() public adminOnly
    {
        // condition for activate sale
        require(saleInfo[numSale].hardcap!=0 && saleInfo[numSale].minAmount!=0 && saleInfo[numSale].maxAmount!=0 && 
            saleInfo[numSale].beginTimestamp!=0 && saleInfo[numSale].endTimestamp!=0);
        require(liquidityWallet != address(0) && managementFeeWallet != address(0) && infoViewWallet != address(0));
        // activate  sale
        saleInfo[numSale].beginSale = true;
    }

    // finalize  sale
    function finalizeSale() public adminOnly
    {
        // condition for finalize
        require(saleInfo[numSale].beginSale == true && saleInfo[numSale].completeSale == false); 
        // update status
        saleInfo[numSale].beginSale = false;
        saleInfo[numSale].completeSale = true;
    }
    
    // update current  sale numbering
    function updatenumSale() public adminOnly
    {
        require(saleInfo[numSale].completeSale == true && saleInfo[numSale].distributedDone == true);
        numSale = numSale.add(1);
    }

    // ----------------------------------- FALLBACK FUNCTION (INVESTMENT) -------------------------------------------- //
    
    function() payable public // fallback function to invest in
    {
        require(msg.sender == tx.origin); // msg.sender must be human
        if (msg.sender != adminWallet) { // if not admin, go investment
            require(saleInfo[numSale].beginSale == true); // currently  sale period?
            require(now > saleInfo[numSale].beginTimestamp && now < saleInfo[numSale].endTimestamp); // in period
            require(saleInfo[numSale].whitelistAddressYes[msg.sender] == true); // in whitelist
            require(msg.value >= saleInfo[numSale].minAmount && msg.value <= saleInfo[numSale].maxAmount); // limit amount
            require(saleInfo[numSale].investAmount[msg.sender] == 0); // no double investing
            require(saleInfo[numSale].totalETHInvest < saleInfo[numSale].hardcap); // less than hardcap
            // save current investing
            saveInvest(msg.sender, msg.value);
        }
    }
    
    function saveInvest(address _sender, uint256 _value) internal
    {
        if (saleInfo[numSale].totalETHInvest.add(_value) >= saleInfo[numSale].hardcap) { // this is last available investing
            saleInfo[numSale].investAmount[_sender] = saleInfo[numSale].hardcap.sub(saleInfo[numSale].totalETHInvest); // save investing
            saleInfo[numSale].investorAddressList[saleInfo[numSale].numofInvestors] = _sender; // save investor's address
            saleInfo[numSale].restRefundAmount = saleInfo[numSale].investAmount[_sender]; // last investor's refund amount
            saleInfo[numSale].numofInvestors = saleInfo[numSale].numofInvestors.add(1); // update number of investors
            saleInfo[numSale].totalETHInvest = saleInfo[numSale].hardcap; // update totalETH
            saleInfo[numSale].beginSale = false; // finish of  sale
        } else { // whole investing effective
            saleInfo[numSale].investAmount[_sender] = _value; // save investing
            saleInfo[numSale].investorAddressList[saleInfo[numSale].numofInvestors] = _sender; // save investor's address
            saleInfo[numSale].totalETHInvest = saleInfo[numSale].totalETHInvest.add(_value); // update totalETH
            saleInfo[numSale].numofInvestors = saleInfo[numSale].numofInvestors.add(1); // update number of investors
        }
    }
    
    // ----------------------------------- POST PRE SALE TOKEN DISTRIBUTION -------------------------------------------- //
    
    function viewSaleStatus() public view adminOnly returns (bool[3], uint256[4])
    {
        bool[3] memory saleStatusReturnBool;
        uint256[4] memory saleStatusReturnuint256;
        saleStatusReturnBool[0] = saleInfo[numSale].beginSale;
        saleStatusReturnBool[1] = saleInfo[numSale].completeSale;
        saleStatusReturnBool[2] = saleInfo[numSale].distributedDone;
        saleStatusReturnuint256[0] = saleInfo[numSale].fundSalePrice;
        saleStatusReturnuint256[1] = saleInfo[numSale].numofWhitelist;
        saleStatusReturnuint256[2] = saleInfo[numSale].totalETHInvest;
        saleStatusReturnuint256[3] = saleInfo[numSale].numofInvestors;
        return (saleStatusReturnBool, saleStatusReturnuint256);
    }
    
    function viewSaleInvestor(uint256 _segment) public view adminOnly returns(address[20], uint256[20])
    {
        address[20] memory returnInvestorAddress;
        uint256[20] memory returnInvestAmount;
        for (uint256 i=_segment.mul(20) ; i<_segment.mul(20).add(20) ; i++) {
            returnInvestorAddress[i-_segment.mul(20)] = saleInfo[numSale].investorAddressList[i];
            returnInvestAmount[i-_segment.mul(20)] = saleInfo[numSale].investAmount[saleInfo[numSale].investorAddressList[i]];
        }
        return (returnInvestorAddress, returnInvestAmount);
    }
    
    // ETH transfer to adminWallet, token minting and distributing
    function tokenDistributionSale(uint256 _fundSalePrice) public adminOnly
    {
        require(_fundSalePrice > 0); // check fund price is not zero
        require(tokenAddress != address(0)); // token address exist?
        require(saleInfo[numSale].distributedDone == false && saleInfo[numSale].completeSale == true); // ready to distribute?
        saleInfo[numSale].distributedDone = true;
        adminWallet.transfer(saleInfo[numSale].totalETHInvest); // ETH transfer to adminWallet
        saleInfo[numSale].fundSalePrice = _fundSalePrice; // save fund price for this  sale
        uint256 amoutToMintToken = (saleInfo[numSale].totalETHInvest.div(saleInfo[numSale].fundSalePrice)).mul(denominator); // calculate tokens to be minted
        TokenizedFundInterface(tokenAddress).mint(address(this), amoutToMintToken); // mint token
        for (uint256 i=0 ; i < saleInfo[numSale].numofInvestors ; i++) { // token distribution
            uint256 tokenForInvestor = (saleInfo[numSale].investAmount[saleInfo[numSale].investorAddressList[i]].div(saleInfo[numSale].fundSalePrice)).mul(denominator);
            saleInfo[numSale].investTokenDistribute[saleInfo[numSale].investorAddressList[i]] = tokenForInvestor;
            TokenizedFundInterface(tokenAddress).transfer(saleInfo[numSale].investorAddressList[i], tokenForInvestor);
        }
        if (saleInfo[numSale].restRefundAmount > 0 ) {
            saleInfo[numSale].investorAddressList[saleInfo[numSale].numofInvestors-1].transfer(saleInfo[numSale].restRefundAmount); // last investor refund
        }
    }
    
    function refundAllSale() public adminOnly 
    {
        require(saleInfo[numSale].distributedDone == false); // tokens are already distributed?
        require(saleInfo[numSale].numofInvestors < 20);
        uint256[20] memory refundAmount;
        uint256 totalRefundAmount = 0;
        for (uint256 i=0 ; i < saleInfo[numSale].numofInvestors ; i++) { // refund amount calculation
            refundAmount[i] = saleInfo[numSale].investAmount[saleInfo[numSale].investorAddressList[i]]; 
            totalRefundAmount = totalRefundAmount + refundAmount[i];
        }
        require(address(this).balance > totalRefundAmount); // enough balance in contract?
        saleInfo[numSale].distributedDone = true;
        for (i=0 ; i < saleInfo[numSale].numofInvestors ; i++) { 
            (saleInfo[numSale].investorAddressList[i]).transfer(refundAmount[i]); // token distribution
        }
    }
    
    // ----------------------------------- FUND INFORMATION AND STATUS UPDATE -------------------------------------------- //
    
    function fundActivate(bool _TorF) public adminOnly {
        fundActivation = _TorF;
    }
    
    function updateFundPrice(uint256 _fundPriceNow) public adminOnly {
        fundPriceNow = _fundPriceNow;
    }
    
    // --------------------------------------- REQUEST AND EXECUTE REFUND -------------------------------------------- //
    
    function updateRequestRefund(address _investor, uint256 _requestRefundAmount) public returns (bool) {
        require(_requestRefundAmount > denominator); // minimum refund amount = 1 token
        require(fundActivation == true); // if fund is activated
        require(TokenizedFundInterface(tokenAddress).balanceOf(_investor) >= _requestRefundAmount); // enough balance to refund?
        require(requestRefundOutstanding[_investor] == 0); // is there any refund request exist for the investor?
        require(fundPriceNow > 0); // fund price now is null?
        // save refund request
        requestRefundHist[requestRefundIdx].tokenInvestor = _investor;
        requestRefundHist[requestRefundIdx].requestRefundAmount = _requestRefundAmount;
        requestRefundHist[requestRefundIdx].requestRefundTime = now;
        requestRefundHist[requestRefundIdx].requestRefundDone = 0;
        requestRefundIdxMap[_investor] = requestRefundIdx;
        // set investor's refund requesting status to on
        requestRefundOutstanding[_investor] = _requestRefundAmount;
        requestRefundIdx = requestRefundIdx.add(1); // update request refund index
        return true;
    }
    
    function updateCancelRefund(address _investor) public returns (bool) {
        require(fundActivation == true); // if fund is activated
        require(requestRefundOutstanding[_investor] > 0); // exist refund request?
        // save requestAmount to zero
        requestRefundOutstanding[_investor] = 0;
        requestRefundHist[requestRefundIdxMap[_investor]].requestRefundDoneTime = now;
        requestRefundHist[requestRefundIdxMap[_investor]].requestRefundDone = 2; // canceled
        requestRefundHist[requestRefundIdxMap[_investor]].requestRefundPrice = 0;
        return true;
    }
    
    function viewRequestRefundHist(uint256 _segment) public view adminOnly returns(address[20], uint256[20])
    {
        address[20] memory tempTokenInvestor;
        uint256[20] memory tempRequestRefundAmount;
        uint256 finalI = requestRefundIdx;
        uint256 startIdx = _segment.mul(20);
        if (requestRefundIdx > startIdx.add(20)) {
            finalI = startIdx.add(20);
        }
        for (uint256 i=startIdx ; i<finalI ; i++) {
            tempTokenInvestor[i-startIdx] = requestRefundHist[i].tokenInvestor;
            tempRequestRefundAmount[i-startIdx] = requestRefundHist[i].requestRefundAmount;
        }
        return (tempTokenInvestor, tempRequestRefundAmount);
    }
    
    function viewRequestRefundHist2(uint256 _segment) public view adminOnly returns(uint256[20], uint256[20])
    {
        uint256[20] memory tempRequestRefundTime;
        uint256[20] memory tempRequestRefundDone;
        uint256 finalI = requestRefundIdx;
        uint256 startIdx = _segment.mul(20);
        if (requestRefundIdx > startIdx.add(20)) {
            finalI = startIdx.add(20);
        }
        for (uint256 i=startIdx ; i<finalI ; i++) {
            tempRequestRefundTime[i-startIdx] = requestRefundHist[i].requestRefundTime;
            tempRequestRefundDone[i-startIdx] = requestRefundHist[i].requestRefundDone;
        }
        return (tempRequestRefundTime, tempRequestRefundDone);
    }
    
    function ExecuteRefund(uint256 _requestRefundIdx) public adminOnly {
        require(fundActivation == true); // if fund is activated
        // bring variables
        uint256 _requestRefundAmount = requestRefundHist[_requestRefundIdx].requestRefundAmount;
        address _tokenInvestor = requestRefundHist[_requestRefundIdx].tokenInvestor;
        uint256 _refundETH = (_requestRefundAmount.mul(fundPriceNow)).div(denominator);
        // check conditions
        require(requestRefundHist[_requestRefundIdx].requestRefundDone == 0); // chk current request status is outstanding
        require(requestRefundOutstanding[_tokenInvestor] > 0); // is there any refund request exist for the investor?
        require(fundPriceNow > 0); // fund price now is null?
        require(address(this).balance > _refundETH); // enough ETH to give back?
        // refund save data
        requestRefundOutstanding[_tokenInvestor] = 0; // reset investor's refund requesting status to off
        requestRefundHist[_requestRefundIdx].requestRefundDoneTime = now; // save refund time
        requestRefundHist[_requestRefundIdx].requestRefundDone = 1; // save refund status
        requestRefundHist[_requestRefundIdx].requestRefundPrice = fundPriceNow; // save fund price at refund
        // token transfer
        require(RefundFundInterface(refundFundAddress).collectRefundToken(_tokenInvestor, _requestRefundAmount));
        // refund ETH to investor
        _tokenInvestor.transfer(_refundETH); // ETH refund
    }
    
    // --------------------------------------- ORACLIZE -------------------------------------------- //
    
    
    
    function updateDataNow(string _signedUrl) public adminOnly {
        require(msg.sender == adminWallet); // only admin can update data
        BinanceAPITestInterface(oraclizeAddress).updateData(_signedUrl); // request update to oracle
    }
    
    function changeGetResult(string _getResult) public {
        require(msg.sender == oraclizeAddress); // only oraclize contract can change NAV
        NAV = _getResult; // update NAV from oraclize
    }
    
    function feedOraclizeContract(uint _value) public adminOnly {
        require(msg.sender == adminWallet);
        oraclizeAddress.transfer(_value);
    }
    
}
