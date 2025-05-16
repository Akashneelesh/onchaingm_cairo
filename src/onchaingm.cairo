use starknet::ContractAddress;
#[starknet::interface]
trait IOnchainGM<TContractState> {
    fn onChainGM(ref self: TContractState, value: u256);
    fn timeUntilNextGM(self: @TContractState, user: ContractAddress) -> u256;
    fn get_fee_recipient(self: @TContractState) -> ContractAddress;
    fn get_gm_fee(self: @TContractState) -> u256;
    fn get_last_GM_timestamp(self: @TContractState, address: ContractAddress) -> u256;
}

#[starknet::contract]
mod onchaingm {
    use starknet::event::EventEmitter;
    use starknet::{
        get_caller_address, contract_address_const, ContractAddress, get_block_timestamp
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin_token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    const TIME_LIMIT: u256 = 84600;

    #[storage]
    struct Storage {
        fee_recipient: ContractAddress,
        GM_FEE: u256,
        last_GM_timestamp: Map<ContractAddress, u256>,
        FEE_TOKEN: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OnChainGMEvent: OnChainGMEvent,
    }

    #[derive(Drop, starknet::Event)]
    struct OnChainGMEvent {
        sender: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self
            .FEE_TOKEN
            .write(
                contract_address_const::<
                    0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938
                >()
            );
        self.fee_recipient.write(contract_address_const::<'fee_recipeient'>());
        self.GM_FEE.write(1);
    }

    #[external(v0)]
    impl onchaingm of super::IOnchainGM<ContractState> {
        fn onChainGM(ref self: ContractState, value: u256) {
            let GM_FEE: u256 = self.GM_FEE.read();
            let caller: ContractAddress = get_caller_address();
            let fee_recipient: ContractAddress = self.fee_recipient.read();
            assert!(value == GM_FEE, "msg.value not equal to GM_FEE");
            assert!(
                get_block_timestamp().into() >= self.get_last_GM_timestamp(caller)
                    + TIME_LIMIT || self.get_last_GM_timestamp(caller) == 0,
                "wait 24 hours"
            );

            self.last_GM_timestamp.write(caller, get_block_timestamp().into());

            let success: bool = ERC20ABIDispatcher { contract_address: self.FEE_TOKEN.read() }
                .transfer_from(caller, fee_recipient, value);

            assert!(success == true, "Fee transfer failed");

            self.emit(OnChainGMEvent { sender: caller });
        }

        fn get_last_GM_timestamp(self: @ContractState, address: ContractAddress) -> u256 {
            self.last_GM_timestamp.read(address)
        }
        fn timeUntilNextGM(self: @ContractState, user: ContractAddress) -> u256 {
            let caller = get_caller_address();
            let last_gm_timestamp_value = self.get_last_GM_timestamp(caller);
            if (last_gm_timestamp_value == 0) {
                0;
            }

            let time_passed: u256 = get_block_timestamp().into() - last_gm_timestamp_value;

            if (time_passed >= TIME_LIMIT) {
                0;
            }

            return TIME_LIMIT - time_passed;
        }
        fn get_fee_recipient(self: @ContractState) -> ContractAddress {
            self.fee_recipient.read()
        }
        fn get_gm_fee(self: @ContractState) -> u256 {
            self.GM_FEE.read()
        }
    }
}
