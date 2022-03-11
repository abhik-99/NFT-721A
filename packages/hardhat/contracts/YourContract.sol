// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";


contract YourContract is ERC721A, Pausable, AccessControl, ReentrancyGuard {
	using SafeCast for uint;
	using Strings for uint256;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
	bytes32 public constant IS_WHITELISTED = keccak256("IS_WHITELISTED");
	bytes32 public constant IS_WHITELISTED_OG = keccak256("IS_WHITELISTED_OG");

	uint256 private constant START_TOKEN_ID = 1000;

	uint256 public maxSupply;
	uint256 public maxPurchase;
	uint256 public maxPurchaseOG;
	uint256 public preSalePrice;
	uint256 public publicPurchase;
	uint256 public publicSalePrice;
	uint256 public maxAirDropSupply;
	uint256 public currentAirDropSupply;

	bool public preSaleActive = false;
	bool public publicSaleActive = false;


	bool public revealed = false;

	string public NETWORK_PROVENANCE = "";

	string public notRevealedUri;
	string private _baseURIextended;

	mapping(address => uint8) whitelistedAddrCounts;
	mapping(address => uint8) whitelistedOgAddrCounts;


  constructor(
		string memory name,
		string memory symbol,
		uint256 _maxSupply,
		uint256 _maxPurchase,
		uint256 _maxPurchaseOG,
		uint256 _preSalePrice,
		uint256 _publicPurchase,
		uint256 _publicSalePrice,
		uint256 _maxAirDropSupply)
		ERC721A(name, symbol) ReentrancyGuard()
		{

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_grantRole(IS_WHITELISTED, msg.sender);
		_grantRole(IS_WHITELISTED_OG, msg.sender);

		maxSupply = _maxSupply;
		preSalePrice = _preSalePrice;
		publicSalePrice = _publicSalePrice;
		publicPurchase = _publicPurchase;
		maxPurchase = _maxPurchase;
		maxPurchaseOG = _maxPurchaseOG;
		maxAirDropSupply = _maxAirDropSupply;
	}

	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}


	function togglePreSale() external onlyRole(DEFAULT_ADMIN_ROLE) {
			preSaleActive = !preSaleActive;
	}

	function togglePublicSale() external onlyRole(DEFAULT_ADMIN_ROLE)  {
		publicSaleActive = !publicSaleActive;
	}


	function setPreSalePrice(uint256 _preSalePrice) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
		preSalePrice = _preSalePrice;
	}
	function setPublicSalePrice(uint256 _publicSalePrice) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
		publicSalePrice = _publicSalePrice;
	}



	function preSaleMint(uint256 _quantity)external payable nonReentrant whenNotPaused {
		require(preSaleActive, "NFT:Pre-sale is not active");
		require(hasRole(IS_WHITELISTED, msg.sender), "NFT:Sender is not whitelisted");
		mint(_quantity);
	}

	function publicSaleMint(uint256 _quantity)external payable nonReentrant{
		require(publicSaleActive, "NFT:Public-sale is not active");
		mint(_quantity);
	}

	function _startTokenId() internal view virtual override returns (uint256) {
		return START_TOKEN_ID;
	}

  function mint(uint256 _quantity) internal whenNotPaused {
		require(totalSupply() + _quantity <= maxSupply, "NFT: minting would exceed total supply");
    _safeMint(msg.sender, _quantity);

		if(publicSaleActive){
			require(balanceOf(msg.sender) + _quantity <= publicPurchase, "NFT-Public: You can't mint any more tokens");
		}
		else{
			if(hasRole(IS_WHITELISTED, msg.sender)){
				require( whitelistedAddrCounts[msg.sender] + _quantity <= maxPurchase, "NFT: You can't mint any more tokens");
				whitelistedAddrCounts[msg.sender] += _quantity.toUint8();
			}
			else if(hasRole(IS_WHITELISTED_OG, msg.sender)) {
				require(whitelistedOgAddrCounts[msg.sender] + _quantity <= maxPurchaseOG, "NFT-OG: You can't mint any more tokens");
				whitelistedOgAddrCounts[msg.sender] += _quantity.toUint8();
			}
		}

		if(preSaleActive){
			require(preSalePrice * _quantity <= msg.value, "NFT: Ether value sent for presale mint is not correct");
		}
		else{
			require(publicSalePrice * _quantity <= msg.value, "NFT: Ether value sent for public mint is not correct");
		}

		uint mintIndex = totalSupply();

		for (uint256 ind = 1; ind <= _quantity; ind++) {
				mintIndex += ind;
		}
		_safeMint(msg.sender, _quantity);
  }
	function _baseURI() internal view virtual override returns (string memory) {
			return _baseURIextended;
	}

	function setBaseURI(string calldata baseURI_) external onlyRole(DEFAULT_ADMIN_ROLE) {
			_baseURIextended = baseURI_;
	}

	function addWhiteListedAddresses(address[] memory _address) external onlyRole(WHITELISTER_ROLE) {
		for (uint256 i = 0; i < _address.length; i++) {
			require(!hasRole(IS_WHITELISTED, _address[i]), "NFT: address is already white listed");
			grantRole(IS_WHITELISTED, _address[i]);
		}
	}

	function addWhiteListedAddressesOG(address[] memory _address) external onlyRole(WHITELISTER_ROLE) {
		for (uint256 i = 0; i < _address.length; i++) {
			require(!hasRole(IS_WHITELISTED_OG, _address[i]), "NFT: address is already OG listed");
			grantRole(IS_WHITELISTED, _address[i]);
			grantRole(IS_WHITELISTED_OG, _address[i]);
		}
	}

	function airDrop(address[] memory _address) external onlyRole(DEFAULT_ADMIN_ROLE) {
		uint256 mintIndex = totalSupply();
		require(currentAirDropSupply + _address.length <= maxAirDropSupply, "NFT: Maximum Air Drop Limit Reached");
		require(mintIndex + _address.length <= maxSupply, "NFT: minting would exceed total supply");
		for(uint256 i = 0; i < _address.length; i++){
				mintIndex += i;
				_safeMint(_address[i],1);
		}
		currentAirDropSupply += _address.length;
	}

	function reveal() external onlyRole(DEFAULT_ADMIN_ROLE) {
		revealed = true;
	}

	function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
			uint balance = address(this).balance;
			payable(msg.sender).transfer(balance);
	}
	/*
	* Set provenance once it's calculated
	*/
	function setProvenanceHash(string memory provenanceHash) external onlyRole(DEFAULT_ADMIN_ROLE) {
			NETWORK_PROVENANCE = provenanceHash;
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		override(ERC721A, AccessControl)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	function tokenURI(uint256 tokenId)
		public
		view
		virtual
		override
		returns (string memory)
	{
			require(
					_exists(tokenId),
					"ERC721Metadata: URI query for nonexistent token"
			);
			if (revealed == false) {
					return notRevealedUri;
			}
			tokenId+=1;
			string memory currentBaseURI = _baseURI();
			return
					bytes(currentBaseURI).length > 0
							? string(
									abi.encodePacked(
											currentBaseURI,
											tokenId.toString(),
											".jpeg"
									)
							)
							: "";
    }

    function setNotRevealedURI(string memory _notRevealedURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
			notRevealedUri = _notRevealedURI;
    }
}