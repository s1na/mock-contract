pragma solidity ^0.4.23;

/**
 * @dev Used for unit testing MockContract functionality.
 */
interface ComplexInterface {
	function methodA() external;
	function methodB() external;
    function acceptAdressUintReturnBool(address recipient, uint amount) external returns (bool);
    function acceptUintReturnString(uint) external returns (string memory);
    function acceptUintReturnBool(uint) external returns (bool);
    function acceptUintReturnUint(uint) external returns (uint);
    function acceptUintReturnAddress(uint) external returns (address);
}