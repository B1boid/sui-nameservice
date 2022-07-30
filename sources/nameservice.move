module nameservice::suiname_nft {

    use sui::utf8;
    use sui::url::{Self, Url};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use std::vector;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, Info, ID};
    use sui::balance::{Self, Balance};

    const ENameIncorrect: u64 = 0;
    const ENameTaken: u64 = 1;
    const EOwnerIncorrect: u64 = 2;
    const EAmountIncorrect: u64 = 3;

    struct AdminCap has key { info: Info }

    struct Names has key {
        info: Info,
        names: vector<utf8::String>,
        ids: vector<ID>,
        balance: Balance<SUI>
    }

    struct SuiNameNFT has key, store {
        info: Info,
        name: utf8::String,
        url: Url,
        is_active: bool
    }

    struct NFTMinted has copy, drop {
        object_id: ID,
        creator: address,
        name: utf8::String,
    }

    public fun get_names(names: &Names): vector<utf8::String> {
        names.names
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
        return true
    }

    public fun is_name_available(names: &Names, name: &utf8::String): bool {
        !vector::contains(&get_names(names), name)
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            info: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(Names {
            info: object::new(ctx),
            names: vector::empty(),
            ids: vector::empty(),
            balance: balance::zero()
        });
    }

    public entry fun transfer(suiname_nft: SuiNameNFT, recipient: address) {
        transfer::transfer(suiname_nft, recipient);
    }

    public entry fun mint(
        names: &mut Names,
        name: vector<u8>,
        url: vector<u8>,
        paid: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(is_name_correct(&name), ENameIncorrect);

        let strName = utf8::string_unsafe(name);
        assert!(is_name_available(names, &strName), ENameTaken);

        let price = get_price(&name);
        assert!(price <= coin::value(paid), EAmountIncorrect);
        let coin_balance = coin::balance_mut(paid);
        balance::join(&mut names.balance, balance::split(coin_balance, price));

        let sender = tx_context::sender(ctx);
        let nft = SuiNameNFT {
            info: object::new(ctx),
            name: strName,
            url: url::new_unsafe_from_bytes(url),
            is_active: false
        };

        event::emit(NFTMinted {
            object_id: *object::info_id(&nft.info),
            creator: sender,
            name: nft.name,
        });

        vector::push_back(&mut names.names, strName);
        vector::push_back(&mut names.ids, *object::info_id(&nft.info));

        transfer::transfer(nft, sender);
    }

    public entry fun change_name_status(suiname_nft: &mut SuiNameNFT, status: bool) {
        suiname_nft.is_active = status
    }

    public entry fun collect_payments(_: &AdminCap, names: &mut Names, ctx: &mut TxContext) {
        let amount = balance::value(&names.balance);
        let payments = coin::take(&mut names.balance, amount, ctx);

        transfer::transfer(payments, tx_context::sender(ctx))
    }
}