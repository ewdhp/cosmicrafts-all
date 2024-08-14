import subprocess
import json
import logging
import re
import random
import time
import sys
import signal

# Set up logging
#logging.basicConfig(filename='logs/matchmaking.log', level=logging.INFO, format='%(asctime)s - %(message)s')

def execute_dfx_command(command, log_output=True):
    """Executes a shell command and logs the output."""
    command = f"{command} --ic"  # Add --ic to the command
    for attempt in range(3):  # Retry up to 3 times
        result = subprocess.run(command, capture_output=True, text=True, shell=True)
        if result.returncode == 0:
            output = result.stdout.strip()
            if log_output:
                logging.info(f"Command: {command}")
                logging.info(f"Output: {output}")
            return output
        else:
            error_message = f"Command failed: {command}\n{result.stderr.strip()}"
            logging.error(error_message)
            if attempt < 2:  # Only retry if not the last attempt
                logging.info("Retrying...")
                time.sleep(1)
            else:
                raise Exception(error_message)  # Raise an exception to halt on error
    return None

def switch_identity(identity_name):
    """Switches the DFX identity."""
    execute_dfx_command(f"dfx identity use {identity_name}", log_output=False)

def get_principal(identity_name):
    """Gets the principal of the current identity."""
    switch_identity(identity_name)
    principal = execute_dfx_command("dfx identity get-principal")
    logging.info(f"{identity_name} principal: {principal}")
    return principal

def get_match_searching(identity_name, player_game_data):
    """Starts searching for a match."""
    switch_identity(identity_name)
    player_game_data_str = json.dumps(player_game_data)
    command = f'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai getMatchSearching \'{player_game_data_str}\''
    return execute_dfx_command(command)

def set_player_active(identity_name):
    """Sets the player as active."""
    switch_identity(identity_name)
    command = 'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai setPlayerActive'
    return execute_dfx_command(command)

def is_game_matched(identity_name):
    """Checks if the game is matched."""
    switch_identity(identity_name)
    command = 'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai isGameMatched'
    return execute_dfx_command(command)

def save_finished_game(identity_name, game_id, stats):
    """Saves the finished game statistics using Nat values."""
    switch_identity(identity_name)

    stats_str = (
        'record {'
        f'botDifficulty = {stats["botDifficulty"]}; '
        f'botMode = {stats["botMode"]}; '
        f'characterID = {stats["characterID"]}; '
        f'damageCritic = {stats["damageCritic"]}; '        # Changed to Nat
        f'damageDealt = {stats["damageDealt"]}; '          # Changed to Nat
        f'damageEvaded = {stats["damageEvaded"]}; '        # Changed to Nat
        f'damageTaken = {stats["damageTaken"]}; '          # Changed to Nat
        f'deploys = {stats["deploys"]}; '                  # Changed to Nat
        f'energyChargeRate = {stats["energyChargeRate"]}; '  # Changed to Nat
        f'energyGenerated = {stats["energyGenerated"]}; '  # Already Nat
        f'energyUsed = {stats["energyUsed"]}; '            # Changed to Nat
        f'energyWasted = {stats["energyWasted"]}; '        # Changed to Nat
        f'faction = {stats["faction"]}; '
        f'gameMode = {stats["gameMode"]}; '
        f'kills = {stats["kills"]}; '                      # Changed to Nat
        f'secRemaining = {stats["secRemaining"]}; '        # Already Nat
        f'wonGame = {str(stats["wonGame"]).lower()}; '
        f'xpEarned = {stats["xpEarned"]}; '                # Changed to Nat
        '}'
    )

    command = f'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai saveFinishedGame \'({game_id}, {stats_str})\''
    logging.info(f"Constructed command: {command}")
    return execute_dfx_command(command)

def get_my_match_data(identity_name):
    """Gets match data for the current player."""
    switch_identity(identity_name)
    command = 'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai getMyMatchData'
    return execute_dfx_command(command)

def get_basic_stats(match_id):
    """Gets basic stats for the specified match ID."""
    command = f'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai getMatchStats {match_id}'
    return execute_dfx_command(command)

def parse_match_id(search_result):
    """Extracts the match ID from the search result."""
    match = re.search(r'\(variant \{ Assigned \}, (\d+(_\d+)*) : nat,', search_result)
    if match:
        match_id_str = match.group(1).replace('_', '')  # Remove underscores
        return int(match_id_str)
    else:
        raise ValueError("Match ID not found in the search result")

def generate_random_stats(shared_energy_generated, shared_sec_remaining, won):
    """Generates randomized game statistics using Nat values."""
    stats = {
        "botDifficulty": random.randint(0, 5),
        "botMode": random.randint(0, 5),
        "characterID": random.randint(1, 2),
        "damageCritic": random.randint(1000, 25000),  # Changed to random integer
        "damageDealt": random.randint(1000, 25000),   # Changed to random integer
        "damageEvaded": random.randint(1000, 25000),  # Changed to random integer
        "damageTaken": random.randint(1000, 25000),   # Changed to random integer
        "deploys": random.randint(10, 225),           # Changed to random integer
        "energyChargeRate": random.randint(33, 200),  # Changed to random integer
        "energyGenerated": shared_energy_generated,   # Already Nat
        "energyUsed": random.randint(33, 200),        # Changed to random integer
        "energyWasted": random.randint(33, 200),      # Changed to random integer
        "faction": random.randint(0, 2),
        "gameMode": random.randint(1, 2),
        "kills": random.randint(10, 250),             # Changed to random integer
        "secRemaining": shared_sec_remaining,         # Already Nat
        "wonGame": won,
        "xpEarned": random.randint(1000, 25000)       # Changed to random integer
    }
    return stats

def get_current_mission_progress(identity_name):
    """Gets the current mission progress for the current identity."""
    switch_identity(identity_name)
    command = 'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai getCurrentMissionProgress'
    return execute_dfx_command(command)

def claim_user_specific_reward(identity_name, mission_id):
    """Claims the user-specific reward for the given mission ID."""
    switch_identity(identity_name)
    command = f'dfx canister call fdaor-cqaaa-aaaao-ai7nq-cai claimUserSpecificReward \'({mission_id})\''
    return execute_dfx_command(command)

def handle_mission_progress(identity_name):
    """Handles the mission progress after saving the finished game."""
    progress_result = get_current_mission_progress(identity_name)
    logging.info(f"Mission progress for {identity_name}: {progress_result}")
####print(f"Mission progress for {identity_name}: {progress_result}")

    # Parse the progress result to check if the mission is finished
    if "record" in progress_result and "finished = true" in progress_result:
        match = re.search(r'id_mission = (\d+) : nat', progress_result)
        if match:
            mission_id = match.group(1)
            claim_result = claim_user_specific_reward(identity_name, mission_id)
            logging.info(f"Claim result for mission ID {mission_id} for {identity_name}: {claim_result}")
            print(f"Claim result for mission ID {mission_id} for {identity_name}: {claim_result}")
        else:
            logging.warning(f"Mission ID not found in progress result for {identity_name}")
    else:
        print(f"No completed mission to claim for {identity_name}")
        logging.info(f"No completed mission to claim for {identity_name}")

def run_matches(num_matches, loop):
    """Run the specified number of matches."""
    num_players = num_matches * 2  # Each match requires 2 players

    players = [f"player{i}" for i in range(1, num_players + 1)]  # Create player identities

    while True:
        # Shuffle the players
        random.shuffle(players)

        # Get principals for all players
        principals = {player: get_principal(player) for player in players}

        player_game_data = {
            "userAvatar": 1,  # Replace with actual avatar ID
            "listSavedKeys": []  # Replace with actual saved keys if needed
        }

        match_ids = []

        for i in range(0, num_players, 2):  # Iterate in steps of 2 for pairs of players
            player1 = players[i]
            player2 = players[i + 1]

            # Start searching for a match for player1
            print(f"{player1} starts searching for a match")
            logging.info(f"{player1} starts searching for a match")
            search_result1 = get_match_searching(player1, player_game_data)
            logging.info(f"{player1} search result: {search_result1}")
            match_id1 = parse_match_id(search_result1)
            match_ids.append((player1, match_id1))

            # Simulate player1 activation and match confirmation
            active_result1 = set_player_active(player1)
            logging.info(f"{player1} active result: {active_result1}")

            # Start searching for a match for player2
            print(f"{player2} starts searching for a match")
            logging.info(f"{player2} starts searching for a match")
            search_result2 = get_match_searching(player2, player_game_data)
            logging.info(f"{player2} search result: {search_result2}")
            match_id2 = parse_match_id(search_result2)
            match_ids.append((player2, match_id2))

            # Simulate player2 activation and match confirmation
            active_result2 = set_player_active(player2)
            logging.info(f"{player2} active result: {active_result2}")

            # Wait until both players confirm the match
            player1_matched = False
            player2_matched = False

            while not (player1_matched and player2_matched):
                is_matched_result1 = is_game_matched(player1)
                is_matched_result2 = is_game_matched(player2)
                logging.info(f"Is game matched result for {player1}: {is_matched_result1}")
                logging.info(f"Is game matched result for {player2}: {is_matched_result2}")

                player1_matched = "true" in is_matched_result1
                player2_matched = "true" in is_matched_result2

                if not (player1_matched and player2_matched):
                    print("Waiting for both players to be matched...")
                    logging.info("Waiting for both players to be matched...")
                    time.sleep(1)

            print("Match found! Ending search.")
            logging.info("Match found! Ending search.")

            # Confirm both players are in the same match
            match_data_player1 = get_my_match_data(player1)
            match_data_player2 = get_my_match_data(player2)
            logging.info(f"Match data for {player1}: {match_data_player1}")
            logging.info(f"Match data for {player2}: {match_data_player2}")

            # Send statistics immediately for the matched players
            shared_energy_generated = random.randint(50, 210)
            shared_sec_remaining = random.randint(30, 300)

            # Randomly determine the winner
            won_player1 = random.choice([True, False])
            won_player2 = not won_player1

            for player, match_id, won in [(player1, match_id1, won_player1), (player2, match_id2, won_player2)]:
                logging.info(f"Sending statistics for match ID: {match_id} for {player}")

                stats = generate_random_stats(shared_energy_generated, shared_sec_remaining, won)

                try:
                    save_finished_game(player, match_id, stats)
                    print(f"Statistics sent for {player} in match {match_id}")
                    logging.info(f"Statistics saved for {player} in match {match_id}")

                    # Handle mission progress and claiming rewards
                    handle_mission_progress(player)

                except Exception as e:
                    error_message = f"Error saving statistics for {player} in match {match_id}: {e}"
                    logging.error(error_message)
                    print(error_message)
                    return  # Halt on error

            # Display basic stats after all stats are sent
            basic_stats = get_basic_stats(match_id1)
###### print(f"Basic stats for match ID {match_id1}: {basic_stats}")
            logging.info(f"Basic stats for match ID {match_id1}: {basic_stats}")

            match_ids.clear()  # Clear match IDs after saving stats

        print(f"Finished {num_matches} matches. {'Looping...' if loop else ''}")
        logging.info(f"Finished {num_matches} matches. {'Looping...' if loop else ''}")

        if not loop:
            break

        time.sleep(1)  # Add a delay before starting the next loop, if desired

if __name__ == "__main__":
    def exit_gracefully(signum, frame):
        """Handle graceful exit on Ctrl+C or termination signal."""
        switch_identity("bizkit")
        print("Exiting gracefully...")
        sys.exit(0)

    signal.signal(signal.SIGINT, exit_gracefully)
    signal.signal(signal.SIGTERM, exit_gracefully)

    try:
        num_matches = int(input("Enter the number of matches to run: "))
        loop = input("Do you want to loop indefinitely? (y/n): ").strip().lower() == "y"
        run_matches(num_matches, loop)
    finally:
        switch_identity("bizkit")
