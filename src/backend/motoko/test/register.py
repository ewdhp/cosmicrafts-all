import subprocess
import random
import string
import time
import sys

USERS_CANISTER = "bkyz2-fmaaa-aaaaa-qaaaq-cai" 
REFERRALS_CANISTER = "bkyz2-fmaaa-aaaaa-qaaaq-cai"

def run_command(command, capture_output=True, text=True):
    """
    Helper function to run a shell command.
    """
    try:
        print(f"Running command: {' '.join(command)}")
        result = subprocess.run(command, capture_output=capture_output, text=text, check=True)
        if capture_output:
            output = result.stdout.strip()
            print(f"Command output: {output}")
            return output
        return None
    except subprocess.CalledProcessError as e:
        print(f"Command {' '.join(command)} failed with error: {e.stderr.strip()}")
        return None

def create_identities(num_identities):
    """
    Creates the specified number of identities and retrieves their principals.
    Returns a list of dictionaries with identity names and principals.
    """
    identities = []
    for i in range(num_identities):
        identity_name = f"player{i + 1}"
        print(f"\nCreating identity: {identity_name}")
        try:
            # Create new identity
            creation_output = run_command(["dfx", "identity", "new", identity_name, "--storage-mode=plaintext"])
            if creation_output is None:
                print(f"Failed to create identity '{identity_name}'. Exiting.")
                sys.exit(1)
            print(f"Identity '{identity_name}' created successfully.")

            # Get the principal of the new identity
            # Temporarily switch to the new identity to get its principal
            switch_output = run_command(["dfx", "identity", "use", identity_name])
            if switch_output is None:
                print(f"Failed to switch to identity '{identity_name}'. Exiting.")
                sys.exit(1)
            print(f"Switched to identity '{identity_name}' to retrieve principal.")

            principal = run_command(["dfx", "identity", "get-principal"])
            if principal:
                print(f"Principal for '{identity_name}': {principal}")
                identities.append({
                    "name": identity_name,
                    "principal": principal,
                    "referral_code": None  # To be filled after registration
                })
            else:
                print(f"Failed to retrieve principal for '{identity_name}'. Exiting.")
                sys.exit(1)
        except Exception as e:
            print(f"Error creating identity '{identity_name}': {e}")
            sys.exit(1)

    # Switch back to default identity after creation
    print("\nSwitching back to 'default' identity for registrations.")
    switch_default = run_command(["dfx", "identity", "use", "default"])
    if switch_default is None:
        print("Failed to switch back to 'default' identity. Exiting.")
        sys.exit(1)
    return identities

def generate_random_username(length=8):
    """
    Generates a random username consisting of lowercase letters and digits.
    """
    return 'user_' + ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def generate_random_avatar_id(max_id=1000):
    """
    Generates a random avatar ID.
    """
    return random.randint(1, max_id)

def get_referral_code(principal):
    """
    Retrieves the referral code for a given principal by calling the referrals canister's getReferralCode function.
    """
    command = [
        "dfx", "canister", "call", REFERRALS_CANISTER,
        "getReferralCode",
        f'(principal "{principal}")'  # Correctly formatted principal
    ]
    output = run_command(command)
    if output:
        # Strip surrounding parentheses if present
        output = output.strip("()")
        # Expected output format: 'opt "REFERRAL_CODE"' or 'null'
        if output.startswith('opt "'):
            referral_code = output[len('opt "'): -1]
            print(f"Retrieved referral code for principal '{principal}': {referral_code}")
            return referral_code
        elif output == "null":
            print(f"No referral code found for principal '{principal}'.")
            return ""
        else:
            print(f"Unexpected output while retrieving referral code for '{principal}': {output}")
            return ""
    print(f"Failed to retrieve referral code for principal '{principal}'.")
    return ""

def register_user(user_id, username, avatar_id, referral_code):
    """
    Registers a user by calling the users canister's signupByID function.
    Returns a tuple (success: bool, message: str).
    """
    # Prepare referral_code parameter
    if referral_code:
        referral_code_str = f'"{referral_code}"'
    else:
        referral_code_str = '""'

    # Construct the argument tuple as per Candid syntax
    # Ensure principal is correctly formatted
    argument = f'(principal "{user_id}", "{username}", {avatar_id}, {referral_code_str})'

    command = [
        "dfx", "canister", "call", USERS_CANISTER,
        "signupByID",
        argument  # No need to wrap in single quotes as run_command handles the string
    ]
    output = run_command(command)
    if output:
        # Expected output format: '(true, "Registration successful")' or '(false, "Error message")'
        try:
            # Remove parentheses
            output = output.strip("()")
            # Split by first comma to separate Bool and Text
            success_part, message_part = output.split(",", 1)
            success = success_part.strip().lower() == "true"
            # Remove surrounding quotes and whitespace from message
            message = message_part.strip().strip('"')
            print(f"Registration result for '{username}': Success={success}, Message='{message}'")
            return success, message
        except Exception as e:
            print(f"Failed to parse registration response: {output}")
            return False, f"Parsing error: {e}"
    print("No response received from registration call.")
    return False, "No response"

def main():
    print("=== DFX Identity and User Registration Script ===\n")

    # Step 1: Get the number of identities to create
    while True:
        try:
            num_identities = int(input("Enter the number of players to register: "))
            if num_identities <= 0:
                print("Please enter a positive integer.")
            else:
                break
        except ValueError:
            print("Invalid input. Please enter a valid number.")

    # Step 2: Create identities and retrieve principals
    identities = create_identities(num_identities)
    if not identities:
        print("No identities were created. Exiting.")
        sys.exit(-1)

    # Step 3: Register each user
    registered_users = []
    for idx, user in enumerate(identities):
        print(f"\n--- Registering User {idx + 1}/{num_identities} ---")

        # Generate random username and avatar ID
        username = generate_random_username()
        avatar_id = generate_random_avatar_id()
        print(f"Generated Username: {username}")
        print(f"Generated Avatar ID: {avatar_id}")

        # Determine referral code
        if idx == 0:
            # First player uses a predefined referral code
            referral_code = "first"
            print(f"Assigned referral code for the first user: {referral_code}")
        else:
            # Ensure that there is at least one registered user
            if not registered_users:
                print("Error: No registered users available to retrieve a referral code.")
                print("Cannot proceed with registration of subsequent users.")
                sys.exit(-1)

            # Retrieve the referral code from the last registered user
            last_registered_user = registered_users[-1]
            last_principal = last_registered_user["principal"]
            print(f"Retrieving referral code from the last registered user: {last_registered_user['username']}")
            referral_code = get_referral_code(last_principal)
            if not referral_code:
                print("Failed to retrieve referral code from the last registered user. Using empty string.")
                referral_code = ""

        # Register the user using the default identity
        success, message = register_user(user["principal"], username, avatar_id, referral_code)
        if success:
            if idx == 0:
                # For the first user, assign the predefined referral code "first"
                user_referral_code = "first"
            else:
                # Retrieve and store the user's referral code from referrals canister
                user_referral_code = get_referral_code(user["principal"])
                if not user_referral_code:
                    print(f"Warning: User '{username}' registered without a referral code.")
                    user_referral_code = ""
            user["referral_code"] = user_referral_code
            registered_users.append({
                "name": user["name"],
                "principal": user["principal"],
                "username": username,
                "avatar_id": avatar_id,
                "referral_code": user_referral_code
            })
        else:
            print(f"Failed to register user '{username}': {message}")
            print("Halting script due to registration failure.")
            sys.exit(1)

        # Optional: Small delay to avoid overwhelming the system
        time.sleep(1)

    # Step 4: Summary of Registered Users
    print("\n=== Registration Summary ===")
    for user in registered_users:
        print(f"Username: {user['username']}, Principal: {user['principal']}, Referral Code: {user['referral_code']}")

    print("\nAll users have been processed successfully.")
    return True

if __name__ == "__main__":
    main()
