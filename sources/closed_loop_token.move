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

#[test_only]
module closed_loop_token::simple_token_tests {
    use sui::tx_context::TxContext;
    use sui::token::{Self, TokenPolicy, TokenPolicyCap};
    use sui::token_test_utils::{Self as test, TEST};

    use closed_loop_token::simple_token::set_rules;
    use closed_loop_token::limiter_rule as limiter;

    const ALICE: address = @0x0;

    #[test]
    /// Transfer 1 Simple Token to self
    fun test_limiter_transfer_allowed_pass() {
        let ctx = &mut test::ctx(ALICE);
        let (policy, cap) = policy_with_allowlist(ctx);

        let token = test::mint(10_000000, ctx);
        let request = token::transfer(token, ALICE, ctx);

        limiter::verify(&policy, &mut request, ctx);
        token::confirm_request(&policy, request, ctx);
        test::return_policy(policy, cap);
    }

    #[test, expected_failure(abort_code = limiter::ELimitExceeded)]
    fun test_limiter_transfer_to_not_allowed_fail() {
        let ctx = &mut test::ctx(ALICE);
        let (policy, _cap) = policy_with_allowlist(ctx);

        let token = test::mint(11_000000, ctx);
        let request = token::transfer(token, ALICE, ctx);

        limiter::verify(&policy, &mut request, ctx);

        abort 1337
    }

    fun policy_with_allowlist(ctx: &mut TxContext): (TokenPolicy<TEST>, TokenPolicyCap<TEST>) {
        let (policy, cap) = test::get_policy(ctx);
        set_rules(&mut policy, &cap, ctx);
        (policy, cap)
    }
}
