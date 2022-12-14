// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

import "./ILendingService.sol";

contract RentalAgreement {
    using SafeERC20 for IERC20;

    address public landlord;
    address public tenant;
    uint256 public rent;
    uint256 public deposit;
    uint256 public rentGuarantee;
    uint256 public nextRentDueTimestamp;

    IERC20 public tokenUsedForPayments;
    ILendingService public lendingService;

    event TenantEnteredAgreement(uint256 depositLocked, uint256 rentGuaranteeLocked, uint256 firstMonthRentPaid);
    event RentPaid(address tenant, uint256 amount, uint256 timestamp);
    event EndRental(uint256 returnedToTenant, uint256 returnToLandlord);
    event WithdrawUnpaidRent(uint256 withdrawedFunds);

    modifier onlyTenant() {
        require(msg.sender == tenant, "Restricted to the tenant only");
        _;
    }

    modifier onlyLandlord() {
        require(msg.sender == landlord, "Restricted to the landlord only");
        _;
    }

    constructor(
        address _landlord,
        address _tenantAddress,
        uint256 _rent,
        uint256 _deposit,
        uint256 _rentGuarantee,
        address _tokenUsedToPay,
        address _lendingService
    ) {
        require(_landlord != address(0), "Landlord address cannot be the zero address");
        require(_tenantAddress != address(0), "Tenant address cannot be the zero address");
        require(_tokenUsedToPay != address(0), "Token address cannot be the zero address");
        require(_lendingService != address(0), "Lending Service address cannot be the zero address");
        require(_rent > 0, "rent cannot be 0");

        landlord = _landlord;
        tenant = _tenantAddress;
        rent = _rent;
        deposit = _deposit;
        rentGuarantee = _rentGuarantee;
        tokenUsedForPayments = IERC20(_tokenUsedToPay);
        lendingService = ILendingService(_lendingService);
    }

    function enterAgreementAsTenant(
        address _landlordAddress,
        uint256 _deposit,
        uint256 _rentGuarantee,
        uint256 _rent
    ) public onlyTenant {
        require(_landlordAddress == landlord, "Incorrect landlord address");
        require(_deposit == deposit, "Incorrect deposit amount");
        require(_rentGuarantee == rentGuarantee, "Incorrect rent guarantee amount");
        require(_rent == rent, "Incorrect rent amount");

        uint256 deposits = deposit + rentGuarantee;
        // Get deposits from tenant
        tokenUsedForPayments.safeTransferFrom(tenant, address(this), deposits);

        // Deposit the deposits :)
        tokenUsedForPayments.approve(address(lendingService), deposits);
        lendingService.deposit(deposits);

        // Transfer first month rent
        tokenUsedForPayments.safeTransferFrom(tenant, landlord, rent);

        nextRentDueTimestamp = block.timestamp + 4 weeks;

        emit TenantEnteredAgreement(deposit, rentGuarantee, rent);
    }

    function payRent() public onlyTenant {
        require(tokenUsedForPayments.allowance(tenant, address(this)) >= rent, "Not enough allowance");

        tokenUsedForPayments.safeTransferFrom(tenant, landlord, rent);

        nextRentDueTimestamp += 4 weeks;

        emit RentPaid(tenant, rent, block.timestamp);
    }

    function withdrawUnpaidRent() public onlyLandlord {
        require(block.timestamp > nextRentDueTimestamp, "There are no unpaid rent");

        nextRentDueTimestamp += 4 weeks;

        rentGuarantee -= rent;

        lendingService.withdraw(rent);
        tokenUsedForPayments.safeTransfer(landlord, rent);
    }

    function endRental(uint256 _amountOfDepositBack) public onlyLandlord {
        require(_amountOfDepositBack <= deposit, "Invalid deposit amount");

        // Get the amount of capital in the lending service
        uint256 depositedOnLendingService = lendingService.depositedBalance();

        uint256 beforeWithdrawBalance = tokenUsedForPayments.balanceOf(address(this));
        lendingService.withdrawCapitalAndInterests();
        uint256 afterWithdrawBalance = tokenUsedForPayments.balanceOf(address(this));

        uint256 interestEarned = (afterWithdrawBalance - depositedOnLendingService) - beforeWithdrawBalance;

        // Compute and transfer funds to tenant
        uint256 fundsToReturnToTenant = _amountOfDepositBack + rentGuarantee + interestEarned;
        tokenUsedForPayments.safeTransfer(tenant, fundsToReturnToTenant);

        uint256 landlordWithdraw = deposit - _amountOfDepositBack;
        // The landlord is keeping some of the deposit
        if (landlordWithdraw > 0) {
            tokenUsedForPayments.safeTransfer(landlord, landlordWithdraw);
        }

        deposit = 0;
        rentGuarantee = 0;
        emit EndRental(fundsToReturnToTenant, landlordWithdraw);
    }
}