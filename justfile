dir := "corridor_eligibility"

default:
    @just --list

check:
    cd {{dir}} && nargo check

test:
    cd {{dir}} && nargo test

execute:
    cd {{dir}} && nargo execute

fmt:
    cd {{dir}} && nargo fmt

info:
    cd {{dir}} && nargo info

# regenerate Prover.toml from corridor-sdk (assumes it's a sibling checkout)
fixture:
    cd ../corridor-sdk && npm run gen-fixture > ../corridor-circuits/{{dir}}/Prover.toml
