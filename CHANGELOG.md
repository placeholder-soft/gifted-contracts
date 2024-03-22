# ChangeLog
## 2023-09-09
- rename `GiftToken` to `GiftBox`
- rename `GiftTokenAccountHelper` to `GiftBoxAccountHelper`
- rename `SendNFTAccount` to `GiftedAccount`
- rename `GiftNFTFactory` to `GiftedNFTFactory`
- rename `SendNFTConfig` to `GiftedConfig`
- add `GiftedAccountGuardian` for admin control and upgradeability.
- add `GiftedAccountProxy` for upgradeability.
- add hardhat to for better IDE support.
- update `GiftedConfig` to return address type instead of string. string type is still supported for none-address types. future updates will not add address value into string type.
- add `callPermit`