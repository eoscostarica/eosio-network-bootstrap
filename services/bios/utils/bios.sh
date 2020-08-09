#!/usr/bin/env bash

set -e;

EOSIO_CONTRACTS_DIRECTORY=/opt/eosio.contracts/build/contracts

store_secret_on_vault() {
  echo "Unimplemented feature, waiting for vault to store secrets in"
}

unlock_wallet() {
  cleos wallet unlock --password $(cat /opt/application/secrets/wallet_password.txt) \
    || echo "Wallet has already been unlocked..."
}

create_wallet() {
  mkdir -p /opt/application/secrets
  cleos wallet create --to-console \
    | awk 'FNR > 3 { print $1 }' \
    | tr -d '"' \
    > /opt/application/secrets/wallet_password.txt;
  cleos wallet open;
  unlock_wallet
  cleos wallet import --private-key $EOS_PRIV_KEY;
}

create_system_accounts() {
  system_accounts=( \
    "eosio.msig" \
    "eosio.token" \
  )

  for account in "${system_accounts[@]}"; do
    echo "Creating $account account..."

    keys=($(cleos create key --to-console))
    pub=${keys[5]}
    priv=${keys[2]}

    cleos wallet import --private-key $priv

    cleos create account eosio $account $pub;
  done
}

activate_features() {
  # GET_SENDER
  cleos push action eosio activate '["f0af56d2c5a48d60a4a5b5c903edfb7db3a736a94ed589d0b797df33ff9d3e1d"]' -p eosio

  # FORWARD_SETCODE
  cleos push action eosio activate '["2652f5f96006294109b3dd0bbde63693f55324af452b799ee137a81a905eed25"]' -p eosio

  # ONLY_BILL_FIRST_AUTHORIZER
  cleos push action eosio activate '["8ba52fe7a3956c5cd3a656a3174b931d3bb2abb45578befc59f283ecd816a405"]' -p eosio

  # RESTRICT_ACTION_TO_SELF
  cleos push action eosio activate '["ad9e3d8f650687709fd68f4b90b41f7d825a365b02c23a636cef88ac2ac00c43"]' -p eosio

  # DISALLOW_EMPTY_PRODUCER_SCHEDULE
  cleos push action eosio activate '["68dcaa34c0517d19666e6b33add67351d8c5f69e999ca1e37931bc410a297428"]' -p eosio

  # FIX_LINKAUTH_RESTRICTION
  cleos push action eosio activate '["e0fb64b1085cc5538970158d05a009c24e276fb94e1a0bf6a528b48fbc4ff526"]' -p eosio

  # REPLACE_DEFERRED
  cleos push action eosio activate '["ef43112c6543b88db2283a2e077278c315ae2c84719a8b25f25cc88565fbea99"]' -p eosio

  # NO_DUPLICATE_DEFERRED_ID
  cleos push action eosio activate '["4a90c00d55454dc5b059055ca213579c6ea856967712a56017487886a4d4cc0f"]' -p eosio

  # ONLY_LINK_TO_EXISTING_PERMISSION
  cleos push action eosio activate '["1a99a59d87e06e09ec5b028a9cbb7749b4a5ad8819004365d02dc4379a8b7241"]' -p eosio

  # RAM_RESTRICTIONS
  cleos push action eosio activate '["4e7bf348da00a945489b2a681749eb56f5de00b900014e137ddae39f48f69d67"]' -p eosio

  # WEBAUTHN_KEY
  cleos push action eosio activate '["4fca8bd82bbd181e714e283f83e1b45d95ca5af40fb89ad3977b653c448f78c2"]' -p eosio

  # WTMSIG_BLOCK_SIGNATURES
  cleos push action eosio activate '["299dcb6af692324b899b39f16d5a530a33062804e41f09dc97e9f156b4476707"]' -p eosio
}

deploy_system_contracts() {
  # Deploy eosio.token
  cleos set contract eosio.token $EOSIO_CONTRACTS_DIRECTORY/eosio.token/
  sleep 2;

  cleos set contract eosio.msig $EOSIO_CONTRACTS_DIRECTORY/eosio.msig/
  sleep 2;

  curl --request POST \
    --url http://127.0.0.1:8888/v1/producer/schedule_protocol_feature_activations \
    -d '{"protocol_features_to_activate": ["0ec7e080177b2c02b278d5088611686b49d739925a92d9bfcacd7fc6b74053bd"]}'
  sleep 2;

  ## Set eosio.bios system contract
  result=1
  set +e;
  while [ "$result" -ne "0" ]; do
    echo "Setting eosio.bios contract...";
    cleos set contract eosio \
      $EOSIO_CONTRACTS_DIRECTORY/eosio.bios/ \
      -x 1000;
    result=$?
    [[ "$result" -ne "0" ]] && echo "Failed, trying again";
  done
  set -e;

  activate_features

}

set_msig_privileged_account() {
  cleos push action eosio setpriv \
    '["eosio.msig", 1]' -p eosio@active
}

init_system_account() {
  cleos push action eosio init \
    '["0", "4,SYS"]' -p eosio@active
}

run_bios() {
  create_wallet
  create_system_accounts
  deploy_system_contracts
  set_msig_privileged_account
  init_system_account
}