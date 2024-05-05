## Validator Experiments

This repo contains experiments towards making validation composable. The goal is to make validation schemes like the following possible:

- A multi-owner validation where different owners use different kinds of cryptographic signatures, e.g. ECDSA vs whatever passkeys use.
- A multisig validation where different signers use different validation schemes, including some of those schemes possibly being multi-owner or multisig validation in themselves.
- A multisig validation where an individual owner has the ability to change their validation scheme independently of the others.

Today's existing ERC-6900 plugins do not have this kind of flexibility. For example, the `MultiOwnerPlugin` can only ever use ECDSA signatures, and it cannot itself be easily be used as one of several signers in a multi-sig plugin.

### The plan

Rather than composing plugins, we'll define a new interface with composibility as its primary goal and compose instances of that interface instead. This interface is `IValidator`, which exposes a single function `validateUserOp`, which is similar to the same method on `IAccount` but with a few differences:

- It takes a `signature` parameter separate from the user operation. This allows parent validators to pass portions of the signature to child validators.
- It takes a `validationId` parameter. This allows an account to select from several different configurations in an `IValidator`, such as choosing which public key to validate against in an ECDSA-checking validator.
- It takes an `account` address parameter. This is needed as a technical detail so validators can be sure to only access storage associated with the account.

For more details, see the comments in `IValidator.sol`.

### Examples

This repo contains examples of three `IValidator` implementations:

- `EcdsaValidator`: a validator which checks that a signature is an ECDSA signature from a particular address.
- `MultiOwnerValidator`: a validator which checks that a signature is valid according to one of several child validators.
- `ThresholdValidator`: a validator which checks that the signature contains valid signatures for k-of-n child validators.

Additionally, the repo contains a plugin, `ValidatorOwnerPlugin`, which demonstrates how these validators can be used in ERC-6900 plugins.

### Limitations

For now, this is entirely focused on user op validation. No exploration has been done towards runtime validation or ERC-1271 signature verification.

Some tests would probably be nice.

It is unclear how this can be applied to validation with side-effects, such as validation which caps gas spend or validation which allows a certain signature to be used one time only. The validators defined in this repo, since they have no side-effects, can be freely called by anyone without consequence, but validators with side-effects need to make sure that those side-effects only occur during the connected smart contract account's validation step.

It would be interesting to explore how this can be applied in an implementation of session key plugin.

In the example implementations, a "validation instance," specified by a validator address and "validation id," is immutable, which means e.g. if you want to change the owner list for a validation in the `MultiOwnerPlugin`, you must instead register a new validation with an updated owner list and switch any references to from the old validation to the new one. It would be interesting to explore mutable validations, as suggested by the last example in the first section above.
