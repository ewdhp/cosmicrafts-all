import json
from os import error
import subprocess
import random
import string
import time
import sys
import re

# Root user principal ID
root_id = "3s2fs-u7klb-jmedr-ekalt-oxxmm-u35zu-stqv5-55af6-5osat-gct7a-gqe"
dfxIdentities = []

""" Create identities and register users """

def run_command(command, capture_output=True, text=True):
    try:
        result = subprocess.run(command, capture_output=capture_output, text=text, check=True)
        if capture_output:
            output = result.stdout.strip()
            return output
        return None
    except subprocess.CalledProcessError as e:
        print(f"Command {' '.join(command)} failed with error: {e.stderr.strip()}")
    return None

def switch_identity(identity):
    command = ["dfx", "identity", "use", identity]
    result = subprocess.run(command, capture_output=True, text=True, check=True)

def get_principal_id():
    command = ["dfx", "identity", "get-principal"]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode == 0:
        principal_id = result.stdout.strip()
        return principal_id
    else:
        print(f"Error retrieving principal: {result.stderr.strip()}")

def filter_player_identities(identities):
  return [identity for identity in identities if re.match(r'^player\d+$', identity)]

def generate_random_username(length=8):
  return 'user_' + ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def generate_random_avatar_id(max_id=10):
  return random.randint(1, max_id)

def get_referral_code(principal):
  command = [
    "dfx", "canister", "call", "cosmicrafts",
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

    if referral_code:
      referral_code_str = f'"{referral_code}"'
    else:
      referral_code_str = '""'

    argument = f'(principal "{user_id}", "{username}", {avatar_id}, {referral_code_str})'

    command = [
      "dfx", "canister", "call", "cosmicrafts",
      "signupByID",
      argument
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

def get_referral_code(principal):
    try:
        # Call the getReferralCode function using dfx
        result = subprocess.run(
            ["dfx", "canister", "call", "your_canister_name", "getReferralCode", f'(principal "{principal}")'],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the output
        output = result.stdout.strip()
        # Extract the referral code from the output
        referral_code = json.loads(output)
        
        # Check if the referral code is valid
        if referral_code is None or referral_code == "":
            return None
        
        return referral_code
    except subprocess.CalledProcessError as e:
        print(f"An error occurred while retrieving the referral code: {e}")
        return None
    
def setup_users():

  root_exists = False
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
  identities = []
  pattern = re.compile(r"player\d+")
  
  for i in range(num_identities):
      identity_name = f"player{i + 1}"
      if identity_name == "default":
          print(f"Skipping default identity: {identity_name}")
          continue
      
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

          principal = run_command(["dfx", "identity", "get-principal"])
          if principal:
              print(f"Principal for '{identity_name}': {principal}")
              if pattern.match(identity_name):
                  identities.append({
                      "name": identity_name,
                      "principal": principal,
                      "referral_code": None 
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

      # Retrieve a random user's referral code
      if root_exists:
        random_user = random.choice(registered_users)
        random_principal = random_user["principal"]
        print(f"Retrieving referral code from a randomly selected user: {random_user['username']}")
        referral_code = get_referral_code(random_principal)
        if not referral_code:
            print("Failed to retrieve referral code from the randomly selected user. Using empty string.")
            referral_code = ""

      # Register the root user if it does not exist
      if not root_exists:
        success, message = register_user(root_id, "Player0", 4, "first")
        if not success:
          print(f"Failed to register user 'Player0': {message}")
          print("Halting script due to registration failure.")
          sys.exit(1)
  
      registered_users.append({
        "name": "Player0",
        "principal": root_id,
        "username": "Player0",
        "avatar_id": 4,
        "referral_code": "first"})
        
      root_exists = True

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

  # Step 4: Summary of Registered Users
  print("\n=== Registration Summary ===")
  for user in registered_users:
    print(f"Username: {user['username']}, Principal: {user['principal']}, Referral Code: {user['referral_code']}")

  print("\nAll users have been processed successfully.")
  return identities

def get_principal_ids(identities):
  principal_ids = [f'principal "{identity["principal"]}"' for identity in identities]
  return principal_ids

def truncate_list_chars(text_list, max_length):
    return [text[:max_length] for text in text_list]

def select_and_pop_id(identity_principals):
  if not identity_principals:
      return None, identity_principals
  selected_identity = random.choice(list(identity_principals.keys()))
  selected_id = identity_principals.pop(selected_identity)
  return selected_id, identity_principals



  #function to print dict values

def filter_ids(identities):
  filtered_identities = {
     k: v for k, v in identities.items() 
     if k not in ["anonymous", "default"]}
  for key, value in filtered_identities.items():
    print(f"{key}: {value}")
  return filtered_identities

def add_identitie(identities, name, principal):
  identities[name] = principal

def get_identities(): 
  switch_identity("default")

  command = ["dfx", "identity", "list"]   
  result = subprocess.run(command, capture_output=True, text=True)
  identities = []
  if result.returncode == 0:
    for line in result.stdout.splitlines():
      if line.strip(): 
        identity_name = line.split()[0]
        identities.append(identity_name)
  else:
    print(f"Error retrieving identities: {result.stderr.strip()}")
  
  identity_principals = {}
  for identity in identities:
    switch_identity(identity) 
    principal_id = get_principal_id() 
    if principal_id:
        identity_principals[identity] = principal_id

  identity_principals["player0"] = root_id

  switch_identity("default")

  return identity_principals


""" Create posts, comments, and likes """

def create_post(caller_id, images, content):  
  
  success, post_id, text = False, None, None

  try:
    command = [
    "dfx", "canister", "call", "cosmicrafts", "createPostByID",
    f'( principal "{caller_id}", {images}, "{content}")']
    result = subprocess.run(
    command, capture_output=True, text=True)
    output = result.stdout.strip()
    error = result.stderr.strip()
    a = output[1:-1].split(", ") 
    l, _ = a[1].split(':')
    success = a[0].strip()
    post_id = l.strip()
    text = a[2].strip()
    print(f"create_post, Success: {result.stdout}")
  except Exception:
      print(f"Error creating post: {error}")

  return post_id    

def create_comment(post_id, post_owner_id, friend_ids, content, n):
  
  success, comment_id, text = False, None, None

  try:  
    for _ in range(n):
      selected_id = random.choice(list(friend_ids))
      command = [
        "dfx", "canister", "call", "cosmicrafts", "createComment",
        f'( {post_id}, principal "{post_owner_id}", principal "{selected_id}", "{content}")']
      result = subprocess.run(command, 
      stdout=subprocess.PIPE, 
      stderr=subprocess.PIPE, text=True)
      output = result.stdout.strip()
      error = result.stderr.strip()
      a = output[1:-1].split(", ") 
      l, _ = a[1].split(':')
      success = a[0].strip()
      comment_id = l.strip()
      text = a[2].strip()
      print(f"create_comment, Success: {result.stdout}")
  except Exception:
    print(f"Error creating comment: {error}")

  return comment_id
 
def like_post(post_id, caller_id, liker_id):
  command = [
    "dfx", "canister", "call", "cosmicrafts", "likePost",
    f'({post_id}, principal "{caller_id}", principal "{liker_id}")'
  ]
  result = subprocess.run(command, capture_output=True, text=True)
  output = result.stdout.strip()
  error_output = result.stderr.strip()
  return output, error_output

def like_comment(post_id, comment_id, liker_id):
  command = [
    "dfx", "canister", "call", "bkyz2-fmaaa-aaaaa-qaaaq-cai", "likeComment",
    f'({post_id}, principal "{post_creator_user_Id}", {comment_id}, principal "{comment_liker_id}")'
  ]
  try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return result.stdout.strip()
  except Exception as e:
    print(f"An error occurred: {e}")
    return None



""" Add and send friend requests """

def send_friend_req(id, request_ids):
  for friend_id in request_ids:
    command = [
      "dfx", "canister", "call", "cosmicrafts", "sendFriendRequests",
      f'(principal "{id}", vec {{principal "{friend_id}"; }})'
    ]
    try:
      result = subprocess.run(
        command, 
        capture_output=True, 
        text=True)          
      if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
      else:
        print(f"send_friend_req, Success: {result.stdout}")
    except Exception as e:
      print(f"Exception: {e}")
    return False   

def accept_friend_req(user_id, acceoted_ids):
  for id in acceoted_ids:
    command = [
      "dfx", "canister", "call", "cosmicrafts", "acceptFriendReqByID",
        f'(principal "{user_id}", principal "{id}")']       
    try:  
      result = subprocess.run(
        command, 
        capture_output=True, 
        text=True)       
      if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
      else:
        print(f"accept_friend_req, Success: {result.stdout}")
        return True
    except Exception as e:
      print(f"Exception: {e}")
      return False 



""" Block and follow users """

def block_users(id, ids_to_block, n):
  formatted_ids = []
  for _ in range(n):
    selected_id = random.choice(list(ids_to_block))
    formatted_ids.append(f'principal "{selected_id}"') 
  formatted_ids = '; '.join(formatted_ids)
  command = [
    "dfx", "canister", "call", "cosmicrafts", "blockUsers",
    f'(principal "{id}", vec {{ {formatted_ids} }})'
  ]
  try:
    result = subprocess.run(
      command, 
      capture_output=True, 
      text=True)        
    if result.returncode != 0:
      print(f"Error: {result.stderr}")
      return False
    else:
      print(f"block_users, Success: {result.stdout}")
      return True
  except Exception as e:
    print(f"Exception: {e}")
    return False   

def follow_users(key, follow_ids, n):
  formatted_ids = []
  for _ in range(n):
    selected_id = random.choice(list(follow_ids))
    formatted_ids.append(f'principal "{selected_id}"') 
  formatted_ids = '; '.join(formatted_ids)
  command = [
    "dfx", "canister", "call", "cosmicrafts", "followUsers",
    f'(principal "{key}", vec {{ {formatted_ids} }})'
  ]         
  try:  
    result = subprocess.run(
      command, 
      capture_output=True, 
      text=True)       
    if result.returncode != 0:
      print(f"Error: {result.stderr}")
      return False
    else:
      print(f"follow_users, Success: {result.stdout}")
      return True
  except Exception as e:
    print(f"Exception: {e}")
    return False
  


""" Notifications """

def create_notification(from_id, to_id, n):
    results = []
    for _ in range(n):
        try:
            command = [
                "dfx", "canister", "call", "cosmicrafts", "createNotification",
                f'(record {{'
                f'id = null; '
                f'from = variant {{ FriendRequest = principal "{from_id}" }};'
                f'to = variant {{ FriendRequest = principal "{to_id}" }};'
                f'timestamp = null; '
                f'body = "user notification";'
                f'}})'
            ]
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                check=True
            )
            output = result.stdout.strip()
            print(f"create_notification, Success: {output}")
            results.append(output)
        except subprocess.CalledProcessError as e:
            print(f"An error occurred: {e}")
            print(f"Command output: {e.output}")
            print(f"Command stderr: {e.stderr}")
            results.append(None)
    return results


""" Minting deck, chests, missions, stats and nfts"""

def mint_deck(id):
  command = ["dfx", "canister", "call", "cosmicrafts", 
  "mintDeck",f'(principal "{id}")']
  try :
    result = subprocess.run(command, 
    stdout=subprocess.PIPE, 
    stderr=subprocess.PIPE, text=True)
    output = result.stdout.strip()  
    if output and "Deck minted" in output:
      nats = re.findall(r'\d+', output)
      nats = [int(nat) for nat in nats]
      print(f"Extracted nats: {nats}")
    return nats
  except Exception as e:
    print(f"Error minting deck: {e}")
    return 0

def missions():
  command = ["dfx", "canister", "call", "cosmicrafts", 
  "createMissionsPeriodically"]
  try:  
    subprocess.run(command, 
    stdout=subprocess.PIPE, 
    stderr=subprocess.PIPE, text=True)
    print(f"missions, Success")
  except Exception as e:
    print(f"Error creating missions: {e}")
  
def call_mint_chest(player_id, rarity):
  candid_arg = f'(principal "{player_id}", {rarity})'
  command = [
    "dfx", "canister", "call", "cosmicrafts", "mintChest",
    candid_arg
  ]
  try:
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    output = result.stdout.strip()
    print(f"Raw output: {output}")
  except subprocess.CalledProcessError as e:
    print(f"An error occurred: {e}")
    print(f"Command output: {e.output}")
    print(f"Command stderr: {e.stderr}")
    return None


""" Main function """

def main():
  print("=== DFX Identity and User Registration Script ===\n")

  identities = setup_users() 
  identities = get_identities()
  ids = filter_ids(identities)

  print("Identities",identities)

  missions()
  mint_deck("3s2fs-u7klb-jmedr-ekalt-oxxmm-u35zu-stqv5-55af6-5osat-gct7a-gqe")

  for name, principal in ids.items():   
    if name != "player0":
      switch_identity(name)
    
    print(f"Name: {name}, Principal ID: {principal}")
    post_id = create_post(principal, "null", "Post")
    create_comment(post_id, principal, ids.values(), "Comment", len(ids.values()) - 1)    
    send_friend_req(principal, ids.values())
    accept_friend_req(principal,ids.values())
    follow_users(principal, ids.values(), len(ids.values()) - 1)
    block_users(principal, ids.values(),len(ids.values()) - 1)
    create_notification(principal, principal, len(ids.values()) - 1)
    
  switch_identity("default")


if __name__ == "__main__":
  main()
