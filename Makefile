CHAINID=agoriclocal
USER1ADDR=$(shell agd keys show localGov1 -a --keyring-backend="test")
VALIDATOR = $(shell agd keys show -a localValidator --keyring-backend=test)
ACCT_ADDR=$(USER1ADDR)
BLD=000000ubld

SDK_ROOT=/Users/anil/WebstormProjects/agoric-samples/agoric-sdk-liquidation-visibility
AGD=$(SDK_ROOT)/bin/agd
PROPOSAL_SCRIPT=$(SDK_ROOT)/packages/inter-protocol/scripts/liquidation-visibility-upgrade.js
BUNDLES_PATH=$(SDK_ROOT)/packages/inter-protocol/bundles
BUNDLE_TARGET=$(SDK_ROOT)/packages/inter-protocol/src/vaultFactory/vaultFactory.js
BUNDLE_NAME=vaultFactory

ATOM_DENOM=ibc/BA313C4A19DFBF943586C0387E6B11286F9E416B4DD27574E6909CABE0E342FA
ATOM=000000$(ATOM_DENOM)

VAULT_BUNDLE_ID = @$(call GetFromPlan, bundles[0].fileName)
MANIFEST_BUNDLE_ID = @/$(call GetFromPlan, bundles[1].fileName)

define GetFromPlan
$(shell node -p "require('./upgrade-vaults-liq-visibility-plan.json').$(1)")
endef

GAS_ADJUSTMENT=1.2
SIGN_BROADCAST_OPTS=--keyring-backend=test --chain-id=$(CHAINID) \
		--gas=auto --gas-adjustment=$(GAS_ADJUSTMENT) \
		--yes -b block

WANT_VALUE=20000
GIVE_VALUE=10000
TO=$(USER1ADDR)
mint-ist:
	make FUNDS=$(GIVE_VALUE)$(ATOM) ACCT_ADDR=$(TO) fund-acct -f Makefile
	cd $(SDK_ROOT) && \
		yarn --silent agops vaults open --wantMinted $(WANT_VALUE) --giveCollateral $(GIVE_VALUE) >/tmp/want-ist.json && \
		yarn --silent agops perf satisfaction --executeOffer /tmp/want-ist.json --from $(TO) --keyring-backend=test
	sleep 3

FUNDS=321$(BLD)
fund-acct:
	agd tx bank send $(VALIDATOR) $(ACCT_ADDR) $(FUNDS) \
	  $(SIGN_BROADCAST_OPTS) \
	  -o json >,tx.json
	jq '{code: .code, height: .height}' ,tx.json

balance-q: target = $(shell agd keys show $(TARGET) -a --keyring-backend="test")
balance-q:
	agd keys show $(target) -a --keyring-backend="test"
	agd query bank balances $(target)

bundle:
	cd $(SDK_ROOT) && \
	yarn bundle-source --cache-js $(BUNDLES_PATH) $(BUNDLE_TARGET) $(BUNDLE_NAME)

build-prop: bundle
	agoric run $(PROPOSAL_SCRIPT)

install-vault-bundle:
	${AGD} tx swingset install-bundle ${VAULT_BUNDLE_ID} --from=${USER1ADDR} $(SIGN_BROADCAST_OPTS)

install-manifest-bundle:
	${AGD} tx swingset install-bundle ${MANIFEST_BUNDLE_ID} --from=${USER1ADDR} $(SIGN_BROADCAST_OPTS)

install-bundles: install-vault-bundle install-manifest-bundle

submit-proposal:
	${AGD} tx gov submit-proposal swingset-core-eval $(call GetFromPlan, permit) $(call GetFromPlan, script) \
		--title="Enable vaultFactory update" --description="Update vaultFactory to extend liquidation visibility" --deposit=10000000ubld \
		--from=${USER1ADDR} $(SIGN_BROADCAST_OPTS)

vote: PROPOSAL = $(shell agd query gov proposals --output json | jq -c '.proposals[-1].proposal_id')
vote:
	$(AGD) tx gov vote $(PROPOSAL) yes --from=${VALIDATOR} $(SIGN_BROADCAST_OPTS)