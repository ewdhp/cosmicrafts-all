from os import error
import subprocess
import random
import string
import time
import sys
import re

# Default identity for the script
root_id = "3s2fs-u7klb-jmedr-ekalt-oxxmm-u35zu-stqv5-55af6-5osat-gct7a-gqe"


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

def create_and_register():
  print("=== DFX Identity and User Registration Script ===\n")

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

        # Retrieve the referral code from the last registered user
        last_registered_user = registered_users[-1]
        last_principal = last_registered_user["principal"]
        print(f"Retrieving referral code from the last registered user: {last_registered_user['username']}")
        referral_code = get_referral_code(last_principal)
        if not referral_code:
          print("Failed to retrieve referral code from the last registered user. Using empty string.")
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
  return True

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

def get_ids(): 
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
    switch_identity(identity)  # Switch to the identity
    principal_id = get_principal_id()  # Get the principal ID for the active identity
    if principal_id:
        identity_principals[identity] = principal_id

  identity_principals["player0"] = root_id

  switch_identity("default")
  return identity_principals


""" Create posts, comments, and likes """

def create_post(caller_id, images, content, n):  
  
  success, post_id, text = False, None, None

  try:
     
    for _ in range(n): 
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

  except Exception:
      print(f"Error creating post: {error}")

  return success, post_id, text     

def create_comment(
  post_id, 
  post_owner_id, 
  comment_creator_id, 
  content, 
  n
  ):
  
  success, comment_id, text = False, None, None

  for _ in range(n):

    command = [
    "dfx", "canister", "call", "cosmicrafts", "createComment",
    f'( {post_id}, principal "{post_owner_id}", principal {comment_creator_id}, "{content}")']

    try:
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
    except Exception:
      print(f"Error creating comment: {error}")

  return success, comment_id, text
 
def like_post(post_id, caller_id, liker_id):
  command = [
    "dfx", "canister", "call", "bkyz2-fmaaa-aaaaa-qaaaq-cai", "likePost",
    f'({post_id}, principal "{caller_id}", principal "{liker_id}")'
  ]
  result = subprocess.run(command, capture_output=True, text=True)
  output = result.stdout.strip()
  error_output = result.stderr.strip()
  return output, error_output

def like_comment(post_id, post_creator_user_Id, comment_id,comment_liker_id):
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

def send_friend_req(key, request_ids):

  formatted_ids = '; '.join(
      [f'principal "{principal_id}"' 
       for principal_id in request_ids])

  command = [
    "dfx", "canister", "call", "cosmicrafts", "sendFriendRequests",
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
      print(f"send_friend_req, Success: {result.stdout}")
      return True
  except Exception as e:
    print(f"Exception: {e}")
    return False

def add_friends(user_id, friend_ids):

  formatted_ids = '; '.join(
    [f'principal "{principal_id}"' 
      for principal_id in friend_ids])

  command = [
    "dfx", "canister", "call", "cosmicrafts", "blockUsers",
    f'(principal "{user_id}", vec {{ {formatted_ids} }})'
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
      print(f"add_friends, Success: {result.stdout}")
      return True
  except Exception as e:
    print(f"Exception: {e}")
    return False 


""" Block and follow users """

def block_users(id, ids_to_block):

  formatted_ids = '; '.join(
    [f'principal "{principal_id}"' 
      for principal_id in ids_to_block])

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
      print(f"\nblock_users, Success: {result.stdout}")
      return True
  except Exception as e:
    print(f"Exception: {e}")
    return False   

def follow_users(key, follow_ids):

  formatted_ids = '; '.join(
      [f'principal "{principal_id}"' 
       for principal_id in follow_ids])

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
  

""" Main function """

def main():

  switch_identity("default")
  create_and_register() 
  ids = filter_ids(get_ids())
  print("ids size: ",len(ids))
  for _ , id in ids.items():

    print(f"Loading user id: {id[:8]}...")

    block_users(id, ids.values())
    add_friends(id, ids.values())
    follow_users(id, ids.values())
    send_friend_req(id, ids.values())

    success, post_id, text = create_post(
      id, "null", "Post content", 1)

    if not success:
      print(text) 
      return

    print(f"Post created")
   

    commenter_id = '"'+list(ids.values())[1]+'"'     
    success, comment_id, text = create_comment(
    post_id, id, commenter_id, "Comment content", 1)

    if not success:
      print(text) 
      return
    
    print(f"Comment created")



if __name__ == "__main__":
    main()