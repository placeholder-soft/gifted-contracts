// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GiftBox.sol";
import "../src/GiftedConfig.sol";
import "../src/GiftBoxAccountHelper.sol";
import "../src/FakeUSDC.sol";
import "../src/GiftedNFTFactory.sol";
import "../src/mocks/MockBrightMoments.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "../src/GiftedAccount.sol";
import "../src/Vault.sol";
import "../src/GasSponsorBook.sol";
import "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/utils/Strings.sol";

contract DeployMainnet is Script {
    using Strings for address;

    GiftedAccountGuardian guardian = GiftedAccountGuardian(0x1fee122930BB09D400FeF0f0Fb9d1BDBbce14268);
    GiftBox giftBox = GiftBox(0xd6508dAa57Fb8257AE35eeb3D0F49b9b2356F5b1);
    ERC6551Registry registry = ERC6551Registry(0xbec73A3ed80216efbc5203DC014F183F582E97c0);
    GiftedConfig config = GiftedConfig(0x81382f69965d92B9dAD86c0c87Af383BEff24041);
    GiftedAccountProxy giftedProxy = GiftedAccountProxy(payable(0xA473098eD8d7f94A18E0B7A0d0C15b6750b4dbDe));

    function run() external {
        // deploy_0();
        // setNFTMonitoring();
        deploy_erc1155();
    }

    function deploy_erc1155() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GiftedAccount accountV2 = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(accountV2));
        GiftBoxAccountHelper helper = new GiftBoxAccountHelper(
            GiftedAccount(payable(address(giftedProxy))), GiftBox(giftBox), ERC6551Registry(registry), guardian
        );
        giftBox.grantRole(giftBox.MINTER_ROLE(), address(helper));

        config.setAddressConfig("GiftedAccount", address(accountV2));
        config.setAddressConfig("GiftBoxAccountHelper", address(helper));

        vm.stopBroadcast();
    }

    function setNFTMonitoring() internal {
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GiftedNFTFactory factory = new GiftedNFTFactory();
        address[] memory nfts = new address[](1);
        nfts[0] = 0xeB8f1fFf0eab593010675EE9E2fC5772F36cccC7;
        factory.monitorNFTCollections(nfts);

        vm.stopBroadcast();
    }

    function deploy_0() internal {
        // Retrieve the deployer's private key from environment variables and start broadcasting transactions
        uint256 deployerPrivateKey = vm.envUint("ETH_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the GiftedAccountGuardian, GiftedAccount implementation, and proxy, then initialize them
        GiftedAccountGuardian guardian = GiftedAccountGuardian(0x1fee122930BB09D400FeF0f0Fb9d1BDBbce14268);
        // Deploy the GiftedConfig contract
        GiftedConfig config = GiftedConfig(0x81382f69965d92B9dAD86c0c87Af383BEff24041);
        // GiftedAccount implementation = GiftedAccount(payable(0xebc4d12a48f6299a1026bcF498b9CB1Ff65B863D));
        // guardian.setGiftedAccountImplementation(address(implementation));

        GiftedAccountProxy proxy = GiftedAccountProxy(payable(0xA473098eD8d7f94A18E0B7A0d0C15b6750b4dbDe));
        GiftedAccount giftedAccount = GiftedAccount(payable(address(proxy)));
        // giftedAccount.initialize(address(guardian));
        // implementation.initialize(address(guardian));

        // Deploy the GiftBox contract and set its base URI
        GiftBox giftBox = GiftBox(0xd6508dAa57Fb8257AE35eeb3D0F49b9b2356F5b1);
        // giftBox.setBaseURI("https://token.gifted.art/");
        // giftBox.setContractURI("https://arweave.net/yuvqjHa8r1sMbYM9T4QMlHfhVnJQN-kNDCY5m4DgKmM");

        // Deploy the ERC6551Registry contract and the GiftBoxAccountHelper contract
        ERC6551Registry registry = ERC6551Registry(0xbec73A3ed80216efbc5203DC014F183F582E97c0);
        GiftBoxAccountHelper helper = GiftBoxAccountHelper(0x7B5E1208CC561E5caD29D1264c53c919e0858D1B);

        // Grant the MINTER_ROLE to the helper contract on the GiftBox contract
        // giftBox.grantRole(giftBox.MINTER_ROLE(), address(helper));

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
        values[3] = address(giftedAccount);
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
