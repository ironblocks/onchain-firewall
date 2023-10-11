# Ironblocks: Uniswap V4 Firewall Hooks  

## Overview 
Ironblocks provides full on-chain firewall which can protect the dApps from malicious transactions in realtime.

Significant number of dApps has pool on Uniswap, and it's might be even part of their business logic in their smart contracts.
harming their pool means harming their protocol/users and vise versa.

This why we added the adapter from Uniswap hooks mechanism to the firewall we created.
This way the protection over the pool can be part of the protection layer of the dApp.

You can learn more on [Ironblocks website](https://ironblocks.com) or in the [Docs](https://ironblocks.readme.io/docs) 

## How it works
We created an adapter hook that can connect to the firewall's policies with these hooks:
- beforeModifyPosition/afterModifyPosition
- beforeSwap/afterSwap

The firewall's policies has preExecution & postExecution functions, the adapter will use these functions of the relevant policies.
The policies also has state that they save and the hook can use that too.

New Uniswap security hooks can be implemented by inherit the GeneralHook.sol.

existing policies that can be used by the hooks are:
- Calls sequences chaeck
- Circuit breaker
- Bypass mechanism

![diagram-firewall hook](https://github.com/ironblocks/onchain-firewall/contracts/uniswap-hooks/general_uniswap_hook.png<>)

## Use cases

### calls sequences check

- By analyzing the protocol with sophisticated tool we add the allow/block list of calls per transaction for the protocol to the relevant policy on the firewall
- If the end user commit the blocked sequence (for example - deposit + withdraw + swap of minted protocol's tokens) he will get to the swap hook
- The beforeSwap hook will check the relevant call sequence in the firewall (after the deposit & withdraw already saved in the firewall memory)
- The policy will block this sequence and the beforeSwap will stop this malicious swap

### circuit breaker

- Let's say that part of the risk modeling of the dApp is that the liquidity removal of the pool can't exceed 1,000,000 $ a day
- When the end user will burn his position of liquidity the beforeModifyPosition hook will call the firewall that will check the invariant according to the risk modeling
- And if the liquidity that has been removed that day is exceeded the threshold by that transaction than the hook can block it with firewall response

### bypass mechanism

- Let's say that the protocol is paused because of risk mitigation
- But the protocol still wants the legitimate users to be able to use the pool
- A legit user can send his transaction to a secure endpoint that will return a signature that approves the list of the legitimate calls
- The end user can send the signature to the protocol
- Then the end user will call the pool and the relevant hook will check with the firewall that the call has been approved
- if the call is approved then the user can use the pool but it hasn't then the hook can block this call


