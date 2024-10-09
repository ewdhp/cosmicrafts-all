import json
import subprocess
import random
import string
import time
import sys
import re
import requests

# Configuration
USERS_CANISTER = "bkyz2-fmaaa-aaaaa-qaaaq-cai"  # Replace with your actual 'users' canister name if different
CALLER_ID = "3s2fs-u7klb-jmedr-ekalt-oxxmm-u35zu-stqv5-55af6-5osat-gct7a-gqe"

# Function to switch to a given identity
def switch_identity(identity):
    command = ["dfx", "identity", "use", identity]
    result = subprocess.run(command, capture_output=True, text=True)

# Function to get principal ID for the currently active identity
def get_principal_id():
    command = ["dfx", "identity", "get-principal"]
    print(f"Running command: {command}")  # Debug print

    result = subprocess.run(command, capture_output=True, text=True)

    if result.returncode == 0:
        principal_id = result.stdout.strip()
        return principal_id
    else:
        print(f"Error retrieving principal: {result.stderr.strip()}")
        return None

# Function to get created identities from dfx command
def get_created_identities():
    command = ["dfx", "identity", "list"]
    print("Running command:", " ".join(command))  # Debug print

    result = subprocess.run(command, capture_output=True, text=True)

    identities = []
    if result.returncode == 0:
        print("Command output:", result.stdout.strip())  # Debug print
        # Parse the output to extract identity names
        for line in result.stdout.splitlines():
            if line.strip() and not line.startswith("*"):  # Ignore the current default identity
                identity_name = line.split()[0]  # The first part is the identity name
                identities.append(identity_name)
    else:
        print(f"Error retrieving identities: {result.stderr.strip()}")

    return identities

# Function to filter identities based on the pattern "player<number>"
def filter_player_identities(identities):
    return [identity for identity in identities if re.match(r'^player\d+$', identity)]

# Function to add a friend
def add_friend(user_id, friend_id):
    command = [
        "dfx", "canister", "call", USERS_CANISTER,
        "addFriend",
        f'(principal "{user_id}", principal "{friend_id}")'  # Ensure friend_id is passed correctly
    ]
    return run_command(command)

# Function to create a post
def create_post(caller_id, images, content):
    command = [
        "dfx", "canister", "call", "bkyz2-fmaaa-aaaaa-qaaaq-cai", "createPostByID",
        f'( principal "{caller_id}", null, "{content}")'
    ]
    print(f"Debug: Running command: {' '.join(command)}")  # Debug: Print the command being run
    result = subprocess.run(command, capture_output=True, text=True)
    output = result.stdout.strip()
    error_output = result.stderr.strip()

    # Debug print statements to inspect the actual output and error output
    print(f"Debug: Raw output from dfx canister call: {output}")
    print(f"Debug: Error output from dfx canister call: {error_output}")

    if not output:
        raise ValueError("Error: No output returned from dfx canister call")

    try:
        # Parse the output format (3 : int)
        match = re.search(r'\((\d+) : int\)', output)
        if match:
            post_id = int(match.group(1))
            return post_id
        else:
            raise ValueError(f"Unexpected output format: {output}")
    except ValueError:
        raise ValueError(f"Unexpected output format: {output}")


# Function to get identity name by principal ID
def get_identity_name_by_principal(principal_id, identity_principals):
    for identity, principal in identity_principals.items():
        if principal == principal_id:
            return identity
    return None


# Assuming run_command is similar to subprocess.run for dfx canister calls
def run_command(command):
    result = subprocess.run(command, capture_output=True, text=True)
    return result.stdout.strip(), result.stderr.strip()


# Function to like a post
def like_post(post_id, caller_id, liker_id):
    command = [
        "dfx", "canister", "call", "bkyz2-fmaaa-aaaaa-qaaaq-cai", "likePost",
        f'({post_id}, principal "{caller_id}", principal "{liker_id}")'
    ]
    print(f"Debug: Running command: {' '.join(command)}")  # Debug: Print the command being run
    result = subprocess.run(command, capture_output=True, text=True)
    output = result.stdout.strip()
    error_output = result.stderr.strip()

    # Debug print statements to inspect the actual output and error output
    print(f"Debug: Raw output from dfx canister call: {output}")
    print(f"Debug: Error output from dfx canister call: {error_output}")

    return output, error_output

# Function to like a comment
def like_comment(post_id, post_creator_user_Id, comment_id,comment_liker_id):
    command = [
        "dfx", "canister", "call", "bkyz2-fmaaa-aaaaa-qaaaq-cai", "likeComment",
        f'({post_id}, principal "{post_creator_user_Id}", {comment_id}, principal "{comment_liker_id}")'
    ]
    print("Running command:", ' '.join(command))

    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.stdout.strip()
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

# Function to follow a user
def follow_user(caller_id, follow_id):
    command = [
        "dfx", "canister", "call", USERS_CANISTER,
        "followUser",
        f'(principal "{follow_id}")'
    ]
    return run_command(command)

# Function to get user basic info by principal ID
def get_user_basic_info(principal_id):
    command = [
        "dfx", "canister", "call", "cosmicrafts", "getUserBasicInfoByID",
        f'(principal "{principal_id}")'
    ]
    result = run_command(command)
    if result:
        # Parse the output to extract the username
        match = re.search(r'username\s*=\s*"([^"]+)"', result)
        if match:
            return match.group(1)
    return None

# Function to get principal ID by identity name
def get_username(user_id):
    command = [
        "dfx", "canister", "call", "cosmicrafts", "getUserBasicInfoByID",
        f'(principal "{user_id}")'
    ]
    result = run_command(command)
    if result:
        # Parse the output to extract the username
        match = re.search(r'username\s*=\s*"([^"]+)"', result)
        if match:
            return match.group(1)
    return None

# Helper function to get random friends to add
def get_random_friends(all_users, current_user, num_friends=2):
    potential_friends = [user for user in all_users if user != current_user]
    return random.sample(potential_friends, min(num_friends, len(potential_friends)))

# Helper function to get random followers to add
def get_random_followers(all_users, current_user, num_followers=2):
    potential_followers = [user for user in all_users if user != current_user]
    return random.sample(potential_followers, min(num_followers, len(potential_followers)))

# Function to switch identity by principal ID
def switch_identity_by_principal(principal_id):
    # This function should map the principal ID to the corresponding identity name
    # and switch to that identity. For simplicity, we assume the identity name is the same as the principal ID.
    switch_identity(principal_id)

# Function to call the createComment method
def create_comment(post_id, post_owner_id, comment_creator_id, content):
    # Prepare the DFX command, ensuring the entire argument is wrapped in quotes
    command = [
        'dfx', 'canister', 'call',
        'cosmicrafts',  # Replace with your canister name
        'createComment',
        f'({post_id}, principal "{post_owner_id}", principal "{comment_creator_id}", "{content}")'  # Wrap in a single string
    ]

    # Print the command for debugging
    print("Running command:", ' '.join(command))

    # Execute the command
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output = result.stdout.strip()
        a = output[1:-1].split(", ") 
        l,_ = a[1].split(':')
        return a[0].strip(), l.strip(), a[2].strip() 

    except Exception as e:
        print(f"An error occurred: {e}")
        return None


def main():
    n = 1 # Define the number of posts, comments, and likes

    # Retrieve created identities
    identities = get_created_identities()
    
    # Filter identities that match "player<number>"
    player_identities = filter_player_identities(identities)

    # Create a dictionary to hold identity names and their corresponding principal IDs
    identity_principals = {}

    # Get principal IDs for each player identity
    for identity in player_identities:
        switch_identity(identity)  # Switch to the identity
        principal_id = get_principal_id()  # Get the principal ID for the active identity
        if principal_id:
            identity_principals[identity] = principal_id

    # Switch back to the default identity
    switch_identity("default")

    
    print("Function to create posts, comments, and likes")

    # Inner Function to create posts, comments, and likes
    def create_posts_comments_likes(n, identity_principals):

        for _ in range(n):


            ##########################################
            # Create posts

            print("Calling create_post")
            
            try:
                post_id = create_post(
                    CALLER_ID,
                    None, 
                    "Sample post content"
                    )       
                        
                post_id_int = int(post_id)

            except ValueError as e:
                    print(e)

            if post_id == -1:
                print("Failed to create post")
                continue


            ##########################################
            # Like posts

            for _ in range(n):

                liker_id = random.choice(
                    list(identity_principals.values())
                    )

                print("Calling like_post", post_id_int)

                try:
                    like_post(
                        post_id_int, 
                        CALLER_ID, 
                        liker_id
                        )

                except ValueError as e:
                    print(e)

            ##########################################
            # Create comments

            for _ in range(n):

                print("Calling create_comment")

                try:
                    comment_creator_id = random.choice(
                    list(identity_principals.values()))

                    success, comment_id, message = create_comment(post_id_int, CALLER_ID, comment_creator_id, "Sample comment content")
                    print(f"Success: {success}, Comment ID: {comment_id}, Message: {message}")

                except ValueError as e:
                    print(e)
               
                ##########################################
                # Like comments

                for _ in range(n):

                    liker_id = random.choice(list(identity_principals.values()))
                    
                    print(f"Success: {success}, Comment ID: {comment_id}, Message: {message}")
                    print("Calling like_comment")

                    success = like_comment(
                        post_id_int,
                        CALLER_ID, 
                        comment_id, 
                        liker_id,
                    )
                    
                    print(f"Success: {success}")


    ##########################################
    # Example usage
    create_posts_comments_likes(n, identity_principals)
    switch_identity("default")

if __name__ == "__main__":
    main()