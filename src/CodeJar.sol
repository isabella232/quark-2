// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract CodeJar {
  error CodeSaveFailed(bytes initCode);
  error CodeSaveMismatch(bytes initCode, bytes code, address expected, address created);
  error CodeTooLarge(uint256 sz);
  error CodeNotFound(address codeAddress);

  function saveCode(bytes memory code) external returns (address) {
        /**
         * 0000    63XXXXXXXX  PUSH4 XXXXXXXX // code size
         * 0005    80          DUP1
         * 0006    600e        PUSH1 0x0e // this size
         * 0008    6000        PUSH1 0x00
         * 000a    39          CODECOPY
         * 000b    6000        PUSH1 0x00
         * 000d    F3          *RETURN
         */
        uint32 initCodeBaseSz = uint32(0x0e); // 0x630000000080600e6000396000f3
        if (code.length > type(uint32).max) {
            revert CodeTooLarge(code.length);
        }
        uint32 codeSz = uint32(code.length);
        uint256 initCodeLen = initCodeBaseSz + codeSz;
        bytes memory initCode = new bytes(initCodeLen);

        assembly {
            function memcpy(dst, src, size) {
                for {} gt(size, 0) {}
                {
                    // Copy word
                    if gt(size, 31) { // ≥32
                        mstore(dst, mload(src))
                        dst := add(dst, 32)
                        src := add(src, 32)
                        size := sub(size, 32)
                        continue
                    }

                    // Copy byte
                    //
                    // Note: we can't use `mstore` here to store a full word since we could
                    // truncate past the end of the dst ptr.
                    mstore8(dst, and(mload(src), 0xff))
                    dst := add(dst, 1)
                    src := add(src, 1)
                    size := sub(size, 1)
                }
            }

            function copy4(dst, v) {
              if gt(v, 0xffffffff) {
                // operand too large
                revert(0, 0)
              }

              mstore8(add(dst, 0), byte(28, v))
              mstore8(add(dst, 1), byte(29, v))
              mstore8(add(dst, 2), byte(30, v))
              mstore8(add(dst, 3), byte(31, v))
            }

            let initCodeOffset := add(initCode, 0x20)
            mstore(initCodeOffset, 0x630000000080600e6000396000f3000000000000000000000000000000000000)
            memcpy(add(initCodeOffset, initCodeBaseSz), add(code, 0x20), codeSz)
            copy4(add(initCodeOffset, 1), codeSz)
        }

        address codeAddress = address(uint160(uint(
            keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    uint256(0),
                    keccak256(initCode)
                )
            )))
        );

        uint256 codeAddressLen;
        assembly {
            codeAddressLen := extcodesize(codeAddress)
        }

        if (codeAddressLen == 0) {
            address codeCreateAddress;
            assembly {
                codeCreateAddress := create2(0, add(initCode, 32), initCodeLen, 0)
            }
            // Ensure that the wallet was created.
            if (uint160(address(codeCreateAddress)) == 0) {
                revert CodeSaveFailed(initCode);
            }
            if (codeCreateAddress != codeAddress) {
                revert CodeSaveMismatch(initCode, code, codeAddress, codeCreateAddress);
            }
        }

        return codeAddress;
    }

    /**
     * @notice Returns the code associated with a running quark for `msg.sender`
     * @dev This is generally expected to be used only by the Quark wallet itself
     *      in the constructor phase to get its code.
     */
    function readCode(address codeAddress) external view returns (bytes memory) {
        uint256 codeLen;
        assembly {
            codeLen := extcodesize(codeAddress)
        }

        if (codeLen == 0) {
          revert CodeNotFound(codeAddress);
        }

        bytes memory code = new bytes(codeLen);
        assembly {
            extcodecopy(codeAddress, add(code, 0x20), 0, codeLen)
        }

        return code;
    }
}
