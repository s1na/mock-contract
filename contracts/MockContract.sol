pragma solidity ^0.4.23;

interface MockInterface {
	/**
	 * @dev After calling this method, the mock will return `response` when it is called
	 * with any calldata that is not mocked more specifically below
	 * (e.g. using givenMethodReturn).
	 * @param response ABI encoded response that will be returned if method is invoked
	 */
	function givenAnyReturn(bytes response) external;
	function givenAnyReturnBool(bool response) external;
	function givenAnyReturnUint(uint response) external;
	function givenAnyReturnAddress(address response) external;

	function givenAnyRevert() external;
	function givenAnyRevertWithMessage(string message) external;
	function givenAnyRunOutOfGas() external;

	/**
	 * @dev After calling this method, the mock will return `response` when the given
	 * methodId is called regardless of arguments. If the methodId and arguments
	 * are mocked more specifically (using `givenMethodAndArguments`) the latter
	 * will take precedence.
	 * @param method ABI encoded methodId. It is valid to pass full calldata (including arguments). The mock will extract the methodId from it
	 * @param response ABI encoded response that will be returned if method is invoked
	 */
	function givenMethodReturn(bytes method, bytes response) external;
	function givenMethodReturnBool(bytes method, bool response) external;
	function givenMethodReturnUint(bytes method, uint response) external;
	function givenMethodReturnAddress(bytes method, address response) external;

	function givenMethodRevert(bytes method) external;
	function givenMethodRevertWithMessage(bytes method, string message) external;
	function givenMethodRunOutOfGas(bytes method) external;

	/**
	 * @dev After calling this method, the mock will return `response` when the given
	 * methodId is called with matching arguments. These exact calldataMocks will take
	 * precedence over all other calldataMocks.
	 * @param calldata ABI encoded calldata (methodId and arguments)
	 * @param response ABI encoded response that will be returned if contract is invoked with calldata
	 */
	function givenCalldataReturn(bytes calldata, bytes response) external;
	function givenCalldataReturnBool(bytes calldata, bool response) external;
	function givenCalldataReturnUint(bytes calldata, uint response) external;
	function givenCalldataReturnAddress(bytes calldata, address response) external;

	function givenCalldataRevert(bytes calldata) external;
	function givenCalldataRevertWithMessage(bytes calldata, string message) external;
	function givenCalldataRunOutOfGas(bytes calldata) external;

	/**
	 * @dev Returns the number of times anything has been called on this mock since last reset
	 */
	function invocationCount() external returns (uint);

	/**
	 * @dev Returns the number of times the given method has been called on this mock since last reset
	 * @param method ABI encoded methodId. It is valid to pass full calldata (including arguments). The mock will extract the methodId from it
	 */
	function invocationCountForMethod(bytes method) external returns (uint);

	/**
	 * @dev Returns the number of times this mock has been called with the exact calldata since last reset.
	 * @param calldata ABI encoded calldata (methodId and arguments)
	 */
	function invocationCountForCalldata(bytes calldata) external returns (uint);

	/**
	 * @dev Resets all mocked methods and invocation counts.
	 */
	 function reset() external;
}

/**
 * Implementation of the MockInterface.
 */
contract MockContract is MockInterface {
	enum MockType { Return, Revert, OutOfGas }
	
	bytes32 public constant MOCKS_LIST_START = hex"01";
	bytes public constant MOCKS_LIST_END = "0xff";
	bytes32 public constant MOCKS_LIST_END_HASH = keccak256(MOCKS_LIST_END);
	bytes4 public constant SENTINEL_ANY_MOCKS = hex"01";

	// A linked list allows easy iteration and inclusion checks
	mapping(bytes32 => bytes) calldataMocks;
	mapping(bytes => MockType) calldataMockTypes;
	mapping(bytes => bytes) calldataExpectations;
	mapping(bytes => string) calldataRevertMessage;
	mapping(bytes32 => uint) calldataInvocations;

	mapping(bytes4 => bytes4) methodIdMocks;
	mapping(bytes4 => MockType) methodIdMockTypes;
	mapping(bytes4 => bytes) methodIdExpectations;
	mapping(bytes4 => string) methodIdRevertMessages;
	mapping(bytes32 => uint) methodIdInvocations;

	MockType fallbackMockType;
	bytes fallbackExpectation;
	string fallbackRevertMessage;
	uint invocations;
	uint resetCount;

	constructor() public {
		calldataMocks[MOCKS_LIST_START] = MOCKS_LIST_END;
		methodIdMocks[SENTINEL_ANY_MOCKS] = SENTINEL_ANY_MOCKS;
	}

	function trackCalldataMock(bytes memory call) private {
		bytes32 callHash = keccak256(call);
		if (calldataMocks[callHash].length == 0) {
			calldataMocks[callHash] = calldataMocks[MOCKS_LIST_START];
			calldataMocks[MOCKS_LIST_START] = call;
		}
	}

	function trackMethodIdMock(bytes4 methodId) private {
		if (methodIdMocks[methodId] == 0x0) {
			methodIdMocks[methodId] = methodIdMocks[SENTINEL_ANY_MOCKS];
			methodIdMocks[SENTINEL_ANY_MOCKS] = methodId;
		}
	}

	function _givenAnyReturn(bytes response) internal {
		fallbackMockType = MockType.Return;
		fallbackExpectation = response;
	}

	function givenAnyReturn(bytes response) external {
		_givenAnyReturn(response);
	}

	function givenAnyReturnBool(bool response) external {
		uint flag = response ? 1 : 0;
		_givenAnyReturn(uintToBytes(flag));
	}

	function givenAnyReturnUint(uint response) external {
		_givenAnyReturn(uintToBytes(response));	
	}

	function givenAnyReturnAddress(address response) external {
		_givenAnyReturn(addressToBytes(response));
	}

	function givenAnyRevert() external {
		fallbackMockType = MockType.Revert;
		fallbackRevertMessage = "";
	}

	function givenAnyRevertWithMessage(string message) external {
		fallbackMockType = MockType.Revert;
		fallbackRevertMessage = message;
	}

	function givenAnyRunOutOfGas() external {
		fallbackMockType = MockType.OutOfGas;
	}

	function _givenCalldataReturn(bytes call, bytes response) private  {
		calldataMockTypes[call] = MockType.Return;
		calldataExpectations[call] = response;
		trackCalldataMock(call);
	}

	function givenCalldataReturn(bytes call, bytes response) external  {
		_givenCalldataReturn(call, response);
	}

	function givenCalldataReturnBool(bytes call, bool response) external {
		uint flag = response ? 1 : 0;
		_givenCalldataReturn(call, uintToBytes(flag));
	}

	function givenCalldataReturnUint(bytes call, uint response) external {
		_givenCalldataReturn(call, uintToBytes(response));
	}

	function givenCalldataReturnAddress(bytes call, address response) external {
		_givenCalldataReturn(call, addressToBytes(response));
	}

	function _givenMethodReturn(bytes call, bytes response) private {
		bytes4 method = bytesToBytes4(call);
		methodIdMockTypes[method] = MockType.Return;
		methodIdExpectations[method] = response;
		trackMethodIdMock(method);		
	}

	function givenMethodReturn(bytes call, bytes response) external {
		_givenMethodReturn(call, response);
	}

	function givenMethodReturnBool(bytes call, bool response) external {
		uint flag = response ? 1 : 0;
		_givenMethodReturn(call, uintToBytes(flag));
	}

	function givenMethodReturnUint(bytes call, uint response) external {
		_givenMethodReturn(call, uintToBytes(response));
	}

	function givenMethodReturnAddress(bytes call, address response) external {
		_givenMethodReturn(call, addressToBytes(response));
	}

	function givenCalldataRevert(bytes call) external {
		calldataMockTypes[call] = MockType.Revert;
		calldataRevertMessage[call] = "";
		trackCalldataMock(call);
	}

	function givenMethodRevert(bytes call) external {
		bytes4 method = bytesToBytes4(call);
		methodIdMockTypes[method] = MockType.Revert;
		trackMethodIdMock(method);		
	}

	function givenCalldataRevertWithMessage(bytes call, string message) external {
		calldataMockTypes[call] = MockType.Revert;
		calldataRevertMessage[call] = message;
		trackCalldataMock(call);
	}

	function givenMethodRevertWithMessage(bytes call, string message) external {
		bytes4 method = bytesToBytes4(call);
		methodIdMockTypes[method] = MockType.Revert;
		methodIdRevertMessages[method] = message;
		trackMethodIdMock(method);		
	}

	function givenCalldataRunOutOfGas(bytes call) external {
		calldataMockTypes[call] = MockType.OutOfGas;
		trackCalldataMock(call);
	}

	function givenMethodRunOutOfGas(bytes call) external {
		bytes4 method = bytesToBytes4(call);
		methodIdMockTypes[method] = MockType.OutOfGas;
		trackMethodIdMock(method);	
	}

	function invocationCount() external returns (uint) {
		return invocations;
	}

	function invocationCountForMethod(bytes call) external returns (uint) {
		bytes4 method = bytesToBytes4(call);
		return methodIdInvocations[keccak256(abi.encodePacked(resetCount, method))];
	}

	function invocationCountForCalldata(bytes call) external returns (uint) {
		return calldataInvocations[keccak256(abi.encodePacked(resetCount, call))];
	}

	function reset() external {
		// Reset all exact calldataMocks
		bytes memory nextMock = calldataMocks[MOCKS_LIST_START];
		bytes32 mockHash = keccak256(nextMock);
		// We cannot compary bytes
		while(mockHash != MOCKS_LIST_END_HASH) {
			// Reset all mock maps
			calldataMockTypes[nextMock] = MockType.Return;
			calldataExpectations[nextMock] = hex"";
			calldataRevertMessage[nextMock] = "";
			// Set next mock to remove
			nextMock = calldataMocks[mockHash];
			// Remove from linked list
			calldataMocks[mockHash] = "";
			// Update mock hash
			mockHash = keccak256(nextMock);
		}
		// Clear list
		calldataMocks[MOCKS_LIST_START] = MOCKS_LIST_END;

		// Reset all any calldataMocks
		bytes4 nextAnyMock = methodIdMocks[SENTINEL_ANY_MOCKS];
		while(nextAnyMock != SENTINEL_ANY_MOCKS) {
			bytes4 currentAnyMock = nextAnyMock;
			methodIdMockTypes[currentAnyMock] = MockType.Return;
			methodIdExpectations[currentAnyMock] = hex"";
			methodIdRevertMessages[currentAnyMock] = "";
			nextAnyMock = methodIdMocks[currentAnyMock];
			// Remove from linked list
			methodIdMocks[currentAnyMock] = 0x0;
		}
		// Clear list
		methodIdMocks[SENTINEL_ANY_MOCKS] = SENTINEL_ANY_MOCKS;

		fallbackExpectation = "";
		fallbackMockType = MockType.Return;
		invocations = 0;
		resetCount += 1;
	}

	function useAllGas() private {
		while(true) {
			bool s;
			assembly {
				//expensive call to EC multiply contract
				s := call(sub(gas, 2000), 6, 0, 0x0, 0xc0, 0x0, 0x60)
			}
		}
	}

	function bytesToBytes4(bytes b) private pure returns (bytes4) {
  		bytes4 out;
  		for (uint i = 0; i < 4; i++) {
    		out |= bytes4(b[i] & 0xFF) >> (i * 8);
  		}
  		return out;
	}

	function addressToBytes(address a) private pure returns (bytes b){
   		assembly {
        	let m := mload(0x40)
        	mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
        	mstore(0x40, add(m, 52))
        	b := m
   		}
	}

	function uintToBytes(uint256 x) private pure returns (bytes b) {
    	b = new bytes(32);
    	assembly { mstore(add(b, 32), x) }
	}

	function() payable external {
		bytes4 methodId;
		assembly {
			methodId := calldataload(0)
		}

		// First, check exact matching overrides
		if (calldataMockTypes[msg.data] == MockType.Revert) {
			revert(calldataRevertMessage[msg.data]);
		}
		if (calldataMockTypes[msg.data] == MockType.OutOfGas) {
			useAllGas();
		}
		bytes memory result = calldataExpectations[msg.data];

		// Then check method Id overrides
		if (result.length == 0) {
			if (methodIdMockTypes[methodId] == MockType.Revert) {
				revert(methodIdRevertMessages[methodId]);
			}
			if (methodIdMockTypes[methodId] == MockType.OutOfGas) {
				useAllGas();
			}
			result = methodIdExpectations[methodId];
		}

		// Last, use the fallback override
		if (result.length == 0) {
			if (fallbackMockType == MockType.Revert) {
				revert(fallbackRevertMessage);
			}
			if (fallbackMockType == MockType.OutOfGas) {
				useAllGas();
			}
			result = fallbackExpectation;
		}

		// Record invocation
		invocations += 1;
		methodIdInvocations[keccak256(abi.encodePacked(resetCount, methodId))] += 1;
		calldataInvocations[keccak256(abi.encodePacked(resetCount, msg.data))] += 1;

		assembly {
			return(add(0x20, result), mload(result))
		}
	}
}
