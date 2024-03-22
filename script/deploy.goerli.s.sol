// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiftBox.sol";
import "../src/GiftedConfig.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/FakeUSDC.sol";
import "../src/GiftedNFTFactory.sol";
import "../src/mocks/MockBrightMoments.sol";
import "../src/mocks/MockERC1155.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "../src/GiftedAccount.sol";
import "../src/Vault.sol";
import "../src/GasSponsorBook.sol";
import "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/utils/Strings.sol";

contract DeployGoerli is Script {
    using Strings for address;

    // GiftedNFTFactory internal factory = GiftedNFTFactory(0x98e805D932B73b12fE34e7757177Bfa12A28C829);

    // ERC6551Registry internal registry = ERC6551Registry(0x0d874789d82679ebD1750044Dca89b83C0f74297);
    // MockBrightMoments internal artworkNFT = MockBrightMoments(address(0x0b008F0e02C6117060bAbE7057A0552019092B4a));
    // MockERC1155 internal erc1155 = MockERC1155(address(0x507313775Be4eb79b557487e3A55d7f4F3460971));

    // GiftBox internal giftBox = GiftBox(0xBdaE17B46C87b8a86D6971FC10240f9d9d93a24B);
    // GiftBoxAccountHelper internal accountHelper = GiftBoxAccountHelper(0xe83d9e9B2fdf799b31A31523c0C3Dd6d59657a6c);
    // GiftedAccountGuardian internal guardian = GiftedAccountGuardian(0x11B9F271b05D0F41807EA803E2f9E2FDF67FA198);
    // GiftedAccount internal giftedAccount = GiftedAccount(payable(0x2B8b11D7599D436ef749B55EC76C6dd7DFF71fa2)); // GiftAccountProxy
    // GiftedAccount internal giftedAccountImpl; // mostly not used
    // GiftedConfig internal config = GiftedConfig(0x12799199D8Cc24Ea22bdbcAD86CA1e3555a60343);

    function run() external {
        // deploy_0();

        // deploy_artwork();
        // deploy_helper();
        // setAddressToFactory();
        // updateContractURI();

        // mint_erc1155();
        // mint_erc721();
        addAddressToSponsor();
    }

    function addAddressToSponsor() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GasSponsorBook sponsorBook = GasSponsorBook(address(0xB39cBe1ff098A947C932EBace18d42e77Fa0ac97));
        sponsorBook.grantRole(keccak256("CONSUMER_ROLE"), address(0x08E3dBFCF164Df355E36B65B4e71D9E66483e083));

        vm.stopBroadcast();
    }

    function deploy_artwork() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // erc721
        MockBrightMoments artworkNFT = new MockBrightMoments();
        artworkNFT.setBaseURI("https://staging.gifted.art/api/nfts/");

        // erc1155
        MockERC1155 erc1155 = new MockERC1155();
        erc1155.setURI("https://staging.gifted.art/api/nfts/");

        GiftedNFTFactory factory = new GiftedNFTFactory();

        address[2] memory fixedSizeArray = [address(artworkNFT), address(erc1155)];

        address[] memory dynamicArray = new address[](2);

        for (uint256 i = 0; i < 2; i++) {
            dynamicArray[i] = fixedSizeArray[i];
        }

        factory.monitorNFTCollections(dynamicArray);

        vm.stopBroadcast();
    }

    function deploy_helper() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ERC6551Registry registry = ERC6551Registry(0xE5f66DE16cE5a1bBCE31574029dF7cF2a987221A);
        GiftBox giftBox = GiftBox(0x1C5c6e32CBc5F608045a1781D6E9329E1B009257);
        GiftedAccountGuardian guardian = GiftedAccountGuardian(0x2a2F221020D19C9c21D0E8F75058da796664F68E);
        GiftedAccount giftedAccount = GiftedAccount(payable(0x5401d50209D48e070220d234132A35Ce3F625afC)); // GiftAccountProxy
        GiftedConfig config = GiftedConfig(0xB0CddfF980D3589E22D4714e24dB40C8ee693a38);

        GiftedAccount accountV2 = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(accountV2));
        GiftBoxAccountHelper helper = new GiftBoxAccountHelper(
            GiftedAccount(giftedAccount), GiftBox(giftBox), ERC6551Registry(registry), guardian
        );
        giftBox.grantRole(giftBox.MINTER_ROLE(), address(helper));

        config.setAddressConfig("GiftedAccount", address(accountV2));
        config.setAddressConfig("GiftBoxAccountHelper", address(helper));

        vm.stopBroadcast();
    }

    function mint_erc1155() internal {
        // uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey);

        // MockERC1155 erc1155 = MockERC1155(address(x61ebbc22d4e34f4f4f26f67114a5836854996c9b));

        // uint256 start = erc1155.totalSupply();
        // uint256 amount = 100;
        // // chuan
        // // erc1155.mint(address(0x70Dc10D2d99f5dea651DABFc7f6FB5db0E8ffa7b), start++, amount, "");
        // // erc1155.mint(address(0x4F88F1014Dd6Ca0507780380111c098BeE6b87e6), start++, amount, "");

        // // // Andrew Jiang
        // // erc1155.mint(address(0x787b382f86511b5e5eAd4b230FB4599b794B93aA), start++, amount, "");

        // // // keyp
        // erc1155.mint(address(0xC31f6b8133d618aD2ff1AC5fAA3Fc4B20557B901), start++, amount, "");

        // // // zitao
        // // erc1155.mint(address(0x82930FE86547DD38Eaa79e207d7530aEC939F5C2), start++, amount, "");

        // // // hua
        // // erc1155.mint(address(0xAA3f5Db8d4681B6cf0e960921E9ED77a2311Edd2), start++, amount, "");

        // // // js
        // // erc1155.mint(address(0x8c4Eb6988A199DAbcae0Ce31052b3f3aC591787e), start++, amount, "");
        // // erc1155.mint(address(0xBcf939a985850fA072FE349A8A07A6862126A4De), start++, amount, "");

        // // // bing
        // // erc1155.mint(address(0x66E675533020c3CDeE2F33E372320B7e2692211e), start++, amount, "");
        // vm.stopBroadcast();
    }

    function setAddressToFactory() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // GiftedNFTFactory factory = new GiftedNFTFactory();
        GiftedNFTFactory factory = GiftedNFTFactory(0x3CcD452829E389811C04AE3efE637532A309c7c8);

        address[2] memory fixedSizeArray =
            [address(0x01342877506d721765E918dc25DfC7201AF02001), address(0xFD52a038021976e84564C78EB5d2b0B8a4509333)];

        address[] memory dynamicArray = new address[](2);

        for (uint256 i = 0; i < 2; i++) {
            dynamicArray[i] = fixedSizeArray[i];
        }

        factory.monitorNFTCollections(dynamicArray);
        // factory.unmonitorNFTCollections(dynamicArray);

        vm.stopBroadcast();
    }

    function updateContractURI() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        GiftBox giftBox = GiftBox(0xBdaE17B46C87b8a86D6971FC10240f9d9d93a24B);
        giftBox.setContractURI("https://arweave.net/yuvqjHa8r1sMbYM9T4QMlHfhVnJQN-kNDCY5m4DgKmM");
        vm.stopBroadcast();
    }

    function mint_erc721() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // sepolia
        MockBrightMoments artworkNFT = MockBrightMoments(address(0x43AFC3E4c2E3bE6dbDB3Fc367026417c55120B4d));

        // chuan
        // artworkNFT.safeMint(address(0x70Dc10D2d99f5dea651DABFc7f6FB5db0E8ffa7b), "");
        // artworkNFT.safeMint(address(0x4F88F1014Dd6Ca0507780380111c098BeE6b87e6), "");

        // Andrew Jiang
        // artworkNFT.safeMint(address(0x787b382f86511b5e5eAd4b230FB4599b794B93aA), "");

        // keyp
        // artworkNFT.safeMint(address(0xC31f6b8133d618aD2ff1AC5fAA3Fc4B20557B901), "");

        // zitao
        // artworkNFT.safeMint(address(0x82930FE86547DD38Eaa79e207d7530aEC939F5C2), "");

        // hua
        // artworkNFT.safeMint(address(0xAA3f5Db8d4681B6cf0e960921E9ED77a2311Edd2), "");

        // js
        // artworkNFT.safeMint(address(0x8c4Eb6988A199DAbcae0Ce31052b3f3aC591787e), "");
        // artworkNFT.safeMint(address(0xBcf939a985850fA072FE349A8A07A6862126A4De), "");

        // bing
        // artworkNFT.safeMint(address(0x66E675533020c3CDeE2F33E372320B7e2692211e), "");

        for (uint256 i = 0; i < 5; i++) {
            artworkNFT.safeMint(address(0xC31f6b8133d618aD2ff1AC5fAA3Fc4B20557B901), "");
        }

        vm.stopBroadcast();
    }

    function deploy_0() internal {
        // Retrieve the deployer's private key from environment variables and start broadcasting transactions
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the GiftedAccountGuardian, GiftedAccount implementation, and proxy, then initialize them
        GiftedAccountGuardian guardian = new GiftedAccountGuardian();
        GiftedAccount implementation = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(implementation));
        GiftedAccountProxy proxy = new GiftedAccountProxy(address(guardian));
        GiftedAccount giftedAccount = GiftedAccount(payable(address(proxy)));
        giftedAccount.initialize(address(guardian));
        implementation.initialize(address(guardian));

        // Deploy the GiftBox contract and set its base URI
        GiftBox giftBox = new GiftBox();
        giftBox.setBaseURI("https://token-staging.gifted.art/");
        giftBox.setContractURI("https://arweave.net/yuvqjHa8r1sMbYM9T4QMlHfhVnJQN-kNDCY5m4DgKmM");

        // Deploy the ERC6551Registry contract and the GiftBoxAccountHelper contract
        ERC6551Registry registry = new ERC6551Registry();
        GiftBoxAccountHelper helper = new GiftBoxAccountHelper(
            GiftedAccount(implementation), GiftBox(giftBox), ERC6551Registry(registry), guardian
        );

        // Grant the MINTER_ROLE to the helper contract on the GiftBox contract
        giftBox.grantRole(giftBox.MINTER_ROLE(), address(helper));

        // Deploy the GiftedConfig contract
        GiftedConfig config = new GiftedConfig();

        // Deploy the Vault contract and initialize it with the deployer's address
        Vault vault = new Vault();
        vault.initialize(vm.addr(deployerPrivateKey));

        // Deploy the GasSponsorBook contract and grant it the CONTRACT_ROLE on the Vault contract
        GasSponsorBook sponsorBook = new GasSponsorBook();
        vault.grantRole(vault.CONTRACT_ROLE(), address(sponsorBook));

        // Set the Vault for the GasSponsorBook and link the helper to the sponsor book
        sponsorBook.setVault(vault);
        helper.setGasSponsorBook(sponsorBook);

        // Grant the SPONSOR_ROLE to the helper contract on the GasSponsorBook contract
        sponsorBook.grantRole(sponsorBook.SPONSOR_ROLE(), address(helper));

        // Prepare the keys and values for setting address configurations in the GiftedConfig contract
        string[] memory keys = new string[](8);
        keys[0] = "GiftBox";
        keys[1] = "GiftBoxAccountHelper";
        keys[2] = "GiftedAccountGuardian";
        keys[3] = "GiftedAccount";
        keys[4] = "ERC6551Registry";
        keys[5] = "GiftedAccountProxy";
        keys[6] = "Vault";
        keys[7] = "GasSponsorBook";

        address[] memory values = new address[](8);
        values[0] = address(giftBox);
        values[1] = address(helper);
        values[2] = address(guardian);
        values[3] = address(implementation);
        values[4] = address(registry);
        values[5] = address(proxy);
        values[6] = address(vault);
        values[7] = address(sponsorBook);

        // Set the address configurations in the GiftedConfig contract
        config.setAddressConfigs(keys, values);

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
