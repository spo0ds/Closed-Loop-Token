module closed_loop_token::simple_token {
    use std::option;
        use sui::vec_map;
        use sui::transfer;
        use sui::coin::{Self, TreasuryCap};
        use sui::tx_context::{sender, TxContext};
        use sui::token::{Self, TokenPolicy, TokenPolicyCap};
        use closed_loop_token::limiter_rule::{Self as limiter, Limiter};

        struct SIMPLE_TOKEN has drop {}

        fun init(otw: SIMPLE_TOKEN, ctx: &mut TxContext) {
            let treasury_cap = create_currency(otw, ctx);
            let (policy, cap) = token::new_policy(&treasury_cap, ctx);

            set_rules(&mut policy, &cap, ctx);

            transfer::public_transfer(treasury_cap, sender(ctx));
            transfer::public_transfer(cap, sender(ctx));
            token::share_policy(policy);
        }

        fun create_currency<T: drop>(
            otw: T,
            ctx: &mut TxContext
        ): TreasuryCap<T> {
            let (treasury_cap, metadata) = coin::create_currency(
                otw, 6,
                b"SMPL",
                b"Simple Token",
                b"Token that showcases Limit Transfer",
                option::none(),
                ctx
            );

            transfer::public_freeze_object(metadata);
            treasury_cap
        }

        public fun set_rules<T>(
            policy: &mut TokenPolicy<T>,
            cap: &TokenPolicyCap<T>,
            ctx: &mut TxContext
        ) {
            token::add_rule_for_action<T, Limiter>(policy, cap, token::transfer_action(), ctx);

            let config = {
                let config = vec_map::empty();
                vec_map::insert(&mut config, token::transfer_action(), 10_000000);
                config
            };
            limiter::set_config(policy, cap, config, ctx);
        }
}
