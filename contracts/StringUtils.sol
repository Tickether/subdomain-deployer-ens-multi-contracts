//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

library StringUtils {
    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    function validateString(string memory label) internal pure returns (uint) {
        bytes memory inputBytes = bytes(label);

        // Check if the string is empty
        if (inputBytes.length == 0) {
            return 0;
        }

        // Check if the string contains only numbers
        bool containsOnlyNumbers = true;
        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];

            // Check for spaces within the input string
            if (char == 0x20) {
                return 0;  // Space character is not allowed
            }

            // Check if the character is not a number
            if (!(char >= 0x30 && char <= 0x39)) {
                containsOnlyNumbers = false;
                break;
            }
        }

        if (containsOnlyNumbers) {
            return 2;  // String contains only numbers
        }

        // Check the first character of the string
        if (!((inputBytes[0] >= 0x30 && inputBytes[0] <= 0x39) || (inputBytes[0] >= 0x61 && inputBytes[0] <= 0x7A))) {
            return 0;
        }

        // Check the remaining characters of the string
        for (uint256 i = 1; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];

            // Check for spaces within the input string
            if (char == 0x20) {
                return 0;  // Space character is not allowed
            }

            // Check if the character is a lowercase letter or a number
            if (!((char >= 0x30 && char <= 0x39) || (char >= 0x61 && char <= 0x7A))) {
                return 0;
            }
        }

        return 1;
    }

    function extractLabel(bytes memory encodedLabel) 
        internal 
        pure 
        returns (string memory) 
    {
        require(encodedLabel.length >= 1, "Invalid encoded label");

        uint8 labelLength = uint8(encodedLabel[0]);
        require(encodedLabel.length >= labelLength + 1, "Invalid encoded label");

        bytes memory labelBytes = new bytes(labelLength);
        for (uint8 i = 0; i < labelLength; i++) {
            labelBytes[i] = encodedLabel[i + 1];
        }

        return string(labelBytes);
    }
}
