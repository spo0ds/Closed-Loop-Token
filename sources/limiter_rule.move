module closed_loop_token::limiter_rule {
    use std::string::String;
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;
    use sui::token::{
        Self,
        TokenPolicy,
        TokenPolicyCap,
        ActionRequest
    };

    /// Trying to perform an action that exceeds the limit.
    const ELimitExceeded: u64 = 0;

    /// The Rule witness.
    struct Limiter has drop {}

    /// The Config object for the `lo
    struct Config has store, drop {
        /// Mapping of Action -> Limit
        limits: VecMap<String, u64>
    }

    /// Verifies that the request does not exceed the limit and adds an approval
    /// to the `ActionRequest`.
    public fun verify<T>(
        policy: &TokenPolicy<T>,
        request: &mut ActionRequest<T>,
        ctx: &mut TxContext
    ) {
        if (!token::has_rule_config<T, Limiter>(policy)) {
            return token::add_approval(Limiter {}, request, ctx)
        };

        let config: &Config = token::rule_config(Limiter {}, policy);
        if (!vec_map::contains(&config.limits, &token::action(request))) {
            return token::add_approval(Limiter {}, request, ctx)
        };

        let action_limit = *vec_map::get(&config.limits, &token::action(request));

        assert!(token::amount(request) <= action_limit, ELimitExceeded);
        token::add_approval(Limiter {}, request, ctx);
    }

    /// Updates the config for the `Limiter` rule. Uses the `VecMap` to store
    /// the limits for each action.
    public fun set_config<T>(
        policy: &mut TokenPolicy<T>,
        cap: &TokenPolicyCap<T>,
        limits: VecMap<String, u64>,
        ctx: &mut TxContext
    ) {
        // if there's no stored config for the rule, add a new one
        if (!token::has_rule_config<T, Limiter>(policy)) {
            let config = Config { limits };
            token::add_rule_config(Limiter {}, policy, cap, config, ctx);
        } else {
            let config: &mut Config = token::rule_config_mut(Limiter {}, policy, cap);
            config.limits = limits;
        }
    }

    /// Returns the config for the `Limiter` rule.
    public fun get_config<T>(policy: &TokenPolicy<T>): VecMap<String, u64> {
        token::rule_config<T, Limiter, Config>(Limiter {}, policy).limits
    }
}