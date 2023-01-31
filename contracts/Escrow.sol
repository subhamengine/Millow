//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _id) external;
}

contract Escrow {
    address public lender;
    address public inspector;
    address payable public seller;
    address public nftAddress;

    modifier onlySeller() {
        require(msg.sender == seller, "Only Seller can call this method");
        _;
    }
    modifier onlyBuyer(uint256 _nftID) {
        require(msg.sender == buyer[_nftID], "Only Buyer can call this method");
        _;
    }
    modifier onlyInspector() {
        require(msg.sender == inspector, "Only Inspector can call this method");
        _;
    }

    mapping(uint256 => bool) public isListed;
    mapping(uint256 => uint256) public purchasePrice;
    mapping(uint256 => uint256) public escrowAmount;
    mapping(uint256 => address) public buyer;
    mapping(uint256 => bool) public inspectionPassed;
    mapping(uint256 => mapping(address => bool)) approval;

    constructor(
        address _nftAddress,
        address payable _seller,
        address _inspector,
        address _lender
    ) {
        nftAddress = _nftAddress;
        seller = _seller;
        inspector = _inspector;
        lender = _lender;
    }

    function list(
        uint256 _nftId,
        uint256 _purchasePrice,
        address _buyer,
        uint256 _escrowAmount
    ) public payable onlySeller {
        //transfer the NFT from seller to the Escrow

        IERC721(nftAddress).transferFrom(msg.sender, address(this), _nftId);

        isListed[_nftId] = true;
        purchasePrice[_nftId] = _purchasePrice;
        escrowAmount[_nftId] = _escrowAmount;
        buyer[_nftId] = _buyer;
    }

    function depositEarnest(uint256 _nftID) public payable onlyBuyer(_nftID) {
        //only buyer can do this
        require(msg.value >= escrowAmount[_nftID]);
    }

    receive() external payable {}

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function updateInspectionStatus(
        uint256 _nftId,
        bool _passed
    ) public onlyInspector {
        inspectionPassed[_nftId] = _passed;
    }

    function approveSale(uint256 _nftID) public {
        approval[_nftID][msg.sender] = true;
    }

    // function approved(uint256 _nftId, address _add) public returns (bool) {
    //     return approval[_nftId][_add];
    // }

    function finalizeSale(uint256 _nftID) public {
        require(
            inspectionPassed[_nftID],
            "In Finalize sale, Inspection did't pass!"
        );

        require(
            approval[_nftID][buyer[_nftID]],
            "In Finalize sale, Buyer did'nt approve"
        );

        require(
            approval[_nftID][seller],
            "In Finalize sale, Seller did'nt approve!"
        );

        require(
            approval[_nftID][lender],
            "In Finalize sale, lender did'nt approve!"
        );

        require(
            address(this).balance >= purchasePrice[_nftID],
            "In Finalize sale, Fund is insufficient!"
        );

        isListed[_nftID] = false;

        //transfering fund to seller
        (bool success, ) = payable(seller).call{value: address(this).balance}(
            ""
        );
        require(success);

        IERC721(nftAddress).transferFrom(address(this), buyer[_nftID], _nftID);
    }

    function cancelSale(uint256 _nftID) public {
        if (inspectionPassed[_nftID] == false) {
            payable(buyer[_nftID]).transfer(address(this).balance);
        } else {
            payable(seller).transfer(address(this).balance);
        }
    }
}
