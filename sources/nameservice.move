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

    const ENameTaken: u64 = 0;
    const EOwnerIncorrect: u64 = 1;
    const EAmountIncorrect: u64 = 2;
    const ContractOwner: address = @0x763fdfdd56e88ddad4347e7ece7e75c2f32ddca0;

    struct Names has key {
        info: Info,
        names: vector<utf8::String>,
        ids: vector<ID>
    }

    struct SuiNameNFT has key, store {
        info: Info,
        name: utf8::String,
        url: Url,
        is_active: bool,
    }

    struct MintNFTEvent has copy, drop {
        object_id: ID,
        creator: address,
        name: utf8::String,
    }

    public fun getNames(names: &Names): vector<utf8::String>{
        names.names
    }

    public fun getPrice(name: &vector<u8>): u64{
        let price;
        let name_size = vector::length(name);
        if (name_size == 1){
            price = 5000;
        } else if (name_size == 2){
            price = 3000;
        } else if (name_size == 3){
            price = 2000;
        } else {
            price = 1000;
        };
        price
    }

    public fun isNameAvailable(names: &Names, name: &utf8::String): bool{
        !vector::contains(&getNames(names), name)
    }

    fun init(ctx: &mut TxContext){
        transfer::share_object(Names{
            info: object::new(ctx),
            names: vector::empty(),
            ids: vector::empty()
        });
    }

    public entry fun transfer(suiname_nft: SuiNameNFT, recipient: address){
        transfer::transfer(suiname_nft, recipient);
    }

    public entry fun mint(
        names: &mut Names,
        name: vector<u8>,
        url: vector<u8>,
        paid: &mut Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert!(isNameAvailable(names, &utf8::string_unsafe(name)), ENameTaken);

        let price = getPrice(&name);
        assert!(price <= coin::value(paid), EAmountIncorrect);
        coin::split_and_transfer(paid, price, ContractOwner, ctx);

        let sender = tx_context::sender(ctx);
        let nft = SuiNameNFT {
            info: object::new(ctx),
            name: utf8::string_unsafe(name),
            url: url::new_unsafe_from_bytes(url),
            is_active: false,
        };

        event::emit(MintNFTEvent {
            object_id: *object::info_id(&nft.info),
            creator: sender,
            name: nft.name,
        });

        vector::push_back(&mut names.names, utf8::string_unsafe(name));
        vector::push_back(&mut names.ids, *object::info_id(&nft.info));

        transfer::transfer(nft, sender);

    }

    public entry fun change_name_status(suiname_nft: &mut SuiNameNFT, status:bool){
        suiname_nft.is_active = status
    }


}