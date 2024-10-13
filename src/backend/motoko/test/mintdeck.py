import subprocess
import re

def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(result.stdout)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {command}")
        print(e.stderr)
        return None

def use_identity(identity_name):
    command = f"dfx identity use {identity_name}"
    print(f"Switching to identity: {identity_name}")
    run_command(command)

def get_principal():
    command = "dfx identity get-principal"
    print("Retrieving principal...")
    return run_command(command)

def mint_deck():
    command = "dfx canister call cosmicrafts mintDeck"
    print("Minting deck...")
    output = run_command(command)
    
    if output and "Deck minted" in output:
        nats = re.findall(r'\d+', output)
        nats = [int(nat) for nat in nats]
        print(f"Extracted nats: {nats}")
        return nats
    return []

def main():
    num_players = int(input("Enter the number of players to mint deck for: "))
    
    for i in range(1, num_players + 1):
        identity_name = f"player{i}"
        print(f"\nProcessing for {identity_name}...")
        use_identity(identity_name)
        principal = get_principal()
        if principal:
            mint_deck()

if __name__ == "__main__":
    main()
