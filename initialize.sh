#!/bin/bash

set -e

NETWORK="$1"

SOROBAN_RPC_HOST="$2"

PK=GCSXUXZSA2VEXN5VGOWE5ODAJLC575JCMWRJ4FFRDWSTRCJYQK4ML6V3

WASM_PATH="target/wasm32-unknown-unknown/release/"
MULTISIG_WASM=$WASM_PATH"soroban_multisig_contract.optimized.wasm"
ABUNDANCE_WASM="./contracts/multisig/soroban_token_contract.wasm"

# PATH=./target/bin:$PATH

if [[ -f "./.soroban-example-dapp" ]]; then
  echo "Removing previous deployments"

  rm -rf ./.soroban-example-dapp
  rm -rf ./.soroban
fi

if [[ "$SOROBAN_RPC_HOST" == "" ]]; then
  # If soroban-cli is called inside the soroban-preview docker container,
  # it can call the stellar standalone container just using its name "stellar"
  if [[ "$IS_USING_DOCKER" == "true" ]]; then
    SOROBAN_RPC_HOST="http://stellar:8000"
    SOROBAN_RPC_URL="$SOROBAN_RPC_HOST"
  elif [[ "$NETWORK" == "futurenet" ]]; then
    SOROBAN_RPC_HOST="https://rpc-futurenet.stellar.org:443"
    SOROBAN_RPC_URL="$SOROBAN_RPC_HOST"
  else
     # assumes standalone on quickstart, which has the soroban/rpc path
    SOROBAN_RPC_HOST="http://localhost:8000"
    SOROBAN_RPC_URL="$SOROBAN_RPC_HOST/soroban/rpc"
  fi
else 
  SOROBAN_RPC_URL="$SOROBAN_RPC_HOST"  
fi

case "$1" in
standalone)
  SOROBAN_NETWORK_PASSPHRASE="Standalone Network ; February 2017"
  FRIENDBOT_URL="$SOROBAN_RPC_HOST/friendbot"
  ;;
futurenet)
  SOROBAN_NETWORK_PASSPHRASE="Test SDF Future Network ; October 2022"
  FRIENDBOT_URL="https://friendbot-futurenet.stellar.org/"
  ;;
*)
  echo "Usage: $0 standalone|futurenet [rpc-host]"
  exit 1
  ;;
esac

echo "Using $NETWORK network"
echo "  RPC URL: $SOROBAN_RPC_URL"
echo "  Friendbot URL: $FRIENDBOT_URL"
echo "  Public key: $PK"

echo Add the $NETWORK network to cli client
soroban config network add \
  --rpc-url "$SOROBAN_RPC_URL" \
  --network-passphrase "$SOROBAN_NETWORK_PASSPHRASE" "$NETWORK"

echo Add $NETWORK to .soroban-example-dapp for use with npm scripts
mkdir -p .soroban-example-dapp
echo $NETWORK > ./.soroban-example-dapp/network
echo $SOROBAN_RPC_URL > ./.soroban-example-dapp/rpc-url
echo "$SOROBAN_NETWORK_PASSPHRASE" > ./.soroban-example-dapp/passphrase

if !(soroban config identity ls | grep example-user 2>&1 >/dev/null); then
  echo Create the example-user identity
  soroban config identity generate example-user
fi
EXAMPLE_USER_ADDRESS="$(soroban config identity address example-user)"
EXAMPLE_USER_SECRET="$(soroban config identity show example-user)"

# This will fail if the account already exists, but it'll still be fine.
echo Fund example-user account from friendbot
curl --silent -X POST "$FRIENDBOT_URL?addr=$EXAMPLE_USER_ADDRESS" >/dev/null
curl --silent -X POST "$FRIENDBOT_URL?addr=$PK" >/dev/null

ARGS="--network $NETWORK --source example-user"

echo "Building contracts"
soroban contract build
echo "Optimizing contracts"
soroban contract optimize --wasm $WASM_PATH"soroban_multisig_contract.wasm"
soroban contract optimize --wasm $ABUNDANCE_WASM --wasm-out $WASM_PATH"soroban_token_contract.optimized.wasm"

echo Deploy the multisig contract
MULTISIG_ID="$(
  soroban contract deploy \
  $ARGS \
  --wasm $MULTISIG_WASM
)"
echo "Contract deployed succesfully with ID: $MULTISIG_ID"
echo "$MULTISIG_ID" > .soroban-example-dapp/multisig_id

echo Deploy the abundance token contract
ABUNDANCE_ID="$(
  soroban contract deploy \
  $ARGS \
  --wasm $ABUNDANCE_WASM
)"
echo "Contract deployed succesfully with ID: $ABUNDANCE_ID"

echo "Initialize the abundance token contract"
soroban contract invoke \
  $ARGS \
  --id "$ABUNDANCE_ID" \
  -- \
  initialize \
  --symbol USDC \
  --decimal 7 \
  --name USDCoin \
  --admin "$EXAMPLE_USER_ADDRESS"

echo funding public key
soroban contract invoke \
  $ARGS \
  --id "$ABUNDANCE_ID" \
  -- \
  mint \
  --to "$PK" \
  --amount 1000000000

echo "Minted 100 USDC to $PK"

echo funding multisig
soroban contract invoke \
  $ARGS \
  --id "$ABUNDANCE_ID" \
  -- \
  mint \
  --to "$MULTISIG_ID" \
  --amount 1000000000

echo "Generating bindings"
soroban contract bindings typescript --wasm $WASM_PATH"soroban_token_contract.optimized.wasm" --network $NETWORK --contract-id $ABUNDANCE_ID --contract-name token-a --output-dir ".soroban/contracts/token-a"
soroban contract bindings typescript --wasm $MULTISIG_WASM --network $NETWORK --contract-id $MULTISIG_ID --contract-name multisig --output-dir ".soroban/contracts/multisig"

echo "Done"
