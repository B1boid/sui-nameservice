module nameservice::suiname_nft {

    use sui::url::{Self, Url};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::utf8::{Self, String};
    use sui::vec_map::{Self, VecMap};

    const ENameIncorrect: u64 = 100;
    const ENameTaken: u64 = 101;
    const EOwnerIncorrect: u64 = 102;
    const EAmountIncorrect: u64 = 103;
    const EWrongType: u64 = 104;
    const EWrongInputGroup: u64 = 105;
    const EInvalidSender: u64 = 106;

    const STORAGE_GROUPS: u8 = 64;

    struct AdminCap has key { id: UID }

    struct GroupsInfo has key {
        id: UID,
        data: VecMap<u8, ID>,
    }

    struct NamesGroup has key {
        id: UID,
        type: u8,
        names: VecMap<String, ID>,
        balance: Balance<SUI>
    }

    struct SuiNameNFT has key, store {
        id: UID,
        name: String,
        url: Url,
        is_active: bool
    }

    struct NFTMinted has copy, drop {
        object_id: ID,
        creator: address,
        name: String,
    }


    public fun get_price(name: &vector<u8>): u64 {
        let price;
        let name_length = vector::length(name);
        if (name_length == 1) {
            price = 5000;
        } else if (name_length == 2) {
            price = 3000;
        } else if (name_length == 3) {
            price = 2000;
        } else {
            price = 1000;
        };
        price
    }

    public fun get_type(name: &vector<u8>): u8 {
        let hash_value: u8 = 0;
        let name_len = vector::length(name);
        let i = 0;
        while (i < name_len) {
            hash_value = (hash_value + *vector::borrow(name, i)) % STORAGE_GROUPS;
            i = i + 1;
        };
        return hash_value + 1
    }

    public fun is_name_correct(name: &vector<u8>): bool {
        let name_length = vector::length(name);
        if (name_length < 1 || name_length > 24) {
            return false
        };

        let i = 0;
        while (i < name_length) {
            let curChar = *vector::borrow(name, i);
            if (!((48 <= curChar && curChar <= 57) || // 0-9 chars [48, 57]
                  (97 <= curChar && curChar <= 122)) // a-z chars [97, 122]
            ) {
                return false
            };
            i = i + 1;
        };
        true
    }

    public fun is_name_available(names: &VecMap<String, ID>, name: &String): bool {
        !vec_map::contains(names, name)
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        let groups_data = vec_map::empty<u8, ID>();
        let group_type = 1;
        while (group_type <= STORAGE_GROUPS) {
            let obj_info = object::new(ctx);
            vec_map::insert(&mut groups_data, group_type, object::uid_to_inner(&obj_info));
            transfer::share_object(NamesGroup {
                id: obj_info,
                type: group_type,
                names: vec_map::empty(),
                balance: balance::zero()
            });
            group_type = group_type + 1;
        };

        transfer::share_object(GroupsInfo {
            id: object::new(ctx),
            data: groups_data,
        });
    }

    public entry fun transfer(suiname_nft: SuiNameNFT, recipient: address) {
        transfer::transfer(suiname_nft, recipient);
    }

    public entry fun mint(
        names: &mut NamesGroup,
        groups_info: &GroupsInfo,
        name: vector<u8>,
        url: vector<u8>,
        paid: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender != @0x0000000000000000000000000000000000000000, EInvalidSender);
        assert!(is_name_correct(&name), ENameIncorrect);

        let type = get_type(&name);
        assert!(type > 0, EWrongType);
        assert!(vec_map::get(&groups_info.data, &type) == object::uid_as_inner(&names.id), EWrongInputGroup);

        let strName = utf8::string_unsafe(name);
        assert!(is_name_available(&names.names, &strName), ENameTaken);

        let price = get_price(&name);
        assert!(price <= coin::value(paid), EAmountIncorrect);
        let coin_balance = coin::balance_mut(paid);
        balance::join(&mut names.balance, balance::split(coin_balance, price));


        let nft = SuiNameNFT {
            id: object::new(ctx),
            name: strName,
            url: url::new_unsafe_from_bytes(url),
            is_active: false
        };

        event::emit(NFTMinted {
            object_id: object::uid_to_inner(&nft.id),
            creator: sender,
            name: nft.name,
        });

        vec_map::insert(&mut names.names, strName, object::uid_to_inner(&nft.id));

        transfer::transfer(nft, sender);
    }

    public entry fun change_name_status(suiname_nft: &mut SuiNameNFT, status: bool) {
        suiname_nft.is_active = status
    }

    public entry fun collect_payments(_: &AdminCap, names: &mut NamesGroup, ctx: &mut TxContext) {
        let amount = balance::value(&names.balance);
        let payments = coin::take(&mut names.balance, amount, ctx);

        transfer::transfer(payments, tx_context::sender(ctx))
    }
}